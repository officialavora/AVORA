import 'avora_session_continuity.dart';

enum AvoraPerformancePresenceMode {
  none,
  cameraVisible,
  faceVisible,
}

enum AvoraPresenceDecisionState {
  valid,
  grace,
  warning,
  enforcement,
  uncertainQuality,
}

enum AvoraPresenceAction {
  allow,
  pauseValidCounting,
  warnUser,
  requestPresenceRetry,
  pausePkScoreContribution,
  pauseLiveVideo,
  dropPerformanceSeat,
  endPerformanceSession,
}

class AvoraPerformancePresencePolicy {
  final String id;

  /// Normally Live and Live-PK.
  /// Audio-PK does not require face by default.
  final Set<AvoraSessionSurface> applicableSurfaces;

  final AvoraPerformancePresenceMode mode;

  /// Very short missed detection is tolerated.
  final Duration detectionGrace;

  /// Warning threshold after absence starts.
  final Duration warningAfter;

  /// Stronger action threshold.
  final Duration enforcementAfter;

  /// 0..10000 basis points.
  final int minimumPresenceConfidenceBps;

  /// Whether PiP is accepted as valid visual performance.
  final bool allowPictureInPicturePresence;

  /// Usually false for camera performance.
  final bool allowBackgroundPresence;

  /// What happens after enforcement threshold.
  final Set<AvoraPresenceAction> enforcementActions;

  const AvoraPerformancePresencePolicy({
    required this.id,
    this.applicableSurfaces = const {
      AvoraSessionSurface.live,
      AvoraSessionSurface.livePk,
    },
    this.mode = AvoraPerformancePresenceMode.faceVisible,
    this.detectionGrace = const Duration(seconds: 5),
    this.warningAfter = const Duration(seconds: 10),
    this.enforcementAfter = const Duration(seconds: 30),
    this.minimumPresenceConfidenceBps = 7000,
    this.allowPictureInPicturePresence = false,
    this.allowBackgroundPresence = false,
    this.enforcementActions = const {
      AvoraPresenceAction.dropPerformanceSeat,
    },
  })  : assert(minimumPresenceConfidenceBps >= 0),
        assert(minimumPresenceConfidenceBps <= 10000);
}

class AvoraPerformancePresenceContext {
  final AvoraSessionSurface surface;

  final AvoraClientVisibility visibility;

  final AvoraRealtimeConnectionState connectionState;

  final DateTime now;

  final bool cameraPublishing;

  final bool facePresent;

  /// Confidence from camera/face presence detector.
  final int presenceConfidenceBps;

  /// First server-observed time the required presence became invalid.
  final DateTime? absenceStartedAt;

  /// Quality problems must not be treated like misconduct.
  final bool poorNetwork;
  final bool poorLighting;
  final bool cameraTemporarilyUnavailable;

  const AvoraPerformancePresenceContext({
    required this.surface,
    required this.visibility,
    required this.connectionState,
    required this.now,
    required this.cameraPublishing,
    required this.facePresent,
    required this.presenceConfidenceBps,
    required this.absenceStartedAt,
    this.poorNetwork = false,
    this.poorLighting = false,
    this.cameraTemporarilyUnavailable = false,
  }) : assert(
          presenceConfidenceBps >= 0 && presenceConfidenceBps <= 10000,
        );
}

class AvoraPerformancePresenceDecision {
  final AvoraPresenceDecisionState state;

  /// Whether this interval may count toward genuine performance.
  final bool countAsValidPerformance;

  final Set<AvoraPresenceAction> actions;

  final Duration absenceDuration;

  /// Quality uncertainty suppresses punitive seat/session actions.
  final bool qualityUncertain;

  const AvoraPerformancePresenceDecision({
    required this.state,
    required this.countAsValidPerformance,
    required this.actions,
    required this.absenceDuration,
    required this.qualityUncertain,
  });
}

class AvoraLivePresenceGuard {
  const AvoraLivePresenceGuard._();

  static bool _visibilityAllowed({
    required AvoraPerformancePresenceContext context,
    required AvoraPerformancePresencePolicy policy,
  }) {
    switch (context.visibility) {
      case AvoraClientVisibility.foreground:
        return true;

      case AvoraClientVisibility.pictureInPicture:
        return policy.allowPictureInPicturePresence;

      case AvoraClientVisibility.background:
        return policy.allowBackgroundPresence;
    }
  }

  static bool _requiredPresenceDetected({
    required AvoraPerformancePresenceContext context,
    required AvoraPerformancePresencePolicy policy,
  }) {
    switch (policy.mode) {
      case AvoraPerformancePresenceMode.none:
        return true;

      case AvoraPerformancePresenceMode.cameraVisible:
        return context.cameraPublishing &&
            context.presenceConfidenceBps >=
                policy.minimumPresenceConfidenceBps;

      case AvoraPerformancePresenceMode.faceVisible:
        return context.cameraPublishing &&
            context.facePresent &&
            context.presenceConfidenceBps >=
                policy.minimumPresenceConfidenceBps;
    }
  }

  static AvoraPerformancePresenceDecision evaluate({
    required AvoraPerformancePresenceContext context,
    required AvoraPerformancePresencePolicy policy,
  }) {
    if (!policy.applicableSurfaces.contains(context.surface) ||
        policy.mode == AvoraPerformancePresenceMode.none) {
      return const AvoraPerformancePresenceDecision(
        state: AvoraPresenceDecisionState.valid,
        countAsValidPerformance: true,
        actions: {
          AvoraPresenceAction.allow,
        },
        absenceDuration: Duration.zero,
        qualityUncertain: false,
      );
    }

    if (context.connectionState != AvoraRealtimeConnectionState.connected) {
      return const AvoraPerformancePresenceDecision(
        state: AvoraPresenceDecisionState.uncertainQuality,
        countAsValidPerformance: false,
        actions: {
          AvoraPresenceAction.pauseValidCounting,
          AvoraPresenceAction.requestPresenceRetry,
        },
        absenceDuration: Duration.zero,
        qualityUncertain: true,
      );
    }

    final qualityUncertain = context.poorNetwork ||
        context.poorLighting ||
        context.cameraTemporarilyUnavailable;

    final visibilityAllowed = _visibilityAllowed(
      context: context,
      policy: policy,
    );

    final presenceDetected = _requiredPresenceDetected(
      context: context,
      policy: policy,
    );

    if (visibilityAllowed && presenceDetected) {
      return const AvoraPerformancePresenceDecision(
        state: AvoraPresenceDecisionState.valid,
        countAsValidPerformance: true,
        actions: {
          AvoraPresenceAction.allow,
        },
        absenceDuration: Duration.zero,
        qualityUncertain: false,
      );
    }

    final startedAt = context.absenceStartedAt ?? context.now;

    final absenceDuration = context.now.isAfter(startedAt)
        ? context.now.difference(startedAt)
        : Duration.zero;

    if (qualityUncertain) {
      return AvoraPerformancePresenceDecision(
        state: AvoraPresenceDecisionState.uncertainQuality,
        countAsValidPerformance: false,
        actions: const {
          AvoraPresenceAction.pauseValidCounting,
          AvoraPresenceAction.requestPresenceRetry,
        },
        absenceDuration: absenceDuration,
        qualityUncertain: true,
      );
    }

    if (absenceDuration < policy.detectionGrace) {
      return AvoraPerformancePresenceDecision(
        state: AvoraPresenceDecisionState.grace,
        countAsValidPerformance: false,
        actions: const {
          AvoraPresenceAction.pauseValidCounting,
        },
        absenceDuration: absenceDuration,
        qualityUncertain: false,
      );
    }

    if (absenceDuration < policy.warningAfter) {
      return AvoraPerformancePresenceDecision(
        state: AvoraPresenceDecisionState.grace,
        countAsValidPerformance: false,
        actions: const {
          AvoraPresenceAction.pauseValidCounting,
        },
        absenceDuration: absenceDuration,
        qualityUncertain: false,
      );
    }

    if (absenceDuration < policy.enforcementAfter) {
      final actions = <AvoraPresenceAction>{
        AvoraPresenceAction.pauseValidCounting,
        AvoraPresenceAction.warnUser,
      };

      if (context.surface == AvoraSessionSurface.livePk) {
        actions.add(
          AvoraPresenceAction.pausePkScoreContribution,
        );
      }

      return AvoraPerformancePresenceDecision(
        state: AvoraPresenceDecisionState.warning,
        countAsValidPerformance: false,
        actions: Set.unmodifiable(actions),
        absenceDuration: absenceDuration,
        qualityUncertain: false,
      );
    }

    final actions = <AvoraPresenceAction>{
      AvoraPresenceAction.pauseValidCounting,
      AvoraPresenceAction.warnUser,
      ...policy.enforcementActions,
    };

    if (context.surface == AvoraSessionSurface.livePk) {
      actions.add(
        AvoraPresenceAction.pausePkScoreContribution,
      );
    }

    if (context.surface == AvoraSessionSurface.live) {
      actions.add(
        AvoraPresenceAction.pauseLiveVideo,
      );
    }

    return AvoraPerformancePresenceDecision(
      state: AvoraPresenceDecisionState.enforcement,
      countAsValidPerformance: false,
      actions: Set.unmodifiable(actions),
      absenceDuration: absenceDuration,
      qualityUncertain: false,
    );
  }

  /// Audio PK has no face requirement by default.
  static bool audioPkRequiresFaceByDefault() {
    return false;
  }

  /// A missing/hidden face is not automatically identity fraud.
  static bool faceAbsenceEqualsIdentityFraud() {
    return false;
  }

  /// Uncertain lighting/network detection must not drop the user.
  static bool uncertainQualityCanDropPerformanceSeat() {
    return false;
  }

  /// Seat/session continuity and valid-performance counting
  /// are intentionally separate.
  static bool retainedSeatAutomaticallyCountsPerformance() {
    return false;
  }

  /// Presence enforcement never implies an automatic permanent ban.
  static bool presenceFailureAutomaticallyPermanentlyBans() {
    return false;
  }
}
