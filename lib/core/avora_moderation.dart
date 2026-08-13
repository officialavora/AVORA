enum AvoraModerationSource {
  roomText,
  roomVoice,
  roomSong,
  roomRadio,
}

enum AvoraViolationType {
  profanity,
  harassment,
  hate,
  threat,
  sexualContent,
  spam,
  kickAbuse,
  other,
}

enum AvoraModerationAction {
  allow,
  warn,
  seatMute,
  roomMute,
  stopMedia,
  blockKickPrivilege,
  roomKick,
  roomBan,
  escalate,
}

enum AvoraModerationSeverity {
  low,
  medium,
  high,
  critical,
}

class AvoraModerationSignal {
  final String id;

  final String roomId;
  final String? userId;

  final AvoraModerationSource source;
  final AvoraViolationType violationType;
  final AvoraModerationSeverity severity;
  final AvoraModerationAction recommendedAction;

  /// Detection confidence from 0.0 to 1.0.
  final double confidence;

  /// BCP-47 / ISO-style language code.
  /// Use 'und' when language is unknown.
  final String languageCode;

  /// Reference to evidence stored by the moderation/audit system.
  /// Raw audio does not need to live inside this model.
  final String? evidenceRef;

  final DateTime detectedAt;

  const AvoraModerationSignal({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.source,
    required this.violationType,
    required this.severity,
    required this.recommendedAction,
    required this.confidence,
    required this.languageCode,
    required this.detectedAt,
    this.evidenceRef,
  }) : assert(
          confidence >= 0.0 && confidence <= 1.0,
          'confidence must be between 0.0 and 1.0',
        );

  bool get isHighConfidence => confidence >= 0.85;

  bool get isCritical => severity == AvoraModerationSeverity.critical;
}

class AvoraModerationDecision {
  final AvoraModerationAction action;
  final bool requiresHumanReview;
  final bool storeEvidence;

  const AvoraModerationDecision({
    required this.action,
    required this.requiresHumanReview,
    required this.storeEvidence,
  });
}

class AvoraModerationPolicy {
  const AvoraModerationPolicy._();

  static AvoraModerationDecision decide({
    required AvoraModerationSignal signal,
    int priorViolations = 0,
  }) {
    if (signal.confidence < 0.60) {
      return AvoraModerationDecision(
        action: AvoraModerationAction.allow,
        requiresHumanReview: signal.isCritical,
        storeEvidence: signal.isCritical,
      );
    }

    if (signal.source == AvoraModerationSource.roomSong ||
        signal.source == AvoraModerationSource.roomRadio) {
      if (signal.confidence >= 0.85 &&
          signal.severity != AvoraModerationSeverity.low) {
        return const AvoraModerationDecision(
          action: AvoraModerationAction.stopMedia,
          requiresHumanReview: true,
          storeEvidence: true,
        );
      }
    }

    if (signal.isCritical && signal.confidence >= 0.90) {
      return const AvoraModerationDecision(
        action: AvoraModerationAction.escalate,
        requiresHumanReview: true,
        storeEvidence: true,
      );
    }

    if (signal.severity == AvoraModerationSeverity.high &&
        signal.confidence >= 0.85) {
      if (priorViolations >= 2) {
        return const AvoraModerationDecision(
          action: AvoraModerationAction.roomBan,
          requiresHumanReview: true,
          storeEvidence: true,
        );
      }

      return const AvoraModerationDecision(
        action: AvoraModerationAction.roomMute,
        requiresHumanReview: true,
        storeEvidence: true,
      );
    }

    if (signal.severity == AvoraModerationSeverity.medium &&
        signal.confidence >= 0.75) {
      if (priorViolations >= 2) {
        return const AvoraModerationDecision(
          action: AvoraModerationAction.roomMute,
          requiresHumanReview: false,
          storeEvidence: true,
        );
      }

      return const AvoraModerationDecision(
        action: AvoraModerationAction.warn,
        requiresHumanReview: false,
        storeEvidence: true,
      );
    }

    if (priorViolations >= 3 && signal.confidence >= 0.75) {
      return const AvoraModerationDecision(
        action: AvoraModerationAction.warn,
        requiresHumanReview: false,
        storeEvidence: true,
      );
    }

    return const AvoraModerationDecision(
      action: AvoraModerationAction.allow,
      requiresHumanReview: false,
      storeEvidence: false,
    );
  }
}
