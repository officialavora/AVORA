import 'avora_message_moderation.dart';

class AvoraMessageContentAnalysisResult {
  final AvoraMessageViolation violation;
  final AvoraMessageModerationSeverity severity;

  /// Confidence from 0.0 to 1.0.
  final double confidence;

  final String? evidenceRef;

  /// URL / referral / invite / promotion reference if detected.
  final String? detectedPromotionRef;

  const AvoraMessageContentAnalysisResult({
    required this.violation,
    required this.severity,
    required this.confidence,
    this.evidenceRef,
    this.detectedPromotionRef,
  }) : assert(
          confidence >= 0.0 && confidence <= 1.0,
          'confidence must be between 0.0 and 1.0',
        );
}

abstract interface class AvoraMessageTextModerationProvider {
  Future<AvoraMessageContentAnalysisResult> analyzeText({
    required String text,
    required AvoraMessageModerationContext context,
  });
}

abstract interface class AvoraMessageMediaModerationProvider {
  Future<AvoraMessageContentAnalysisResult> analyzeMedia({
    required String mediaRef,
    required AvoraMessageContentKind contentKind,
    required AvoraMessageModerationContext context,
  });
}

class AvoraMessageModerationProviders {
  final AvoraMessageTextModerationProvider text;
  final AvoraMessageMediaModerationProvider media;

  const AvoraMessageModerationProviders({
    required this.text,
    required this.media,
  });
}
