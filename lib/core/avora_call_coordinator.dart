import 'avora_call_state.dart';

enum AvoraCallCoordinatorAction {
  incomingPrimary,
  waitingQueued,
  rejectedBusy,
  holdAndAccept,
  swapped,
  waitingDeclined,
  endedAndResumed,
  rejected,
}

class AvoraCallConcurrencyPolicy {
  const AvoraCallConcurrencyPolicy({
    this.callWaitingEnabled = true,
    this.holdAndSwapEnabled = true,
    this.maxLiveCalls = 2,
  }) : assert(maxLiveCalls >= 1 && maxLiveCalls <= 2);

  final bool callWaitingEnabled;
  final bool holdAndSwapEnabled;

  /// Current AVORA mobile calling design supports at most one primary
  /// and one waiting/held secondary call.
  final int maxLiveCalls;
}

class AvoraCallLineSnapshot {
  const AvoraCallLineSnapshot({
    this.primary,
    this.secondary,
  });

  final AvoraCallSession? primary;
  final AvoraCallSession? secondary;

  int get liveCallCount {
    var count = 0;

    if (primary != null && !primary!.isTerminal) {
      count++;
    }

    if (secondary != null && !secondary!.isTerminal) {
      count++;
    }

    return count;
  }

  bool get hasWaitingCall => secondary?.state == AvoraCallState.waiting;

  bool get hasHeldCall => secondary?.state == AvoraCallState.held;
}

class AvoraCallCoordinatorDecision {
  const AvoraCallCoordinatorDecision({
    required this.allowed,
    required this.action,
    required this.line,
    required this.reason,
    this.terminalCall,
  });

  final bool allowed;
  final AvoraCallCoordinatorAction action;
  final AvoraCallLineSnapshot line;
  final String reason;

  /// Terminal call snapshot retained for call history/audit.
  final AvoraCallSession? terminalCall;
}

class AvoraCallCoordinator {
  const AvoraCallCoordinator._();

  static AvoraCallCoordinatorDecision handleIncoming({
    required AvoraCallLineSnapshot line,
    required AvoraCallSession incomingCall,
    required AvoraCallConcurrencyPolicy policy,
    required DateTime nowUtc,
  }) {
    if (incomingCall.state != AvoraCallState.incoming) {
      return AvoraCallCoordinatorDecision(
        allowed: false,
        action: AvoraCallCoordinatorAction.rejected,
        line: line,
        reason: 'incoming_call_not_in_incoming_state',
      );
    }

    if (!incomingCall.validIdentityBinding) {
      return AvoraCallCoordinatorDecision(
        allowed: false,
        action: AvoraCallCoordinatorAction.rejected,
        line: line,
        reason: 'invalid_identity_binding',
      );
    }

    final primary = line.primary;

    if (primary == null || primary.isTerminal) {
      return AvoraCallCoordinatorDecision(
        allowed: true,
        action: AvoraCallCoordinatorAction.incomingPrimary,
        line: AvoraCallLineSnapshot(primary: incomingCall),
        reason: 'incoming_primary',
      );
    }

    final secondaryOccupied =
        line.secondary != null && !line.secondary!.isTerminal;

    if (secondaryOccupied ||
        line.liveCallCount >= policy.maxLiveCalls ||
        !policy.callWaitingEnabled ||
        policy.maxLiveCalls < 2) {
      return _rejectIncomingBusy(
        line: line,
        incomingCall: incomingCall,
        nowUtc: nowUtc,
      );
    }

    final waiting = AvoraCallStateEngine.transition(
      current: incomingCall,
      to: AvoraCallState.waiting,
      nowUtc: nowUtc,
    );

    if (!waiting.allowed) {
      return AvoraCallCoordinatorDecision(
        allowed: false,
        action: AvoraCallCoordinatorAction.rejected,
        line: line,
        reason: waiting.reason,
      );
    }

    return AvoraCallCoordinatorDecision(
      allowed: true,
      action: AvoraCallCoordinatorAction.waitingQueued,
      line: AvoraCallLineSnapshot(
        primary: primary,
        secondary: waiting.next,
      ),
      reason: 'call_waiting',
    );
  }

  static AvoraCallCoordinatorDecision holdPrimaryAndAcceptWaiting({
    required AvoraCallLineSnapshot line,
    required AvoraCallConcurrencyPolicy policy,
    required DateTime nowUtc,
  }) {
    final primary = line.primary;
    final secondary = line.secondary;

    if (!policy.callWaitingEnabled || !policy.holdAndSwapEnabled) {
      return _reject(line, 'hold_and_swap_disabled');
    }

    if (primary == null ||
        secondary == null ||
        primary.state != AvoraCallState.active ||
        secondary.state != AvoraCallState.waiting) {
      return _reject(line, 'invalid_hold_accept_state');
    }

    final held = AvoraCallStateEngine.transition(
      current: primary,
      to: AvoraCallState.held,
      nowUtc: nowUtc,
    );

    final connecting = AvoraCallStateEngine.transition(
      current: secondary,
      to: AvoraCallState.connecting,
      nowUtc: nowUtc,
    );

    if (!held.allowed || !connecting.allowed) {
      return _reject(line, 'hold_accept_transition_failed');
    }

    return AvoraCallCoordinatorDecision(
      allowed: true,
      action: AvoraCallCoordinatorAction.holdAndAccept,
      line: AvoraCallLineSnapshot(
        primary: connecting.next,
        secondary: held.next,
      ),
      reason: 'primary_held_waiting_connecting',
    );
  }

  static AvoraCallCoordinatorDecision swap({
    required AvoraCallLineSnapshot line,
    required AvoraCallConcurrencyPolicy policy,
    required DateTime nowUtc,
  }) {
    final primary = line.primary;
    final secondary = line.secondary;

    if (!policy.holdAndSwapEnabled) {
      return _reject(line, 'hold_and_swap_disabled');
    }

    if (primary == null ||
        secondary == null ||
        primary.state != AvoraCallState.active ||
        secondary.state != AvoraCallState.held) {
      return _reject(line, 'invalid_swap_state');
    }

    final oldPrimaryHeld = AvoraCallStateEngine.transition(
      current: primary,
      to: AvoraCallState.held,
      nowUtc: nowUtc,
    );

    final oldSecondaryActive = AvoraCallStateEngine.transition(
      current: secondary,
      to: AvoraCallState.active,
      nowUtc: nowUtc,
    );

    if (!oldPrimaryHeld.allowed || !oldSecondaryActive.allowed) {
      return _reject(line, 'swap_transition_failed');
    }

    return AvoraCallCoordinatorDecision(
      allowed: true,
      action: AvoraCallCoordinatorAction.swapped,
      line: AvoraCallLineSnapshot(
        primary: oldSecondaryActive.next,
        secondary: oldPrimaryHeld.next,
      ),
      reason: 'calls_swapped',
    );
  }

  static AvoraCallCoordinatorDecision declineWaiting({
    required AvoraCallLineSnapshot line,
    required DateTime nowUtc,
  }) {
    final secondary = line.secondary;

    if (secondary == null || secondary.state != AvoraCallState.waiting) {
      return _reject(line, 'no_waiting_call');
    }

    final declined = AvoraCallStateEngine.transition(
      current: secondary,
      to: AvoraCallState.declined,
      nowUtc: nowUtc,
    );

    if (!declined.allowed) {
      return _reject(line, declined.reason);
    }

    return AvoraCallCoordinatorDecision(
      allowed: true,
      action: AvoraCallCoordinatorAction.waitingDeclined,
      line: AvoraCallLineSnapshot(primary: line.primary),
      terminalCall: declined.next,
      reason: 'waiting_call_declined',
    );
  }

  static AvoraCallCoordinatorDecision endPrimaryAndResumeHeld({
    required AvoraCallLineSnapshot line,
    required DateTime nowUtc,
  }) {
    final primary = line.primary;
    final secondary = line.secondary;

    if (primary == null ||
        secondary == null ||
        primary.state != AvoraCallState.active ||
        secondary.state != AvoraCallState.held) {
      return _reject(line, 'invalid_end_and_resume_state');
    }

    final ended = AvoraCallStateEngine.transition(
      current: primary,
      to: AvoraCallState.ended,
      nowUtc: nowUtc,
      endReason: AvoraCallEndReason.localEnded,
    );

    final resumed = AvoraCallStateEngine.transition(
      current: secondary,
      to: AvoraCallState.active,
      nowUtc: nowUtc,
    );

    if (!ended.allowed || !resumed.allowed) {
      return _reject(line, 'end_and_resume_transition_failed');
    }

    return AvoraCallCoordinatorDecision(
      allowed: true,
      action: AvoraCallCoordinatorAction.endedAndResumed,
      line: AvoraCallLineSnapshot(primary: resumed.next),
      terminalCall: ended.next,
      reason: 'primary_ended_held_resumed',
    );
  }

  static AvoraCallCoordinatorDecision _rejectIncomingBusy({
    required AvoraCallLineSnapshot line,
    required AvoraCallSession incomingCall,
    required DateTime nowUtc,
  }) {
    final busy = AvoraCallStateEngine.transition(
      current: incomingCall,
      to: AvoraCallState.busy,
      nowUtc: nowUtc,
    );

    if (!busy.allowed) {
      return _reject(line, busy.reason);
    }

    return AvoraCallCoordinatorDecision(
      allowed: true,
      action: AvoraCallCoordinatorAction.rejectedBusy,
      line: line,
      terminalCall: busy.next,
      reason: 'line_busy',
    );
  }

  static AvoraCallCoordinatorDecision _reject(
    AvoraCallLineSnapshot line,
    String reason,
  ) {
    return AvoraCallCoordinatorDecision(
      allowed: false,
      action: AvoraCallCoordinatorAction.rejected,
      line: line,
      reason: reason,
    );
  }

  static bool waitingTimeIsDefaultBillable() => false;

  static bool busyOutcomeIsDefaultBillable() => false;

  static bool thirdConcurrentCallCanBypassLimit() => false;
}
