enum AvoraMessageModerationContext {
  room,
  inbox,
}

enum AvoraMessageContentKind {
  text,
  image,
  video,
}

enum AvoraMessageViolation {
  none,
  profanity,
  harassment,
  sexualMedia,
  unsafeMedia,
  spam,
  appPromotion,
  maliciousLink,
  other,
}

enum AvoraMessageModerationAction {
  allow,
  warn,
  blurMedia,
  blockMessage,
  restrictDm,
  escalate,
}

enum AvoraMessageModerationSeverity {
  low,
  medium,
  high,
  critical,
}

class AvoraMessageModerationSignal {
  final String id;

  final AvoraMessageModerationContext context;
  final AvoraMessageContentKind contentKind;

  final String senderUserId;
  final String conversationId;

  final AvoraMessageViolation violation;
  final AvoraMessageModerationSeverity severity;

  /// Confidence from 0.0 to 1.0.
  final double confidence;

  /// Optional evidence reference stored by moderation/audit systems.
  final String? evidenceRef;

  /// Optional detected URL / invite / referral code reference.
  final String? detectedPromotionRef;

  final DateTime detectedAt;

  const AvoraMessageModerationSignal({
    required this.id,
    required this.context,
    required this.contentKind,
    required this.senderUserId,
    required this.conversationId,
    required this.violation,
    required this.severity,
    required this.confidence,
    required this.detectedAt,
    this.evidenceRef,
    this.detectedPromotionRef,
  }) : assert(
          confidence >= 0.0 && confidence <= 1.0,
          'confidence must be between 0.0 and 1.0',
        );
}

class AvoraMessageModerationDecision {
  final AvoraMessageModerationAction action;

  final bool storeEvidence;
  final bool requiresHumanReview;

  /// Useful for repeat-spam / promotion enforcement.
  final Duration? restrictionDuration;

  const AvoraMessageModerationDecision({
    required this.action,
    required this.storeEvidence,
    required this.requiresHumanReview,
    this.restrictionDuration,
  });
}

class AvoraMessageModerationPolicy {
  const AvoraMessageModerationPolicy._();

  static AvoraMessageModerationDecision decide({
    required AvoraMessageModerationSignal signal,
    int priorViolations = 0,
  }) {
    if (signal.confidence < 0.60) {
      return AvoraMessageModerationDecision(
        action: AvoraMessageModerationAction.allow,
        storeEvidence:
            signal.severity == AvoraMessageModerationSeverity.critical,
        requiresHumanReview:
            signal.severity == AvoraMessageModerationSeverity.critical,
      );
    }

    if (signal.violation == AvoraMessageViolation.maliciousLink &&
        signal.confidence >= 0.85) {
      if (priorViolations >= 2 &&
          signal.context == AvoraMessageModerationContext.inbox) {
        return const AvoraMessageModerationDecision(
          action: AvoraMessageModerationAction.restrictDm,
          storeEvidence: true,
          requiresHumanReview: true,
          restrictionDuration: Duration(hours: 24),
        );
      }

      return const AvoraMessageModerationDecision(
        action: AvoraMessageModerationAction.blockMessage,
        storeEvidence: true,
        requiresHumanReview: true,
      );
    }

    final isUnsafeMedia =
        signal.violation == AvoraMessageViolation.sexualMedia ||
            signal.violation == AvoraMessageViolation.unsafeMedia;

    if (isUnsafeMedia &&
        signal.contentKind != AvoraMessageContentKind.text &&
        signal.confidence >= 0.85) {
      if (signal.context == AvoraMessageModerationContext.room) {
        return const AvoraMessageModerationDecision(
          action: AvoraMessageModerationAction.blockMessage,
          storeEvidence: true,
          requiresHumanReview: true,
        );
      }

      if (priorViolations >= 2 &&
          (signal.severity == AvoraMessageModerationSeverity.high ||
              signal.severity == AvoraMessageModerationSeverity.critical)) {
        return const AvoraMessageModerationDecision(
          action: AvoraMessageModerationAction.blockMessage,
          storeEvidence: true,
          requiresHumanReview: true,
        );
      }

      return AvoraMessageModerationDecision(
        action: AvoraMessageModerationAction.blurMedia,
        storeEvidence: true,
        requiresHumanReview:
            signal.severity == AvoraMessageModerationSeverity.critical,
      );
    }

    final isPromotion =
        signal.violation == AvoraMessageViolation.appPromotion ||
            signal.violation == AvoraMessageViolation.spam;

    if (isPromotion &&
        signal.context == AvoraMessageModerationContext.inbox &&
        signal.confidence >= 0.80) {
      if (priorViolations >= 4) {
        return const AvoraMessageModerationDecision(
          action: AvoraMessageModerationAction.restrictDm,
          storeEvidence: true,
          requiresHumanReview: true,
          restrictionDuration: Duration(hours: 24),
        );
      }

      if (priorViolations >= 2) {
        return const AvoraMessageModerationDecision(
          action: AvoraMessageModerationAction.restrictDm,
          storeEvidence: true,
          requiresHumanReview: false,
          restrictionDuration: Duration(hours: 1),
        );
      }

      return const AvoraMessageModerationDecision(
        action: AvoraMessageModerationAction.warn,
        storeEvidence: true,
        requiresHumanReview: false,
      );
    }

    final isAbusiveText = signal.violation == AvoraMessageViolation.profanity ||
        signal.violation == AvoraMessageViolation.harassment;

    if (isAbusiveText && signal.contentKind == AvoraMessageContentKind.text) {
      if (signal.confidence >= 0.85 &&
          signal.severity == AvoraMessageModerationSeverity.high &&
          priorViolations >= 2) {
        return const AvoraMessageModerationDecision(
          action: AvoraMessageModerationAction.blockMessage,
          storeEvidence: true,
          requiresHumanReview: false,
        );
      }

      if (signal.confidence >= 0.75) {
        return const AvoraMessageModerationDecision(
          action: AvoraMessageModerationAction.warn,
          storeEvidence: true,
          requiresHumanReview: false,
        );
      }
    }

    if (signal.severity == AvoraMessageModerationSeverity.critical &&
        signal.confidence >= 0.90) {
      return const AvoraMessageModerationDecision(
        action: AvoraMessageModerationAction.escalate,
        storeEvidence: true,
        requiresHumanReview: true,
      );
    }

    return const AvoraMessageModerationDecision(
      action: AvoraMessageModerationAction.allow,
      storeEvidence: false,
      requiresHumanReview: false,
    );
  }
}
