enum AvoraSessionSurface {
  voiceRoom,
  audioPk,
  live,
  livePk,
}

enum AvoraClientVisibility {
  foreground,
  background,
  pictureInPicture,
}

enum AvoraRealtimeConnectionState {
  connected,
  reconnecting,
  disconnected,
}

enum AvoraSeatRetentionAction {
  retain,
  release,
}

enum AvoraSeatReleaseReason {
  none,
  explicitUserLeave,
  moderatorDrop,
  safetyTermination,
  sessionEnded,
  reconnectGraceExpired,
  sessionLeaseExpired,
}

enum AvoraBackgroundPresentation {
  normal,
  pictureInPicture,
  backgroundAudioControls,
  none,
}

class AvoraSessionContinuityPolicy {
  /// Short network/app interruptions retain the seat.
  final Duration reconnectGrace;

  /// Server session lease beyond the latest valid heartbeat.
  final Duration sessionLease;

  /// Minimize/background never drops seat by itself.
  final bool retainSeatWhenBackgrounded;

  /// PiP never changes backend seat ownership.
  final bool retainSeatInPictureInPicture;

  /// Mic mute never drops seat by itself.
  final bool retainSeatWhenSelfMicMuted;

  /// Background presence is NOT salary-valid by default.
  final bool allowBackgroundValidPerformance;

  /// PiP may remain valid for video-performance policies
  /// if an explicit policy later enables it.
  final bool allowPipValidPerformance;

  const AvoraSessionContinuityPolicy({
    this.reconnectGrace = const Duration(minutes: 2),
    this.sessionLease = const Duration(minutes: 5),
    this.retainSeatWhenBackgrounded = true,
    this.retainSeatInPictureInPicture = true,
    this.retainSeatWhenSelfMicMuted = true,
    this.allowBackgroundValidPerformance = false,
    this.allowPipValidPerformance = false,
  });
}

class AvoraSessionLease {
  final String sessionId;

  final String userAvoraId;

  final String roomId;

  final AvoraSessionSurface surface;

  final DateTime startedAt;

  /// Latest authoritative heartbeat accepted by server.
  final DateTime lastHeartbeatAt;

  /// When realtime connection was first observed disconnected.
  final DateTime? disconnectedAt;

  const AvoraSessionLease({
    required this.sessionId,
    required this.userAvoraId,
    required this.roomId,
    required this.surface,
    required this.startedAt,
    required this.lastHeartbeatAt,
    this.disconnectedAt,
  });
}

class AvoraSeatContinuityContext {
  final AvoraSessionLease lease;

  final AvoraClientVisibility visibility;

  final AvoraRealtimeConnectionState connectionState;

  final DateTime now;

  final bool selfMicMuted;

  final bool explicitUserLeave;

  final bool moderatorDroppedSeat;

  final bool safetyTerminated;

  final bool sessionEnded;

  const AvoraSeatContinuityContext({
    required this.lease,
    required this.visibility,
    required this.connectionState,
    required this.now,
    required this.selfMicMuted,
    this.explicitUserLeave = false,
    this.moderatorDroppedSeat = false,
    this.safetyTerminated = false,
    this.sessionEnded = false,
  });
}

class AvoraSeatContinuityDecision {
  final AvoraSeatRetentionAction action;

  final AvoraSeatReleaseReason releaseReason;

  final bool reconnecting;

  const AvoraSeatContinuityDecision({
    required this.action,
    required this.releaseReason,
    required this.reconnecting,
  });

  bool get retainSeat => action == AvoraSeatRetentionAction.retain;
}

class AvoraPerformanceContinuityContext {
  final AvoraClientVisibility visibility;

  final AvoraRealtimeConnectionState connectionState;

  final bool seated;

  final bool micUnmuted;

  /// For Live/Live-PK when a policy requires visible camera performance.
  final bool cameraPublishing;

  final bool afk;

  const AvoraPerformanceContinuityContext({
    required this.visibility,
    required this.connectionState,
    required this.seated,
    required this.micUnmuted,
    required this.cameraPublishing,
    required this.afk,
  });
}

class AvoraSessionContinuityEngine {
  const AvoraSessionContinuityEngine._();

  static AvoraSeatContinuityDecision evaluateSeatRetention({
    required AvoraSeatContinuityContext context,
    required AvoraSessionContinuityPolicy policy,
  }) {
    if (context.explicitUserLeave) {
      return const AvoraSeatContinuityDecision(
        action: AvoraSeatRetentionAction.release,
        releaseReason: AvoraSeatReleaseReason.explicitUserLeave,
        reconnecting: false,
      );
    }

    if (context.moderatorDroppedSeat) {
      return const AvoraSeatContinuityDecision(
        action: AvoraSeatRetentionAction.release,
        releaseReason: AvoraSeatReleaseReason.moderatorDrop,
        reconnecting: false,
      );
    }

    if (context.safetyTerminated) {
      return const AvoraSeatContinuityDecision(
        action: AvoraSeatRetentionAction.release,
        releaseReason: AvoraSeatReleaseReason.safetyTermination,
        reconnecting: false,
      );
    }

    if (context.sessionEnded) {
      return const AvoraSeatContinuityDecision(
        action: AvoraSeatRetentionAction.release,
        releaseReason: AvoraSeatReleaseReason.sessionEnded,
        reconnecting: false,
      );
    }

    final leaseAge = context.now.difference(context.lease.lastHeartbeatAt);

    if (leaseAge > policy.sessionLease) {
      return const AvoraSeatContinuityDecision(
        action: AvoraSeatRetentionAction.release,
        releaseReason: AvoraSeatReleaseReason.sessionLeaseExpired,
        reconnecting: false,
      );
    }

    if (context.connectionState == AvoraRealtimeConnectionState.disconnected) {
      final disconnectedAt = context.lease.disconnectedAt;

      if (disconnectedAt != null) {
        final disconnectedFor = context.now.difference(disconnectedAt);

        if (disconnectedFor > policy.reconnectGrace) {
          return const AvoraSeatContinuityDecision(
            action: AvoraSeatRetentionAction.release,
            releaseReason: AvoraSeatReleaseReason.reconnectGraceExpired,
            reconnecting: false,
          );
        }
      }

      return const AvoraSeatContinuityDecision(
        action: AvoraSeatRetentionAction.retain,
        releaseReason: AvoraSeatReleaseReason.none,
        reconnecting: true,
      );
    }

    /// Background/minimize/PiP do not release seat.
    if (context.visibility == AvoraClientVisibility.background &&
        policy.retainSeatWhenBackgrounded) {
      return const AvoraSeatContinuityDecision(
        action: AvoraSeatRetentionAction.retain,
        releaseReason: AvoraSeatReleaseReason.none,
        reconnecting: false,
      );
    }

    if (context.visibility == AvoraClientVisibility.pictureInPicture &&
        policy.retainSeatInPictureInPicture) {
      return const AvoraSeatContinuityDecision(
        action: AvoraSeatRetentionAction.retain,
        releaseReason: AvoraSeatReleaseReason.none,
        reconnecting: false,
      );
    }

    if (context.selfMicMuted && policy.retainSeatWhenSelfMicMuted) {
      return const AvoraSeatContinuityDecision(
        action: AvoraSeatRetentionAction.retain,
        releaseReason: AvoraSeatReleaseReason.none,
        reconnecting: false,
      );
    }

    return const AvoraSeatContinuityDecision(
      action: AvoraSeatRetentionAction.retain,
      releaseReason: AvoraSeatReleaseReason.none,
      reconnecting: false,
    );
  }

  static AvoraBackgroundPresentation presentationFor({
    required AvoraSessionSurface surface,
    required AvoraClientVisibility visibility,
    required bool platformSupportsPictureInPicture,
  }) {
    if (visibility == AvoraClientVisibility.foreground) {
      return AvoraBackgroundPresentation.normal;
    }

    final videoSurface = surface == AvoraSessionSurface.live ||
        surface == AvoraSessionSurface.livePk;

    if (videoSurface && platformSupportsPictureInPicture) {
      return AvoraBackgroundPresentation.pictureInPicture;
    }

    final audioSurface = surface == AvoraSessionSurface.voiceRoom ||
        surface == AvoraSessionSurface.audioPk;

    if (audioSurface) {
      return AvoraBackgroundPresentation.backgroundAudioControls;
    }

    return AvoraBackgroundPresentation.none;
  }

  static bool countsAsValidPerformance({
    required AvoraSessionSurface surface,
    required AvoraPerformanceContinuityContext context,
    required AvoraSessionContinuityPolicy policy,
    required bool requireMicUnmuted,
    required bool requireCameraPublishing,
  }) {
    if (context.connectionState != AvoraRealtimeConnectionState.connected) {
      return false;
    }

    if (!context.seated || context.afk) {
      return false;
    }

    if (requireMicUnmuted && !context.micUnmuted) {
      return false;
    }

    if (requireCameraPublishing && !context.cameraPublishing) {
      return false;
    }

    if (context.visibility == AvoraClientVisibility.background) {
      return policy.allowBackgroundValidPerformance;
    }

    if (context.visibility == AvoraClientVisibility.pictureInPicture) {
      final videoSurface = surface == AvoraSessionSurface.live ||
          surface == AvoraSessionSurface.livePk;

      return videoSurface && policy.allowPipValidPerformance;
    }

    return true;
  }

  /// App minimize alone must never drop a seat.
  static bool minimizeDropsSeat() {
    return false;
  }

  /// Self mic mute alone must never drop a seat.
  static bool selfMicMuteDropsSeat() {
    return false;
  }

  /// Floating/PiP UI is not the source of backend seat truth.
  static bool pictureInPictureControlsSeatOwnership() {
    return false;
  }

  /// Seat persistence and salary-valid time are separate systems.
  static bool retainedSeatAutomaticallyMeansValidWorkTime() {
    return false;
  }
}
