enum AvoraLiveExperience {
  videoLive,
  videoPk,
}

enum AvoraLivePresenceIssue {
  none,

  /// Normal short movement away from camera.
  temporaryOffFrame,

  /// Expected broadcaster face is persistently absent.
  faceAbsent,

  /// Broadcaster is intentionally showing only rear camera
  /// when the session requires face-live participation.
  backCameraOnly,

  /// High-confidence mismatch against verified broadcaster.
  faceMismatch,

  cameraCovered,
  lowLight,
  networkInstability,
}

enum AvoraLiveQualityAction {
  allow,
  warn,
  requestRecheck,
  pauseLive,
  stopLive,
}

class AvoraLiveQualityConfig {
  final double minimumActionConfidence;
  final double faceMismatchConfidence;

  /// Consecutive detections required before ordinary
  /// presence issues start enforcement.
  final int warningDetectionCount;

  /// Optional competition/event score penalty.
  /// Never represents wallet coin deduction.
  final int repeatedViolationPointPenalty;

  const AvoraLiveQualityConfig({
    this.minimumActionConfidence = 0.75,
    this.faceMismatchConfidence = 0.90,
    this.warningDetectionCount = 2,
    this.repeatedViolationPointPenalty = 0,
  })  : assert(
          minimumActionConfidence >= 0 && minimumActionConfidence <= 1,
        ),
        assert(
          faceMismatchConfidence >= 0 && faceMismatchConfidence <= 1,
        ),
        assert(warningDetectionCount > 0),
        assert(repeatedViolationPointPenalty >= 0);
}

class AvoraLiveQualitySignal {
  final String sessionId;
  final String broadcasterUserId;

  final AvoraLiveExperience experience;
  final AvoraLivePresenceIssue issue;

  final double confidence;

  /// Number of consecutive detections of the same issue.
  final int consecutiveDetections;

  /// Prior warnings during this live session.
  final int priorWarnings;

  /// True when the session requires the verified broadcaster
  /// to remain the visible face-live participant.
  final bool verifiedFaceExpected;

  final DateTime detectedAt;

  const AvoraLiveQualitySignal({
    required this.sessionId,
    required this.broadcasterUserId,
    required this.experience,
    required this.issue,
    required this.confidence,
    required this.consecutiveDetections,
    required this.priorWarnings,
    required this.detectedAt,
    this.verifiedFaceExpected = false,
  })  : assert(confidence >= 0 && confidence <= 1),
        assert(consecutiveDetections >= 0),
        assert(priorWarnings >= 0);
}

class AvoraLiveQualityDecision {
  final AvoraLiveQualityAction action;

  /// Optional deduction from an explicit Live/Event
  /// competition score only.
  final int competitionPointPenalty;

  final bool requiresHumanReview;

  const AvoraLiveQualityDecision({
    required this.action,
    this.competitionPointPenalty = 0,
    this.requiresHumanReview = false,
  });
}

class AvoraLiveQualityPolicy {
  const AvoraLiveQualityPolicy._();

  static AvoraLiveQualityDecision decide({
    required AvoraLiveQualitySignal signal,
    AvoraLiveQualityConfig config = const AvoraLiveQualityConfig(),
  }) {
    if (signal.issue == AvoraLivePresenceIssue.none) {
      return const AvoraLiveQualityDecision(
        action: AvoraLiveQualityAction.allow,
      );
    }

    /// Do not punish network/lighting problems as identity abuse.
    if (signal.issue == AvoraLivePresenceIssue.networkInstability ||
        signal.issue == AvoraLivePresenceIssue.lowLight) {
      return const AvoraLiveQualityDecision(
        action: AvoraLiveQualityAction.requestRecheck,
      );
    }

    if (signal.confidence < config.minimumActionConfidence) {
      return const AvoraLiveQualityDecision(
        action: AvoraLiveQualityAction.allow,
      );
    }

    /// Brief normal movement should not immediately stop a live.
    if (signal.issue == AvoraLivePresenceIssue.temporaryOffFrame &&
        signal.consecutiveDetections < 3) {
      return const AvoraLiveQualityDecision(
        action: AvoraLiveQualityAction.allow,
      );
    }

    /// Verified-face mismatch gets a recheck before punishment.
    if (signal.issue == AvoraLivePresenceIssue.faceMismatch &&
        signal.verifiedFaceExpected &&
        signal.confidence >= config.faceMismatchConfidence) {
      if (signal.priorWarnings == 0) {
        return const AvoraLiveQualityDecision(
          action: AvoraLiveQualityAction.requestRecheck,
        );
      }

      return AvoraLiveQualityDecision(
        action: AvoraLiveQualityAction.stopLive,
        competitionPointPenalty: config.repeatedViolationPointPenalty,
        requiresHumanReview: true,
      );
    }

    if (signal.consecutiveDetections < config.warningDetectionCount) {
      return const AvoraLiveQualityDecision(
        action: AvoraLiveQualityAction.allow,
      );
    }

    if (signal.priorWarnings == 0) {
      return const AvoraLiveQualityDecision(
        action: AvoraLiveQualityAction.warn,
      );
    }

    if (signal.priorWarnings == 1) {
      return const AvoraLiveQualityDecision(
        action: AvoraLiveQualityAction.pauseLive,
      );
    }

    return AvoraLiveQualityDecision(
      action: AvoraLiveQualityAction.stopLive,
      competitionPointPenalty: config.repeatedViolationPointPenalty,
      requiresHumanReview: signal.priorWarnings >= 3,
    );
  }
}
