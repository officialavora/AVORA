enum AvoraCallType {
  voice,
  video,
}

enum AvoraCallDirection {
  outgoing,
  incoming,
}

enum AvoraCallState {
  idle,

  // Outgoing setup.
  dialing,
  ringing,

  // Incoming setup.
  incoming,

  // Media/session establishment.
  connecting,

  // Connected media.
  active,

  // Second-call / concurrency states.
  waiting,
  held,

  // Temporary network recovery.
  reconnecting,

  // Terminal outcomes.
  busy,
  declined,
  missed,
  cancelled,
  failed,
  answeredElsewhere,
  ended,
}

enum AvoraCallEndReason {
  none,
  localEnded,
  remoteEnded,
  busy,
  declined,
  missed,
  cancelled,
  noAnswer,
  networkFailure,
  safetyTermination,
  answeredElsewhere,
  replacedByAnotherCall,
}

class AvoraCallSession {
  const AvoraCallSession({
    required this.callId,
    required this.callerAvoraId,
    required this.calleeAvoraId,
    required this.type,
    required this.direction,
    required this.state,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.connectedAtUtc,
    this.endedAtUtc,
    this.endReason = AvoraCallEndReason.none,
  });

  final String callId;

  /// Immutable AVORA IDs remain authoritative.
  final String callerAvoraId;
  final String calleeAvoraId;

  final AvoraCallType type;
  final AvoraCallDirection direction;
  final AvoraCallState state;

  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime? connectedAtUtc;
  final DateTime? endedAtUtc;
  final AvoraCallEndReason endReason;

  bool get isTerminal => AvoraCallStateEngine.isTerminalState(state);

  /// Calling Points must not be earned merely for ringing/waiting/busy time.
  /// Later admin policy may decide how held time is treated.
  bool get isDefaultBillable => state == AvoraCallState.active;

  bool get hasConnected =>
      connectedAtUtc != null ||
      state == AvoraCallState.active ||
      state == AvoraCallState.held ||
      state == AvoraCallState.reconnecting;

  bool get validIdentityBinding =>
      callId.trim().isNotEmpty &&
      callerAvoraId.trim().isNotEmpty &&
      calleeAvoraId.trim().isNotEmpty &&
      callerAvoraId.trim() != calleeAvoraId.trim();
}

class AvoraCallTransitionDecision {
  const AvoraCallTransitionDecision({
    required this.allowed,
    required this.next,
    required this.reason,
  });

  final bool allowed;
  final AvoraCallSession next;
  final String reason;
}

class AvoraCallStateEngine {
  const AvoraCallStateEngine._();

  static bool isTerminalState(AvoraCallState state) {
    return switch (state) {
      AvoraCallState.busy ||
      AvoraCallState.declined ||
      AvoraCallState.missed ||
      AvoraCallState.cancelled ||
      AvoraCallState.failed ||
      AvoraCallState.answeredElsewhere ||
      AvoraCallState.ended =>
        true,
      _ => false,
    };
  }

  static bool isAllowedTransition(
    AvoraCallState from,
    AvoraCallState to,
  ) {
    if (from == to) {
      return false;
    }

    if (isTerminalState(from)) {
      return false;
    }

    return switch (from) {
      AvoraCallState.idle =>
        to == AvoraCallState.dialing || to == AvoraCallState.incoming,
      AvoraCallState.dialing => to == AvoraCallState.ringing ||
          to == AvoraCallState.connecting ||
          to == AvoraCallState.busy ||
          to == AvoraCallState.declined ||
          to == AvoraCallState.cancelled ||
          to == AvoraCallState.failed,
      AvoraCallState.ringing => to == AvoraCallState.connecting ||
          to == AvoraCallState.busy ||
          to == AvoraCallState.declined ||
          to == AvoraCallState.cancelled ||
          to == AvoraCallState.missed ||
          to == AvoraCallState.failed,
      AvoraCallState.incoming => to == AvoraCallState.connecting ||
          to == AvoraCallState.waiting ||
          to == AvoraCallState.busy ||
          to == AvoraCallState.declined ||
          to == AvoraCallState.missed ||
          to == AvoraCallState.answeredElsewhere ||
          to == AvoraCallState.failed,
      AvoraCallState.connecting => to == AvoraCallState.active ||
          to == AvoraCallState.cancelled ||
          to == AvoraCallState.failed ||
          to == AvoraCallState.answeredElsewhere,
      AvoraCallState.active => to == AvoraCallState.held ||
          to == AvoraCallState.reconnecting ||
          to == AvoraCallState.ended ||
          to == AvoraCallState.failed,
      AvoraCallState.waiting => to == AvoraCallState.connecting ||
          to == AvoraCallState.busy ||
          to == AvoraCallState.declined ||
          to == AvoraCallState.missed ||
          to == AvoraCallState.answeredElsewhere ||
          to == AvoraCallState.failed,
      AvoraCallState.held => to == AvoraCallState.active ||
          to == AvoraCallState.reconnecting ||
          to == AvoraCallState.ended ||
          to == AvoraCallState.failed,
      AvoraCallState.reconnecting => to == AvoraCallState.active ||
          to == AvoraCallState.held ||
          to == AvoraCallState.failed ||
          to == AvoraCallState.ended,
      AvoraCallState.busy ||
      AvoraCallState.declined ||
      AvoraCallState.missed ||
      AvoraCallState.cancelled ||
      AvoraCallState.failed ||
      AvoraCallState.answeredElsewhere ||
      AvoraCallState.ended =>
        false,
    };
  }

  static AvoraCallTransitionDecision transition({
    required AvoraCallSession current,
    required AvoraCallState to,
    required DateTime nowUtc,
    AvoraCallEndReason endReason = AvoraCallEndReason.none,
  }) {
    if (!current.validIdentityBinding) {
      return AvoraCallTransitionDecision(
        allowed: false,
        next: current,
        reason: 'invalid_identity_binding',
      );
    }

    if (!isAllowedTransition(current.state, to)) {
      return AvoraCallTransitionDecision(
        allowed: false,
        next: current,
        reason: 'invalid_state_transition',
      );
    }

    final terminal = isTerminalState(to);

    final connectedAt =
        to == AvoraCallState.active && current.connectedAtUtc == null
            ? nowUtc.toUtc()
            : current.connectedAtUtc;

    final normalizedEndReason = terminal
        ? _resolveTerminalReason(to, endReason)
        : AvoraCallEndReason.none;

    final next = AvoraCallSession(
      callId: current.callId.trim(),
      callerAvoraId: current.callerAvoraId.trim(),
      calleeAvoraId: current.calleeAvoraId.trim(),
      type: current.type,
      direction: current.direction,
      state: to,
      createdAtUtc: current.createdAtUtc.toUtc(),
      updatedAtUtc: nowUtc.toUtc(),
      connectedAtUtc: connectedAt,
      endedAtUtc: terminal ? nowUtc.toUtc() : null,
      endReason: normalizedEndReason,
    );

    return AvoraCallTransitionDecision(
      allowed: true,
      next: next,
      reason: 'allowed',
    );
  }

  static AvoraCallEndReason _resolveTerminalReason(
    AvoraCallState state,
    AvoraCallEndReason requested,
  ) {
    if (requested != AvoraCallEndReason.none) {
      return requested;
    }

    return switch (state) {
      AvoraCallState.busy => AvoraCallEndReason.busy,
      AvoraCallState.declined => AvoraCallEndReason.declined,
      AvoraCallState.missed => AvoraCallEndReason.missed,
      AvoraCallState.cancelled => AvoraCallEndReason.cancelled,
      AvoraCallState.failed => AvoraCallEndReason.networkFailure,
      AvoraCallState.answeredElsewhere => AvoraCallEndReason.answeredElsewhere,
      AvoraCallState.ended => AvoraCallEndReason.remoteEnded,
      _ => AvoraCallEndReason.none,
    };
  }

  static bool waitingNeverCountsAsDefaultBillableTime() => true;

  static bool busyNeverCountsAsConnectedTime() => true;

  static bool immutableAvoraIdsRemainAuthoritative() => true;

  static bool clientMaySilentlyRewriteCallHistory() => false;
}
