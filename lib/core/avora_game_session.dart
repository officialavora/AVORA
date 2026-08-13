import 'avora_game_hub.dart';

enum AvoraGameSessionState {
  created,
  waitingForPlayers,
  ready,
  active,
  paused,
  completed,
  cancelled,
  abandoned,
}

enum AvoraGameParticipantState {
  invited,
  joined,
  ready,
  playing,
  disconnected,
  left,
  removed,
}

enum AvoraGameSessionEventType {
  sessionCreated,
  participantInvited,
  participantJoined,
  participantReady,
  participantDisconnected,
  participantReconnected,
  participantLeft,
  participantRemoved,
  matchStarted,
  matchPaused,
  matchResumed,
  matchCompleted,
  matchCancelled,
  roomLinked,
  roomUnlinked,
}

class AvoraGameSessionParticipant {
  /// Immutable authoritative AVORA ID.
  final String avoraId;

  final AvoraGameParticipantState state;

  final DateTime joinedAt;
  final DateTime? leftAt;

  /// Optional team/side/seat reference.
  final String? positionRef;

  final bool host;
  final bool ready;

  const AvoraGameSessionParticipant({
    required this.avoraId,
    required this.state,
    required this.joinedAt,
    this.leftAt,
    this.positionRef,
    this.host = false,
    this.ready = false,
  });
}

class AvoraGameSessionEvent {
  final String eventId;
  final String sessionId;

  final AvoraGameSessionEventType type;

  /// Actor AVORA ID when applicable.
  final String? actorAvoraId;

  final DateTime occurredAt;

  final Map<String, String> metadata;

  const AvoraGameSessionEvent({
    required this.eventId,
    required this.sessionId,
    required this.type,
    required this.occurredAt,
    this.actorAvoraId,
    this.metadata = const {},
  });
}

class AvoraGameSessionPolicy {
  final String policyVersionId;

  final String gameId;

  /// Uses existing Game Hub modes.
  final Set<AvoraGameMode> supportedModes;

  final int minimumPlayers;
  final int maximumPlayers;

  /// Whether a meaningful single-player mode exists.
  final bool supportsSolo;

  /// Whether AI/bot practice is supported.
  final bool supportsSoloPractice;

  final bool supportsPrivateInvite;
  final bool supportsRoomParty;
  final bool supportsRandomMatch;
  final bool supportsSpectators;

  /// If linked to a room, game UI must preserve
  /// meaningful room awareness.
  final bool preserveRoomPresenceWhilePlaying;

  /// Show compact join/leave/relevant room event indicators
  /// while game UI is active.
  final bool showRoomEventOverlay;

  /// Room voice remains logically available unless
  /// the user intentionally changes audio settings.
  final bool preserveRoomAudioContext;

  const AvoraGameSessionPolicy({
    required this.policyVersionId,
    required this.gameId,
    required this.supportedModes,
    required this.minimumPlayers,
    required this.maximumPlayers,
    required this.supportsSolo,
    required this.supportsSoloPractice,
    required this.supportsPrivateInvite,
    required this.supportsRoomParty,
    required this.supportsRandomMatch,
    required this.supportsSpectators,
    this.preserveRoomPresenceWhilePlaying = true,
    this.showRoomEventOverlay = true,
    this.preserveRoomAudioContext = true,
  })  : assert(minimumPlayers >= 1),
        assert(maximumPlayers >= minimumPlayers);
}

class AvoraGameSession {
  final String sessionId;
  final String gameId;

  final AvoraGameMode mode;

  final AvoraGameSessionState state;

  final String policyVersionId;

  /// Optional linked social voice room.
  final String? roomId;

  /// Optional virtual-coin round/match reference.
  final String? gameRoundId;

  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  final List<AvoraGameSessionParticipant> participants;

  const AvoraGameSession({
    required this.sessionId,
    required this.gameId,
    required this.mode,
    required this.state,
    required this.policyVersionId,
    required this.createdAt,
    required this.participants,
    this.roomId,
    this.gameRoundId,
    this.startedAt,
    this.completedAt,
  });
}

enum AvoraGameSessionDenyReason {
  none,
  unsupportedMode,
  invalidPlayerLimit,
  sessionNotJoinable,
  duplicateParticipant,
  sessionFull,
  soloRequiresSinglePlayer,
  multiplayerRequiresMultiplePlayers,
}

class AvoraGameSessionDecision {
  final bool allowed;
  final AvoraGameSessionDenyReason reason;

  const AvoraGameSessionDecision({
    required this.allowed,
    required this.reason,
  });
}

class AvoraGameRoomOverlayState {
  final bool visible;

  final String? roomId;

  final int roomParticipantCount;

  final int recentJoinCount;
  final int recentLeaveCount;

  /// Optional lightweight indicators rather than
  /// replacing the actual room participant model.
  final List<String> recentlyActiveAvoraIds;

  const AvoraGameRoomOverlayState({
    required this.visible,
    required this.roomId,
    required this.roomParticipantCount,
    required this.recentJoinCount,
    required this.recentLeaveCount,
    this.recentlyActiveAvoraIds = const [],
  });
}

class AvoraGameSessionStatistics {
  final String sessionId;
  final String gameId;

  final int uniqueParticipantCount;

  final int joinEventCount;
  final int leaveEventCount;
  final int reconnectEventCount;

  final Duration? activeDuration;

  const AvoraGameSessionStatistics({
    required this.sessionId,
    required this.gameId,
    required this.uniqueParticipantCount,
    required this.joinEventCount,
    required this.leaveEventCount,
    required this.reconnectEventCount,
    required this.activeDuration,
  });
}

class AvoraGameSessionEngine {
  const AvoraGameSessionEngine._();

  static bool supportsMode({
    required AvoraGameSessionPolicy policy,
    required AvoraGameMode mode,
  }) {
    if (!policy.supportedModes.contains(mode)) {
      return false;
    }

    switch (mode) {
      case AvoraGameMode.solo:
        return policy.supportsSolo;

      case AvoraGameMode.privateInvite:
        return policy.supportsPrivateInvite;

      case AvoraGameMode.roomParty:
        return policy.supportsRoomParty;

      case AvoraGameMode.randomMatch:
        return policy.supportsRandomMatch;

      case AvoraGameMode.spectator:
        return policy.supportsSpectators;
    }
  }

  static AvoraGameSessionDecision canCreate({
    required AvoraGameSessionPolicy policy,
    required AvoraGameMode mode,
    required int requestedPlayerSlots,
  }) {
    if (!supportsMode(policy: policy, mode: mode)) {
      return const AvoraGameSessionDecision(
        allowed: false,
        reason: AvoraGameSessionDenyReason.unsupportedMode,
      );
    }

    if (requestedPlayerSlots < policy.minimumPlayers ||
        requestedPlayerSlots > policy.maximumPlayers) {
      return const AvoraGameSessionDecision(
        allowed: false,
        reason: AvoraGameSessionDenyReason.invalidPlayerLimit,
      );
    }

    if (mode == AvoraGameMode.solo && requestedPlayerSlots != 1) {
      return const AvoraGameSessionDecision(
        allowed: false,
        reason: AvoraGameSessionDenyReason.soloRequiresSinglePlayer,
      );
    }

    return const AvoraGameSessionDecision(
      allowed: true,
      reason: AvoraGameSessionDenyReason.none,
    );
  }

  static AvoraGameSessionDecision canJoin({
    required AvoraGameSession session,
    required AvoraGameSessionPolicy policy,
    required String joiningAvoraId,
  }) {
    final joinable = session.state == AvoraGameSessionState.created ||
        session.state == AvoraGameSessionState.waitingForPlayers ||
        session.state == AvoraGameSessionState.ready;

    if (!joinable) {
      return const AvoraGameSessionDecision(
        allowed: false,
        reason: AvoraGameSessionDenyReason.sessionNotJoinable,
      );
    }

    if (session.participants.any(
      (participant) =>
          participant.avoraId == joiningAvoraId &&
          participant.state != AvoraGameParticipantState.left &&
          participant.state != AvoraGameParticipantState.removed,
    )) {
      return const AvoraGameSessionDecision(
        allowed: false,
        reason: AvoraGameSessionDenyReason.duplicateParticipant,
      );
    }

    final activeCount = session.participants
        .where(
          (participant) =>
              participant.state != AvoraGameParticipantState.left &&
              participant.state != AvoraGameParticipantState.removed,
        )
        .length;

    if (activeCount >= policy.maximumPlayers) {
      return const AvoraGameSessionDecision(
        allowed: false,
        reason: AvoraGameSessionDenyReason.sessionFull,
      );
    }

    return const AvoraGameSessionDecision(
      allowed: true,
      reason: AvoraGameSessionDenyReason.none,
    );
  }

  static AvoraGameRoomOverlayState buildRoomOverlay({
    required AvoraGameSession session,
    required AvoraGameSessionPolicy policy,
    required int roomParticipantCount,
    required List<AvoraGameSessionEvent> recentEvents,
  }) {
    if (session.roomId == null ||
        !policy.preserveRoomPresenceWhilePlaying ||
        !policy.showRoomEventOverlay) {
      return AvoraGameRoomOverlayState(
        visible: false,
        roomId: session.roomId,
        roomParticipantCount: roomParticipantCount,
        recentJoinCount: 0,
        recentLeaveCount: 0,
      );
    }

    final joins = recentEvents
        .where(
          (event) => event.type == AvoraGameSessionEventType.participantJoined,
        )
        .length;

    final leaves = recentEvents
        .where(
          (event) =>
              event.type == AvoraGameSessionEventType.participantLeft ||
              event.type == AvoraGameSessionEventType.participantRemoved,
        )
        .length;

    final activeIds = recentEvents
        .map((event) => event.actorAvoraId)
        .whereType<String>()
        .toSet()
        .toList(growable: false);

    return AvoraGameRoomOverlayState(
      visible: true,
      roomId: session.roomId,
      roomParticipantCount: roomParticipantCount,
      recentJoinCount: joins,
      recentLeaveCount: leaves,
      recentlyActiveAvoraIds: activeIds,
    );
  }

  static AvoraGameSessionStatistics buildStatistics({
    required AvoraGameSession session,
    required List<AvoraGameSessionEvent> events,
  }) {
    final uniqueIds = <String>{
      for (final participant in session.participants) participant.avoraId,
      for (final event in events)
        if (event.actorAvoraId != null) event.actorAvoraId!,
    };

    final joins = events
        .where(
          (event) => event.type == AvoraGameSessionEventType.participantJoined,
        )
        .length;

    final leaves = events
        .where(
          (event) =>
              event.type == AvoraGameSessionEventType.participantLeft ||
              event.type == AvoraGameSessionEventType.participantRemoved,
        )
        .length;

    final reconnects = events
        .where(
          (event) =>
              event.type == AvoraGameSessionEventType.participantReconnected,
        )
        .length;

    final activeDuration =
        session.startedAt != null && session.completedAt != null
            ? session.completedAt!.difference(session.startedAt!)
            : null;

    return AvoraGameSessionStatistics(
      sessionId: session.sessionId,
      gameId: session.gameId,
      uniqueParticipantCount: uniqueIds.length,
      joinEventCount: joins,
      leaveEventCount: leaves,
      reconnectEventCount: reconnects,
      activeDuration: activeDuration,
    );
  }

  /// Game opening never makes room membership disappear.
  static bool openingGameAutomaticallyLeavesRoom() {
    return false;
  }

  /// Room presence remains available in a compact game UI layer.
  static bool gameMustCompletelyHideRoomPresence() {
    return false;
  }

  /// A game may expose only modes that genuinely fit its mechanics.
  static bool everyGameMustSupportEveryMode() {
    return false;
  }

  /// Random matchmaking never changes the immutable AVORA identity.
  static bool randomMatchCreatesTemporaryUserIdentity() {
    return false;
  }

  /// Session history is server-side/auditable, not client-only.
  static bool gameSessionHistoryMayExistOnlyOnClient() {
    return false;
  }

  /// Game visual UI never becomes authoritative for coin settlement.
  static bool gameScreenControlsAuthoritativeSettlement() {
    return false;
  }

  /// Game session and virtual-coin round records can be linked
  /// without forcing every game to use wagering/round economics.
  static bool everyGameSessionRequiresVirtualCoinBet() {
    return false;
  }
}
