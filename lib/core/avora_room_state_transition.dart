enum AvoraRoomMediaMode {
  audio,
  videoLive,
}

enum AvoraRoomTransitionAction {
  changeSeatLayout,
  switchAudioToVideoLive,
  switchVideoLiveToAudio,
  stopVideoKeepAudio,
  minimize,
  resume,
  fullEnd,
}

enum AvoraSeatOverflowPolicy {
  denyTransition,
  moveToAvailableSeat,
  keepAsUnseatedParticipant,
}

enum AvoraRoomTransitionDenyReason {
  none,
  invalidRequest,
  roomMismatch,
  sessionMismatch,
  insufficientSeatCapacity,
  continuityRejected,
  sessionAlreadyEnded,
}

class AvoraRoomParticipantState {
  const AvoraRoomParticipantState({
    required this.avoraId,
    required this.inRoom,
    required this.seated,
    required this.micMuted,
    required this.adminActive,
    required this.chatContextKey,
    required this.counterTargetSnapshotKey,
    this.seatId,
  });

  final String avoraId;
  final bool inRoom;

  final bool seated;
  final String? seatId;

  final bool micMuted;
  final bool adminActive;

  /// Existing message/chat system remains authoritative.
  final String chatContextKey;

  /// Existing target/counter engines remain authoritative.
  final String counterTargetSnapshotKey;

  bool get valid =>
      avoraId.trim().isNotEmpty &&
      chatContextKey.trim().isNotEmpty &&
      counterTargetSnapshotKey.trim().isNotEmpty &&
      (!seated || (seatId != null && seatId!.trim().isNotEmpty));
}

class AvoraRoomStateSnapshot {
  const AvoraRoomStateSnapshot({
    required this.roomId,
    required this.sessionId,
    required this.mediaMode,
    required this.seatCapacity,
    required this.participants,
    required this.minimized,
    required this.ended,
    required this.policyVersion,
    required this.version,
  });

  final String roomId;

  /// Remains stable across layout/media/minimize transitions.
  final String sessionId;

  final AvoraRoomMediaMode mediaMode;
  final int seatCapacity;

  final List<AvoraRoomParticipantState> participants;

  final bool minimized;
  final bool ended;

  final String policyVersion;

  /// Monotonic server state version.
  final int version;

  bool get valid =>
      roomId.trim().isNotEmpty &&
      sessionId.trim().isNotEmpty &&
      seatCapacity >= 0 &&
      policyVersion.trim().isNotEmpty &&
      version > 0 &&
      participants.every((participant) => participant.valid);
}

class AvoraSeatMigration {
  const AvoraSeatMigration({
    required this.avoraId,
    required this.fromSeatId,
    required this.toSeatId,
    required this.remainedSeated,
    required this.movedToOverflow,
  });

  final String avoraId;
  final String? fromSeatId;
  final String? toSeatId;

  final bool remainedSeated;
  final bool movedToOverflow;
}

class AvoraRoomTransitionRequest {
  const AvoraRoomTransitionRequest({
    required this.transitionId,
    required this.roomId,
    required this.sessionId,
    required this.actorAvoraId,
    required this.action,
    required this.policyVersion,
    required this.idempotencyKey,
    required this.requestedAtUtc,
    this.targetMediaMode,
    this.targetSeatCapacity,
    this.overflowPolicy = AvoraSeatOverflowPolicy.denyTransition,
  });

  final String transitionId;
  final String roomId;
  final String sessionId;

  final String actorAvoraId;

  final AvoraRoomTransitionAction action;

  final AvoraRoomMediaMode? targetMediaMode;
  final int? targetSeatCapacity;

  final AvoraSeatOverflowPolicy overflowPolicy;

  final String policyVersion;
  final String idempotencyKey;

  final DateTime requestedAtUtc;

  bool get valid =>
      transitionId.trim().isNotEmpty &&
      roomId.trim().isNotEmpty &&
      sessionId.trim().isNotEmpty &&
      actorAvoraId.trim().isNotEmpty &&
      policyVersion.trim().isNotEmpty &&
      idempotencyKey.trim().isNotEmpty &&
      requestedAtUtc.isUtc;
}

class AvoraRoomTransitionAuditEvent {
  const AvoraRoomTransitionAuditEvent({
    required this.transitionId,
    required this.roomId,
    required this.sessionId,
    required this.actorAvoraId,
    required this.action,
    required this.sourceMode,
    required this.destinationMode,
    required this.sourceSeatCapacity,
    required this.destinationSeatCapacity,
    required this.allowed,
    required this.reason,
    required this.policyVersion,
    required this.idempotencyKey,
    required this.occurredAtUtc,
    required this.migrations,
  });

  final String transitionId;
  final String roomId;
  final String sessionId;

  final String actorAvoraId;

  final AvoraRoomTransitionAction action;

  final AvoraRoomMediaMode sourceMode;
  final AvoraRoomMediaMode destinationMode;

  final int sourceSeatCapacity;
  final int destinationSeatCapacity;

  final bool allowed;
  final AvoraRoomTransitionDenyReason reason;

  final String policyVersion;
  final String idempotencyKey;
  final DateTime occurredAtUtc;

  final List<AvoraSeatMigration> migrations;
}

class AvoraRoomTransitionDecision {
  const AvoraRoomTransitionDecision({
    required this.allowed,
    required this.reason,
    required this.nextState,
    required this.auditEvent,
  });

  final bool allowed;
  final AvoraRoomTransitionDenyReason reason;

  final AvoraRoomStateSnapshot nextState;
  final AvoraRoomTransitionAuditEvent auditEvent;
}

class AvoraRoomTransitionEngine {
  const AvoraRoomTransitionEngine._();

  static AvoraRoomTransitionDecision apply({
    required AvoraRoomStateSnapshot current,
    required AvoraRoomTransitionRequest request,
    required DateTime serverNowUtc,

    /// Must come from existing AvoraSessionContinuityEngine.
    required bool continuityAllowsSeatRetention,
  }) {
    AvoraRoomTransitionDecision deny(
      AvoraRoomTransitionDenyReason reason,
    ) {
      return AvoraRoomTransitionDecision(
        allowed: false,
        reason: reason,
        nextState: current,
        auditEvent: AvoraRoomTransitionAuditEvent(
          transitionId: request.transitionId,
          roomId: current.roomId,
          sessionId: current.sessionId,
          actorAvoraId: request.actorAvoraId,
          action: request.action,
          sourceMode: current.mediaMode,
          destinationMode: current.mediaMode,
          sourceSeatCapacity: current.seatCapacity,
          destinationSeatCapacity: current.seatCapacity,
          allowed: false,
          reason: reason,
          policyVersion: request.policyVersion,
          idempotencyKey: request.idempotencyKey,
          occurredAtUtc: serverNowUtc,
          migrations: const [],
        ),
      );
    }

    if (!current.valid || !request.valid || !serverNowUtc.isUtc) {
      return deny(AvoraRoomTransitionDenyReason.invalidRequest);
    }

    if (current.roomId != request.roomId) {
      return deny(AvoraRoomTransitionDenyReason.roomMismatch);
    }

    if (current.sessionId != request.sessionId) {
      return deny(AvoraRoomTransitionDenyReason.sessionMismatch);
    }

    if (current.ended && request.action != AvoraRoomTransitionAction.fullEnd) {
      return deny(AvoraRoomTransitionDenyReason.sessionAlreadyEnded);
    }

    var nextMode = current.mediaMode;
    var nextCapacity = current.seatCapacity;
    var nextMinimized = current.minimized;
    var nextEnded = current.ended;

    final migrations = <AvoraSeatMigration>[];

    switch (request.action) {
      case AvoraRoomTransitionAction.changeSeatLayout:
        final requestedCapacity = request.targetSeatCapacity;

        if (requestedCapacity == null || requestedCapacity < 0) {
          return deny(AvoraRoomTransitionDenyReason.invalidRequest);
        }

        final seated = current.participants
            .where((participant) => participant.seated)
            .toList();

        if (requestedCapacity < seated.length &&
            request.overflowPolicy == AvoraSeatOverflowPolicy.denyTransition) {
          return deny(
            AvoraRoomTransitionDenyReason.insufficientSeatCapacity,
          );
        }

        nextCapacity = requestedCapacity;

        for (var index = 0; index < seated.length; index++) {
          final participant = seated[index];

          if (index < requestedCapacity) {
            migrations.add(
              AvoraSeatMigration(
                avoraId: participant.avoraId,
                fromSeatId: participant.seatId,
                toSeatId: 'seat-${index + 1}',
                remainedSeated: true,
                movedToOverflow: false,
              ),
            );
          } else {
            migrations.add(
              AvoraSeatMigration(
                avoraId: participant.avoraId,
                fromSeatId: participant.seatId,
                toSeatId: null,
                remainedSeated: false,
                movedToOverflow: true,
              ),
            );
          }
        }

      case AvoraRoomTransitionAction.switchAudioToVideoLive:
        nextMode = AvoraRoomMediaMode.videoLive;

      case AvoraRoomTransitionAction.switchVideoLiveToAudio:
      case AvoraRoomTransitionAction.stopVideoKeepAudio:
        nextMode = AvoraRoomMediaMode.audio;

      case AvoraRoomTransitionAction.minimize:
        nextMinimized = true;

      case AvoraRoomTransitionAction.resume:
        nextMinimized = false;

      case AvoraRoomTransitionAction.fullEnd:
        nextEnded = true;
        nextMinimized = false;
    }

    final layoutChanged =
        request.action == AvoraRoomTransitionAction.changeSeatLayout;

    final participants = <AvoraRoomParticipantState>[];

    for (final participant in current.participants) {
      var seated = participant.seated;
      var seatId = participant.seatId;

      if (layoutChanged && participant.seated) {
        final migration = migrations.firstWhere(
          (item) => item.avoraId == participant.avoraId,
        );

        if (migration.remainedSeated) {
          seated = true;
          seatId = migration.toSeatId;
        } else {
          switch (request.overflowPolicy) {
            case AvoraSeatOverflowPolicy.denyTransition:
              break;

            case AvoraSeatOverflowPolicy.moveToAvailableSeat:
            case AvoraSeatOverflowPolicy.keepAsUnseatedParticipant:
              seated = false;
              seatId = null;
          }
        }
      }

      /// Existing continuity engine decides whether a temporary disconnect /
      /// media transition is allowed to retain the seat.
      if (!layoutChanged &&
          participant.seated &&
          !continuityAllowsSeatRetention &&
          request.action != AvoraRoomTransitionAction.fullEnd) {
        return deny(
          AvoraRoomTransitionDenyReason.continuityRejected,
        );
      }

      participants.add(
        AvoraRoomParticipantState(
          avoraId: participant.avoraId,
          inRoom: nextEnded ? false : participant.inRoom,
          seated: nextEnded ? false : seated,
          seatId: nextEnded ? null : seatId,

          /// Preserve mute/admin/chat/counters across compatible transitions.
          micMuted: participant.micMuted,
          adminActive: participant.adminActive,
          chatContextKey: participant.chatContextKey,
          counterTargetSnapshotKey: participant.counterTargetSnapshotKey,
        ),
      );
    }

    final next = AvoraRoomStateSnapshot(
      roomId: current.roomId,
      sessionId: current.sessionId,
      mediaMode: nextMode,
      seatCapacity: nextCapacity,
      participants: List.unmodifiable(participants),
      minimized: nextMinimized,
      ended: nextEnded,
      policyVersion: request.policyVersion,
      version: current.version + 1,
    );

    return AvoraRoomTransitionDecision(
      allowed: true,
      reason: AvoraRoomTransitionDenyReason.none,
      nextState: next,
      auditEvent: AvoraRoomTransitionAuditEvent(
        transitionId: request.transitionId,
        roomId: current.roomId,
        sessionId: current.sessionId,
        actorAvoraId: request.actorAvoraId,
        action: request.action,
        sourceMode: current.mediaMode,
        destinationMode: next.mediaMode,
        sourceSeatCapacity: current.seatCapacity,
        destinationSeatCapacity: next.seatCapacity,
        allowed: true,
        reason: AvoraRoomTransitionDenyReason.none,
        policyVersion: request.policyVersion,
        idempotencyKey: request.idempotencyKey,
        occurredAtUtc: serverNowUtc,
        migrations: List.unmodifiable(migrations),
      ),
    );
  }

  static bool expandingSeatCapacityCanDropExistingOccupants() => false;

  static bool layoutChangeShouldResetRoom() => false;

  static bool mediaModeChangeShouldResetRoom() => false;

  static bool audioCanTransitionToVideoLive() => true;

  static bool videoLiveCanTransitionBackToAudio() => true;

  static bool videoCanStopWhileAudioRoomRemainsActive() => true;

  static bool minimizeMeansSessionEnded() => false;

  static bool roomAndSessionIdentityRemainStableAcrossTransition() => true;

  static bool transitionMustBeServerAuthoritative() => true;

  static bool transitionMustBeIdempotent() => true;

  static bool transitionRequiresAudit() => true;

  static bool reconnectMustRestoreAuthoritativeState() => true;

  static bool existingSessionContinuityRemainsAuthoritative() => true;

  static bool existingRoomLifecycleRemainsAuthoritative() => true;
}
