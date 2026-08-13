import 'avora_moderation.dart';

enum AvoraModerationPipelineStage {
  received,
  languageDetection,
  transcription,
  contentAnalysis,
  policyDecision,
  completed,
  failed,
}

class AvoraModerationInput {
  final String id;
  final String roomId;
  final String? userId;

  final AvoraModerationSource source;

  /// Used for room text.
  final String? text;

  /// Reference to live voice/song/radio audio segment.
  /// Raw audio does not live in this object.
  final String? audioRef;

  /// Optional language hint from device/room/user.
  /// Example: 'en', 'hi', 'ar'. Use null if unknown.
  final String? languageHint;

  final DateTime receivedAt;

  const AvoraModerationInput({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.source,
    required this.receivedAt,
    this.text,
    this.audioRef,
    this.languageHint,
  });

  bool get isAudio =>
      source == AvoraModerationSource.roomVoice ||
      source == AvoraModerationSource.roomSong ||
      source == AvoraModerationSource.roomRadio;

  bool get isText => source == AvoraModerationSource.roomText;
}

class AvoraTranscriptionResult {
  final String text;

  /// Detected language. Use 'und' when unknown.
  final String languageCode;

  /// 0.0 to 1.0.
  final double confidence;

  const AvoraTranscriptionResult({
    required this.text,
    required this.languageCode,
    required this.confidence,
  }) : assert(
          confidence >= 0.0 && confidence <= 1.0,
          'confidence must be between 0.0 and 1.0',
        );
}

class AvoraModerationPipelineResult {
  final AvoraModerationPipelineStage stage;

  final AvoraModerationInput input;

  final AvoraTranscriptionResult? transcription;
  final AvoraModerationSignal? signal;
  final AvoraModerationDecision? decision;

  final String? errorCode;

  const AvoraModerationPipelineResult({
    required this.stage,
    required this.input,
    this.transcription,
    this.signal,
    this.decision,
    this.errorCode,
  });
}

class AvoraModerationPipelinePlan {
  final bool validInput;
  final AvoraModerationPipelineStage nextStage;

  final bool requiresLanguageDetection;
  final bool requiresTranscription;

  final String languageCode;
  final String? errorCode;

  const AvoraModerationPipelinePlan({
    required this.validInput,
    required this.nextStage,
    required this.requiresLanguageDetection,
    required this.requiresTranscription,
    required this.languageCode,
    this.errorCode,
  });
}

class AvoraModerationPipelinePlanner {
  const AvoraModerationPipelinePlanner._();

  static AvoraModerationPipelinePlan plan(
    AvoraModerationInput input,
  ) {
    final language = _normalizeLanguage(
      input.languageHint,
    );

    if (input.isText) {
      if (input.text == null || input.text!.trim().isEmpty) {
        return const AvoraModerationPipelinePlan(
          validInput: false,
          nextStage: AvoraModerationPipelineStage.failed,
          requiresLanguageDetection: false,
          requiresTranscription: false,
          languageCode: 'und',
          errorCode: 'missing_text',
        );
      }

      return AvoraModerationPipelinePlan(
        validInput: true,
        nextStage: AvoraModerationPipelineStage.contentAnalysis,
        requiresLanguageDetection: language == 'und',
        requiresTranscription: false,
        languageCode: language,
      );
    }

    if (input.isAudio) {
      if (input.audioRef == null || input.audioRef!.trim().isEmpty) {
        return const AvoraModerationPipelinePlan(
          validInput: false,
          nextStage: AvoraModerationPipelineStage.failed,
          requiresLanguageDetection: false,
          requiresTranscription: false,
          languageCode: 'und',
          errorCode: 'missing_audio',
        );
      }

      return AvoraModerationPipelinePlan(
        validInput: true,
        nextStage: language == 'und'
            ? AvoraModerationPipelineStage.languageDetection
            : AvoraModerationPipelineStage.transcription,
        requiresLanguageDetection: language == 'und',
        requiresTranscription: true,
        languageCode: language,
      );
    }

    return const AvoraModerationPipelinePlan(
      validInput: false,
      nextStage: AvoraModerationPipelineStage.failed,
      requiresLanguageDetection: false,
      requiresTranscription: false,
      languageCode: 'und',
      errorCode: 'unsupported_source',
    );
  }

  static String _normalizeLanguage(String? value) {
    final normalized = value?.trim().toLowerCase();

    if (normalized == null || normalized.isEmpty) {
      return 'und';
    }

    return normalized;
  }
}

class AvoraContentAnalysisResult {
  final AvoraViolationType violationType;
  final AvoraModerationSeverity severity;

  /// Classifier confidence from 0.0 to 1.0.
  final double confidence;

  /// Language detected by the analysis provider.
  /// Use 'und' when unknown.
  final String languageCode;

  final String? evidenceRef;

  const AvoraContentAnalysisResult({
    required this.violationType,
    required this.severity,
    required this.confidence,
    required this.languageCode,
    this.evidenceRef,
  }) : assert(
          confidence >= 0.0 && confidence <= 1.0,
          'confidence must be between 0.0 and 1.0',
        );
}

class AvoraModerationPipelineFinalizer {
  const AvoraModerationPipelineFinalizer._();

  static AvoraModerationPipelineResult complete({
    required AvoraModerationInput input,
    required AvoraContentAnalysisResult analysis,
    AvoraTranscriptionResult? transcription,
    int priorViolations = 0,
  }) {
    final language = _resolveLanguage(
      analysis.languageCode,
      transcription?.languageCode,
      input.languageHint,
    );

    final signal = AvoraModerationSignal(
      id: '${input.id}:signal',
      roomId: input.roomId,
      userId: input.userId,
      source: input.source,
      violationType: analysis.violationType,
      severity: analysis.severity,
      recommendedAction: AvoraModerationAction.allow,
      confidence: analysis.confidence,
      languageCode: language,
      evidenceRef: analysis.evidenceRef,
      detectedAt: input.receivedAt,
    );

    final decision = AvoraModerationPolicy.decide(
      signal: signal,
      priorViolations: priorViolations,
    );

    return AvoraModerationPipelineResult(
      stage: AvoraModerationPipelineStage.completed,
      input: input,
      transcription: transcription,
      signal: signal,
      decision: decision,
    );
  }

  static String _resolveLanguage(
    String analysisLanguage,
    String? transcriptionLanguage,
    String? inputHint,
  ) {
    String normalize(String? value) {
      final result = value?.trim().toLowerCase();

      if (result == null || result.isEmpty) {
        return 'und';
      }

      return result;
    }

    final fromAnalysis = normalize(analysisLanguage);
    if (fromAnalysis != 'und') {
      return fromAnalysis;
    }

    final fromTranscription = normalize(transcriptionLanguage);
    if (fromTranscription != 'und') {
      return fromTranscription;
    }

    return normalize(inputHint);
  }
}
