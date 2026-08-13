import 'avora_call_state.dart';

class AvoraCallDurationSnapshot {
  const AvoraCallDurationSnapshot({
    required this.callId,
    required this.callerAvoraId,
    required this.calleeAvoraId,
    required this.state,
    required this.measuredAtUtc,
    required this.activeDuration,
    required this.heldDuration,
    required this.reconnectingDuration,
    required this.waitingDuration,
    required this.setupDuration,
  });

  final String callId;
  final String callerAvoraId;
  final String calleeAvoraId;
  final AvoraCallState state;
  final DateTime measuredAtUtc;

  /// Actual active two-party connected media time.
  final Duration activeDuration;

  /// Connected session intentionally placed on hold.
  final Duration heldDuration;

  /// Previously connected session temporarily recovering network/media.
  final Duration reconnectingDuration;

  /// Incoming second-call waiting time. Never billable by default.
  final Duration waitingDuration;

  /// Idle/dialing/ringing/incoming/connecting time.
  final Duration setupDuration;

  /// Connected-session presence. This is intentionally broader than
  /// default billable time.
  Duration get connectedDuration =>
      activeDuration + heldDuration + reconnectingDuration;

  /// Default Calling Points boundary.
  ///
  /// Admin policy may later change held/reconnecting treatment, but ringing,
  /// waiting and busy must never silently become connected billable time.
  Duration get defaultBillableDuration => activeDuration;

  Duration get nonBillableConnectedDuration =>
      heldDuration + reconnectingDuration;

  Duration get nonConnectedDuration => setupDuration + waitingDuration;
}

class AvoraCallDurationTransitionDecision {
  const AvoraCallDurationTransitionDecision({
    required this.allowed,
    required this.next,
    required this.reason,
  });

  final bool allowed;
  final AvoraCallDurationMeter next;
  final String reason;
}

/// Immutable authoritative duration accumulator.
///
/// Duration is derived from validated call-state intervals rather than client
/// UI timers. This prevents ringing/waiting/busy time from being counted as
/// connected Calling Points time.
class AvoraCallDurationMeter {
  const AvoraCallDurationMeter._({
    required this.callId,
    required this.callerAvoraId,
    required this.calleeAvoraId,
    required this.currentState,
    required this.lastStateChangedAtUtc,
    required int activeMicros,
    required int heldMicros,
    required int reconnectingMicros,
    required int waitingMicros,
    required int setupMicros,
  })  : _activeMicros = activeMicros,
        _heldMicros = heldMicros,
        _reconnectingMicros = reconnectingMicros,
        _waitingMicros = waitingMicros,
        _setupMicros = setupMicros;

  final String callId;
  final String callerAvoraId;
  final String calleeAvoraId;

  final AvoraCallState currentState;
  final DateTime lastStateChangedAtUtc;

  final int _activeMicros;
  final int _heldMicros;
  final int _reconnectingMicros;
  final int _waitingMicros;
  final int _setupMicros;

  static AvoraCallDurationMeter begin({
    required AvoraCallSession session,
  }) {
    if (!session.validIdentityBinding) {
      throw ArgumentError(
        'Valid immutable call/caller/callee identity binding is required.',
      );
    }

    final anchor = session.updatedAtUtc.toUtc();

    if (anchor.isBefore(session.createdAtUtc.toUtc())) {
      throw ArgumentError(
        'Call duration anchor cannot be before call creation.',
      );
    }

    return AvoraCallDurationMeter._(
      callId: session.callId.trim(),
      callerAvoraId: session.callerAvoraId.trim(),
      calleeAvoraId: session.calleeAvoraId.trim(),
      currentState: session.state,
      lastStateChangedAtUtc: anchor,
      activeMicros: 0,
      heldMicros: 0,
      reconnectingMicros: 0,
      waitingMicros: 0,
      setupMicros: 0,
    );
  }

  AvoraCallDurationTransitionDecision transition({
    required AvoraCallState to,
    required DateTime atUtc,
  }) {
    final normalizedAt = atUtc.toUtc();

    if (normalizedAt.isBefore(lastStateChangedAtUtc)) {
      return AvoraCallDurationTransitionDecision(
        allowed: false,
        next: this,
        reason: 'non_monotonic_timestamp',
      );
    }

    if (!AvoraCallStateEngine.isAllowedTransition(
      currentState,
      to,
    )) {
      return AvoraCallDurationTransitionDecision(
        allowed: false,
        next: this,
        reason: 'invalid_state_transition',
      );
    }

    final deltaMicros =
        normalizedAt.difference(lastStateChangedAtUtc).inMicroseconds;

    final accrued = _accrue(
      state: currentState,
      deltaMicros: deltaMicros,
    );

    final next = AvoraCallDurationMeter._(
      callId: callId,
      callerAvoraId: callerAvoraId,
      calleeAvoraId: calleeAvoraId,
      currentState: to,
      lastStateChangedAtUtc: normalizedAt,
      activeMicros: accrued.active,
      heldMicros: accrued.held,
      reconnectingMicros: accrued.reconnecting,
      waitingMicros: accrued.waiting,
      setupMicros: accrued.setup,
    );

    return AvoraCallDurationTransitionDecision(
      allowed: true,
      next: next,
      reason: 'allowed',
    );
  }

  AvoraCallDurationSnapshot snapshot({
    required DateTime atUtc,
  }) {
    final normalizedAt = atUtc.toUtc();

    if (normalizedAt.isBefore(lastStateChangedAtUtc)) {
      throw ArgumentError(
        'Snapshot time cannot be before latest state transition.',
      );
    }

    var deltaMicros =
        normalizedAt.difference(lastStateChangedAtUtc).inMicroseconds;

    // Terminal states do not continue accumulating duration after termination.
    if (AvoraCallStateEngine.isTerminalState(currentState)) {
      deltaMicros = 0;
    }

    final accrued = _accrue(
      state: currentState,
      deltaMicros: deltaMicros,
    );

    return AvoraCallDurationSnapshot(
      callId: callId,
      callerAvoraId: callerAvoraId,
      calleeAvoraId: calleeAvoraId,
      state: currentState,
      measuredAtUtc: normalizedAt,
      activeDuration: Duration(microseconds: accrued.active),
      heldDuration: Duration(microseconds: accrued.held),
      reconnectingDuration: Duration(microseconds: accrued.reconnecting),
      waitingDuration: Duration(microseconds: accrued.waiting),
      setupDuration: Duration(microseconds: accrued.setup),
    );
  }

  _AvoraCallDurationAccrual _accrue({
    required AvoraCallState state,
    required int deltaMicros,
  }) {
    var active = _activeMicros;
    var held = _heldMicros;
    var reconnecting = _reconnectingMicros;
    var waiting = _waitingMicros;
    var setup = _setupMicros;

    switch (state) {
      case AvoraCallState.active:
        active += deltaMicros;

      case AvoraCallState.held:
        held += deltaMicros;

      case AvoraCallState.reconnecting:
        reconnecting += deltaMicros;

      case AvoraCallState.waiting:
        waiting += deltaMicros;

      case AvoraCallState.idle:
      case AvoraCallState.dialing:
      case AvoraCallState.ringing:
      case AvoraCallState.incoming:
      case AvoraCallState.connecting:
        setup += deltaMicros;

      case AvoraCallState.busy:
      case AvoraCallState.declined:
      case AvoraCallState.missed:
      case AvoraCallState.cancelled:
      case AvoraCallState.failed:
      case AvoraCallState.answeredElsewhere:
      case AvoraCallState.ended:
        break;
    }

    return _AvoraCallDurationAccrual(
      active: active,
      held: held,
      reconnecting: reconnecting,
      waiting: waiting,
      setup: setup,
    );
  }

  static bool ringingIsDefaultBillable() => false;

  static bool waitingIsDefaultBillable() => false;

  static bool busyIsDefaultBillable() => false;

  static bool heldIsDefaultBillable() => false;

  static bool reconnectingIsDefaultBillable() => false;

  static bool activeIsDefaultBillable() => true;

  static bool clientTimerIsAuthoritativeForCallingPoints() => false;
}

class _AvoraCallDurationAccrual {
  const _AvoraCallDurationAccrual({
    required this.active,
    required this.held,
    required this.reconnecting,
    required this.waiting,
    required this.setup,
  });

  final int active;
  final int held;
  final int reconnecting;
  final int waiting;
  final int setup;
}
