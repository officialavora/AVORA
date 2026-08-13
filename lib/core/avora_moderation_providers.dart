import 'avora_moderation.dart';
import 'avora_moderation_pipeline.dart';

abstract interface class AvoraTextModerationProvider {
  Future<AvoraContentAnalysisResult> analyzeText({
    required String text,
    required String languageCode,
  });
}

abstract interface class AvoraAudioTranscriptionProvider {
  Future<AvoraTranscriptionResult> transcribe({
    required String audioRef,
    String? languageHint,
  });
}

abstract interface class AvoraAudioModerationProvider {
  Future<AvoraContentAnalysisResult> analyzeTranscript({
    required String transcript,
    required String languageCode,
    required AvoraModerationSource source,
  });
}

class AvoraModerationProviders {
  final AvoraTextModerationProvider text;
  final AvoraAudioTranscriptionProvider transcription;
  final AvoraAudioModerationProvider audio;

  const AvoraModerationProviders({
    required this.text,
    required this.transcription,
    required this.audio,
  });
}
