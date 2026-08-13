import 'avora_game_economy_health_guard.dart';

enum AvoraGameEconomyGateState {
  open,
  paused,
}

class AvoraGameEconomyGateAudit {
  const AvoraGameEconomyGateAudit({
    required this.auditId,
    required this.gameId,
    required this.actorAvoraId,
    required this.previousState,
    required this.newState,
    required this.reason,
    required this.createdAtUtc,
  });

  final String auditId;
  final String gameId;
  final String actorAvoraId;
  final AvoraGameEconomyGateState previousState;
  final AvoraGameEconomyGateState newState;
  final String reason;
  final DateTime createdAtUtc;
}

class AvoraGameEconomySafetyGate {
  final Map<String, AvoraGameEconomyGateState> _states =
      <String, AvoraGameEconomyGateState>{};

  final List<AvoraGameEconomyGateAudit> _audit = <AvoraGameEconomyGateAudit>[];

  AvoraGameEconomyGateState stateFor(String gameId) {
    return _states[gameId.trim()] ?? AvoraGameEconomyGateState.open;
  }

  bool canAcceptNewBet(String gameId) {
    return stateFor(gameId) == AvoraGameEconomyGateState.open;
  }

  List<AvoraGameEconomyGateAudit> auditFor(String gameId) {
    return List<AvoraGameEconomyGateAudit>.unmodifiable(
      _audit.where((item) => item.gameId == gameId.trim()),
    );
  }

  bool applyHealthResult({
    required String auditId,
    required String gameId,
    required AvoraGameEconomyHealthResult health,
    required DateTime createdAtUtc,
  }) {
    if (!health.pauseRecommended) {
      return false;
    }

    return _changeState(
      auditId: auditId,
      gameId: gameId,
      actorAvoraId: 'SYSTEM',
      newState: AvoraGameEconomyGateState.paused,
      reason: 'critical_game_economy_health',
      createdAtUtc: createdAtUtc,
    );
  }

  bool ownerResume({
    required String auditId,
    required String gameId,
    required String ownerAvoraId,
    required String reason,
    required DateTime createdAtUtc,
  }) {
    if (ownerAvoraId.trim().isEmpty || reason.trim().isEmpty) {
      throw ArgumentError('owner_resume_audit_required');
    }

    return _changeState(
      auditId: auditId,
      gameId: gameId,
      actorAvoraId: ownerAvoraId,
      newState: AvoraGameEconomyGateState.open,
      reason: reason,
      createdAtUtc: createdAtUtc,
    );
  }

  bool _changeState({
    required String auditId,
    required String gameId,
    required String actorAvoraId,
    required AvoraGameEconomyGateState newState,
    required String reason,
    required DateTime createdAtUtc,
  }) {
    final id = gameId.trim();

    if (auditId.trim().isEmpty ||
        id.isEmpty ||
        actorAvoraId.trim().isEmpty ||
        reason.trim().isEmpty) {
      throw ArgumentError('game_gate_audit_fields_required');
    }

    if (_audit.any((item) => item.auditId == auditId)) {
      throw StateError('duplicate_game_gate_audit');
    }

    final previous = stateFor(id);

    if (previous == newState) {
      return false;
    }

    _states[id] = newState;

    _audit.add(
      AvoraGameEconomyGateAudit(
        auditId: auditId,
        gameId: id,
        actorAvoraId: actorAvoraId,
        previousState: previous,
        newState: newState,
        reason: reason,
        createdAtUtc: createdAtUtc.toUtc(),
      ),
    );

    return true;
  }

  static bool criticalHealthMayBlockNewBets() => true;
  static bool pauseMustNotRewritePastRounds() => true;
  static bool pauseMustNotDeleteUserCoins() => true;
  static bool ownerCanResumeAfterReview() => true;
  static bool pauseAndResumeMustBeAudited() => true;
  static bool futureGamesMustUseSameSafetyGate() => true;
}
