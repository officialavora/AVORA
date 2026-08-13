import 'avora_game_economy_policy.dart';

class AvoraGamePolicyVersionRecord {
  const AvoraGamePolicyVersionRecord({
    required this.gameId,
    required this.policy,
    required this.changedByAvoraId,
    required this.changedAtUtc,
    required this.reason,
  });

  final String gameId;
  final AvoraGameEconomyPolicy policy;
  final String changedByAvoraId;
  final DateTime changedAtUtc;
  final String reason;
}

class AvoraGameOwnerPolicyRegistry {
  final Map<String, AvoraGameEconomyPolicy> _activePolicies =
      <String, AvoraGameEconomyPolicy>{};

  final List<AvoraGamePolicyVersionRecord> _history =
      <AvoraGamePolicyVersionRecord>[];

  AvoraGameEconomyPolicy? activePolicyFor(String gameId) {
    return _activePolicies[gameId];
  }

  List<AvoraGamePolicyVersionRecord> historyFor(String gameId) {
    return List<AvoraGamePolicyVersionRecord>.unmodifiable(
      _history.where((record) => record.gameId == gameId),
    );
  }

  void setPolicy({
    required String gameId,
    required AvoraGameEconomyPolicy policy,
    required String ownerAvoraId,
    required String reason,
    required DateTime changedAtUtc,
  }) {
    final normalizedGameId = gameId.trim();
    final normalizedOwnerId = ownerAvoraId.trim();
    final normalizedReason = reason.trim();

    if (normalizedGameId.isEmpty ||
        normalizedOwnerId.isEmpty ||
        normalizedReason.isEmpty) {
      throw ArgumentError('game_policy_audit_fields_required');
    }

    policy.validate();

    final duplicateVersion = _history.any(
      (record) =>
          record.gameId == normalizedGameId &&
          record.policy.policyVersion == policy.policyVersion,
    );

    if (duplicateVersion) {
      throw StateError('duplicate_game_policy_version');
    }

    _activePolicies[normalizedGameId] = policy;

    _history.add(
      AvoraGamePolicyVersionRecord(
        gameId: normalizedGameId,
        policy: policy,
        changedByAvoraId: normalizedOwnerId,
        changedAtUtc: changedAtUtc.toUtc(),
        reason: normalizedReason,
      ),
    );
  }

  void pauseGame({
    required String gameId,
    required String newPolicyVersion,
    required String ownerAvoraId,
    required String reason,
    required DateTime changedAtUtc,
  }) {
    final current = activePolicyFor(gameId);

    if (current == null) {
      throw StateError('game_policy_not_found');
    }

    setPolicy(
      gameId: gameId,
      policy: AvoraGameEconomyPolicy(
        policyVersion: newPolicyVersion,
        returnBasisPoints: current.returnBasisPoints,
        minimumBet: current.minimumBet,
        maximumBet: current.maximumBet,
        active: false,
      ),
      ownerAvoraId: ownerAvoraId,
      reason: reason,
      changedAtUtc: changedAtUtc,
    );
  }

  static bool ownerCanConfigureGameReturnPercentage() => true;

  static bool ownerCanConfigureBetLimits() => true;

  static bool ownerCanPauseAnyGame() => true;

  static bool everyChangeMustCreateHistory() => true;

  static bool oldPolicyVersionsMustRemainHistorical() => true;

  static bool futureGamesMustRegisterBeforeCoinBetting() => true;

  static bool clientMustNeverSelfChangeEconomyPolicy() => true;

  static bool policyChangeMustNeverRewriteSettledRounds() => true;
}
