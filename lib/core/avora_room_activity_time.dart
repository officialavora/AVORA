enum AvoraRoomActivityEventType {
  roomJoined,
  roomLeft,
  seatTaken,
  seatLeft,
  micUnmuted,
  micMuted,
  speakingStarted,
  speakingStopped,
  mediaStarted,
  mediaStopped,
  disconnected,
  reconnected,
  afkStarted,
  afkEnded,
  duplicateSessionStarted,
  duplicateSessionEnded,
  policyEligibleStarted,
  policyEligibleStopped,
}

enum AvoraRoomTimeExclusionReason {
  notInRoom,
  disconnected,
  afk,
  duplicateSession,
  notSeated,
  microphoneMuted,
  notSpeaking,
  policyExcluded,
}

class AvoraRoomActivityEvent {
  final String id;

  final String roomId;

  final String userAvoraId;

  final String sessionId;

  final AvoraRoomActivityEventType type;

  /// Server-authoritative timestamp.
  final DateTime occurredAt;

  /// Optional music/media/source reference.
  final String? sourceId;

  const AvoraRoomActivityEvent({
    required this.id,
    required this.roomId,
    required this.userAvoraId,
    required this.sessionId,
    required this.type,
    required this.occurredAt,
    this.sourceId,
  });
}

class AvoraValidHostingTimePolicy {
  /// Host must actually be inside the room.
  final bool requireRoomPresence;

  /// Example: policy may require the host to be on a seat.
  final bool requireSeated;

  /// AVORA default for hosting-time policies:
  /// mic-muted time does not count.
  final bool requireMicUnmuted;

  /// Optional stricter policy.
  final bool requireSpeakingActivity;

  final bool excludeAfk;
  final bool excludeDisconnected;
  final bool excludeDuplicateSession;
  final bool requirePolicyEligibleMode;

  const AvoraValidHostingTimePolicy({
    this.requireRoomPresence = true,
    this.requireSeated = true,
    this.requireMicUnmuted = true,
    this.requireSpeakingActivity = false,
    this.excludeAfk = true,
    this.excludeDisconnected = true,
    this.excludeDuplicateSession = true,
    this.requirePolicyEligibleMode = true,
  });
}

class AvoraRoomActivityReport {
  final String roomId;
  final String userAvoraId;

  final DateTime periodStart;
  final DateTime periodEnd;

  final int roomPresenceSeconds;
  final int seatedSeconds;
  final int micUnmutedSeconds;
  final int speakingSeconds;
  final int mediaPlaybackSeconds;

  /// Salary/hosting-valid time after all policy checks.
  final int validHostingSeconds;

  final Map<AvoraRoomTimeExclusionReason, int> excludedSecondsByReason;

  const AvoraRoomActivityReport({
    required this.roomId,
    required this.userAvoraId,
    required this.periodStart,
    required this.periodEnd,
    required this.roomPresenceSeconds,
    required this.seatedSeconds,
    required this.micUnmutedSeconds,
    required this.speakingSeconds,
    required this.mediaPlaybackSeconds,
    required this.validHostingSeconds,
    required this.excludedSecondsByReason,
  });

  int get validHostingMinutes => validHostingSeconds ~/ 60;

  int get roomPresenceMinutes => roomPresenceSeconds ~/ 60;

  int get seatedMinutes => seatedSeconds ~/ 60;

  int get micUnmutedMinutes => micUnmutedSeconds ~/ 60;

  int get mediaPlaybackMinutes => mediaPlaybackSeconds ~/ 60;
}

class _ActivityState {
  bool inRoom = false;
  bool seated = false;
  bool micUnmuted = false;
  bool speaking = false;
  bool mediaPlaying = false;
  bool connected = true;
  bool afk = false;
  bool duplicateSession = false;
  bool policyEligible = true;
}

class _ActivityAccumulator {
  int roomPresenceSeconds = 0;
  int seatedSeconds = 0;
  int micUnmutedSeconds = 0;
  int speakingSeconds = 0;
  int mediaPlaybackSeconds = 0;
  int validHostingSeconds = 0;

  final Map<AvoraRoomTimeExclusionReason, int> excludedSecondsByReason = {};
}

class AvoraRoomActivityTimeEngine {
  const AvoraRoomActivityTimeEngine._();

  static void _applyEvent(
    _ActivityState state,
    AvoraRoomActivityEventType type,
  ) {
    switch (type) {
      case AvoraRoomActivityEventType.roomJoined:
        state.inRoom = true;
        break;

      case AvoraRoomActivityEventType.roomLeft:
        state.inRoom = false;
        state.seated = false;
        state.micUnmuted = false;
        state.speaking = false;
        state.mediaPlaying = false;
        break;

      case AvoraRoomActivityEventType.seatTaken:
        state.seated = true;
        break;

      case AvoraRoomActivityEventType.seatLeft:
        state.seated = false;
        state.micUnmuted = false;
        state.speaking = false;
        break;

      case AvoraRoomActivityEventType.micUnmuted:
        state.micUnmuted = true;
        break;

      case AvoraRoomActivityEventType.micMuted:
        state.micUnmuted = false;
        state.speaking = false;
        break;

      case AvoraRoomActivityEventType.speakingStarted:
        state.speaking = true;
        break;

      case AvoraRoomActivityEventType.speakingStopped:
        state.speaking = false;
        break;

      case AvoraRoomActivityEventType.mediaStarted:
        state.mediaPlaying = true;
        break;

      case AvoraRoomActivityEventType.mediaStopped:
        state.mediaPlaying = false;
        break;

      case AvoraRoomActivityEventType.disconnected:
        state.connected = false;
        state.speaking = false;
        break;

      case AvoraRoomActivityEventType.reconnected:
        state.connected = true;
        break;

      case AvoraRoomActivityEventType.afkStarted:
        state.afk = true;
        break;

      case AvoraRoomActivityEventType.afkEnded:
        state.afk = false;
        break;

      case AvoraRoomActivityEventType.duplicateSessionStarted:
        state.duplicateSession = true;
        break;

      case AvoraRoomActivityEventType.duplicateSessionEnded:
        state.duplicateSession = false;
        break;

      case AvoraRoomActivityEventType.policyEligibleStarted:
        state.policyEligible = true;
        break;

      case AvoraRoomActivityEventType.policyEligibleStopped:
        state.policyEligible = false;
        break;
    }
  }

  static void _addExcluded(
    _ActivityAccumulator accumulator,
    AvoraRoomTimeExclusionReason reason,
    int seconds,
  ) {
    accumulator.excludedSecondsByReason.update(
      reason,
      (value) => value + seconds,
      ifAbsent: () => seconds,
    );
  }

  static bool _isValidHostingState({
    required _ActivityState state,
    required AvoraValidHostingTimePolicy policy,
  }) {
    if (policy.requireRoomPresence && !state.inRoom) {
      return false;
    }

    if (policy.excludeDisconnected && !state.connected) {
      return false;
    }

    if (policy.excludeAfk && state.afk) {
      return false;
    }

    if (policy.excludeDuplicateSession && state.duplicateSession) {
      return false;
    }

    if (policy.requirePolicyEligibleMode && !state.policyEligible) {
      return false;
    }

    if (policy.requireSeated && !state.seated) {
      return false;
    }

    if (policy.requireMicUnmuted && !state.micUnmuted) {
      return false;
    }

    if (policy.requireSpeakingActivity && !state.speaking) {
      return false;
    }

    return true;
  }

  static AvoraRoomTimeExclusionReason? _primaryExclusionReason({
    required _ActivityState state,
    required AvoraValidHostingTimePolicy policy,
  }) {
    if (policy.requireRoomPresence && !state.inRoom) {
      return AvoraRoomTimeExclusionReason.notInRoom;
    }

    if (policy.excludeDisconnected && !state.connected) {
      return AvoraRoomTimeExclusionReason.disconnected;
    }

    if (policy.excludeAfk && state.afk) {
      return AvoraRoomTimeExclusionReason.afk;
    }

    if (policy.excludeDuplicateSession && state.duplicateSession) {
      return AvoraRoomTimeExclusionReason.duplicateSession;
    }

    if (policy.requirePolicyEligibleMode && !state.policyEligible) {
      return AvoraRoomTimeExclusionReason.policyExcluded;
    }

    if (policy.requireSeated && !state.seated) {
      return AvoraRoomTimeExclusionReason.notSeated;
    }

    if (policy.requireMicUnmuted && !state.micUnmuted) {
      return AvoraRoomTimeExclusionReason.microphoneMuted;
    }

    if (policy.requireSpeakingActivity && !state.speaking) {
      return AvoraRoomTimeExclusionReason.notSpeaking;
    }

    return null;
  }

  static void _accumulateInterval({
    required _ActivityState state,
    required _ActivityAccumulator accumulator,
    required AvoraValidHostingTimePolicy policy,
    required int seconds,
  }) {
    if (seconds <= 0) {
      return;
    }

    if (state.inRoom && state.connected) {
      accumulator.roomPresenceSeconds += seconds;
    }

    if (state.inRoom && state.connected && state.seated) {
      accumulator.seatedSeconds += seconds;
    }

    if (state.inRoom && state.connected && state.micUnmuted) {
      accumulator.micUnmutedSeconds += seconds;
    }

    if (state.inRoom && state.connected && state.micUnmuted && state.speaking) {
      accumulator.speakingSeconds += seconds;
    }

    /// Music/media is deliberately independent of microphone mute.
    if (state.inRoom && state.connected && state.mediaPlaying) {
      accumulator.mediaPlaybackSeconds += seconds;
    }

    if (_isValidHostingState(
      state: state,
      policy: policy,
    )) {
      accumulator.validHostingSeconds += seconds;
      return;
    }

    final reason = _primaryExclusionReason(
      state: state,
      policy: policy,
    );

    if (reason != null && state.inRoom) {
      _addExcluded(
        accumulator,
        reason,
        seconds,
      );
    }
  }

  static AvoraRoomActivityReport buildReport({
    required String roomId,
    required String userAvoraId,
    required DateTime periodStart,
    required DateTime periodEnd,
    required List<AvoraRoomActivityEvent> events,
    required AvoraValidHostingTimePolicy policy,
  }) {
    if (!periodEnd.isAfter(periodStart)) {
      throw ArgumentError(
        'periodEnd must be after periodStart.',
      );
    }

    final relevant = events
        .where(
          (event) =>
              event.roomId == roomId &&
              event.userAvoraId == userAvoraId &&
              !event.occurredAt.isAfter(periodEnd),
        )
        .toList(growable: true)
      ..sort(
        (a, b) => a.occurredAt.compareTo(b.occurredAt),
      );

    final state = _ActivityState();
    final accumulator = _ActivityAccumulator();

    /// Replay events before the requested period so the
    /// starting state is reconstructed server-side.
    for (final event in relevant) {
      if (event.occurredAt.isBefore(periodStart)) {
        _applyEvent(state, event.type);
      }
    }

    var cursor = periodStart;

    for (final event in relevant) {
      if (event.occurredAt.isBefore(periodStart)) {
        continue;
      }

      if (event.occurredAt.isAfter(periodEnd)) {
        break;
      }

      final seconds = event.occurredAt.difference(cursor).inSeconds;

      _accumulateInterval(
        state: state,
        accumulator: accumulator,
        policy: policy,
        seconds: seconds,
      );

      _applyEvent(state, event.type);
      cursor = event.occurredAt;
    }

    final remaining = periodEnd.difference(cursor).inSeconds;

    _accumulateInterval(
      state: state,
      accumulator: accumulator,
      policy: policy,
      seconds: remaining,
    );

    return AvoraRoomActivityReport(
      roomId: roomId,
      userAvoraId: userAvoraId,
      periodStart: periodStart,
      periodEnd: periodEnd,
      roomPresenceSeconds: accumulator.roomPresenceSeconds,
      seatedSeconds: accumulator.seatedSeconds,
      micUnmutedSeconds: accumulator.micUnmutedSeconds,
      speakingSeconds: accumulator.speakingSeconds,
      mediaPlaybackSeconds: accumulator.mediaPlaybackSeconds,
      validHostingSeconds: accumulator.validHostingSeconds,
      excludedSecondsByReason: Map.unmodifiable(
        accumulator.excludedSecondsByReason,
      ),
    );
  }
}

enum AvoraRoomAudioBus {
  microphoneVoice,
  musicMedia,
}

class AvoraRoomParticipantAudioState {
  final String userAvoraId;

  /// User muted their own microphone.
  final bool selfMicMuted;

  /// Room moderator muted this user's microphone.
  final bool moderationMicMuted;

  /// User is currently playing an approved song/media source.
  final bool mediaPlaying;

  /// Moderator stopped this participant's media source.
  final bool moderationMediaStopped;

  const AvoraRoomParticipantAudioState({
    required this.userAvoraId,
    this.selfMicMuted = false,
    this.moderationMicMuted = false,
    this.mediaPlaying = false,
    this.moderationMediaStopped = false,
  });

  bool get canTransmitMicrophoneVoice => !selfMicMuted && !moderationMicMuted;

  /// Mic mute does not stop the separate music/media bus.
  bool get canTransmitMedia => mediaPlaying && !moderationMediaStopped;
}

class AvoraListenerAudioPreference {
  final String listenerAvoraId;

  /// Local-only mute. Other listeners are unaffected.
  final Set<String> locallyMutedVoiceUserIds;

  /// Local-only media/song mute.
  final Set<String> locallyMutedMediaUserIds;

  /// User locally muted all room playback.
  final bool muteAllRoomAudio;

  const AvoraListenerAudioPreference({
    required this.listenerAvoraId,
    this.locallyMutedVoiceUserIds = const {},
    this.locallyMutedMediaUserIds = const {},
    this.muteAllRoomAudio = false,
  });
}

class AvoraRoomAudioRoutingPolicy {
  const AvoraRoomAudioRoutingPolicy._();

  static bool listenerHearsMicrophone({
    required AvoraRoomParticipantAudioState participant,
    required AvoraListenerAudioPreference listener,
  }) {
    if (listener.muteAllRoomAudio) {
      return false;
    }

    if (listener.locallyMutedVoiceUserIds.contains(
      participant.userAvoraId,
    )) {
      return false;
    }

    return participant.canTransmitMicrophoneVoice;
  }

  static bool listenerHearsMedia({
    required AvoraRoomParticipantAudioState participant,
    required AvoraListenerAudioPreference listener,
  }) {
    if (listener.muteAllRoomAudio) {
      return false;
    }

    if (listener.locallyMutedMediaUserIds.contains(
      participant.userAvoraId,
    )) {
      return false;
    }

    return participant.canTransmitMedia;
  }

  /// Critical AVORA behavior:
  /// mic mute does not automatically mute song/music playback.
  static bool micMuteStopsMediaBus() {
    return false;
  }

  /// Song playback never pretends to be microphone-active time.
  static bool mediaPlaybackCountsAsMicActiveTime() {
    return false;
  }

  /// Local listener mute affects only that listener.
  static bool localMuteChangesRoomWideAudio() {
    return false;
  }
}

class AvoraHostPeriodTimeRequirement {
  /// Example: 15 valid days. Configurable.
  final int requiredValidDays;

  /// Example: 2 hours/day = 7200 seconds. Configurable.
  final int minimumValidSecondsPerDay;

  const AvoraHostPeriodTimeRequirement({
    required this.requiredValidDays,
    required this.minimumValidSecondsPerDay,
  })  : assert(requiredValidDays >= 0),
        assert(minimumValidSecondsPerDay >= 0);
}

class AvoraHostPeriodTimeQualification {
  final int validDays;
  final int requiredValidDays;
  final bool qualified;

  const AvoraHostPeriodTimeQualification({
    required this.validDays,
    required this.requiredValidDays,
    required this.qualified,
  });
}

class AvoraHostTimeQualificationEngine {
  const AvoraHostTimeQualificationEngine._();

  static AvoraHostPeriodTimeQualification evaluate({
    required List<AvoraRoomActivityReport> dailyReports,
    required AvoraHostPeriodTimeRequirement requirement,
  }) {
    final validDays = dailyReports
        .where(
          (report) =>
              report.validHostingSeconds >=
              requirement.minimumValidSecondsPerDay,
        )
        .length;

    return AvoraHostPeriodTimeQualification(
      validDays: validDays,
      requiredValidDays: requirement.requiredValidDays,
      qualified: validDays >= requirement.requiredValidDays,
    );
  }
}
