import 'avora_coin_economy_budget.dart';

class AvoraCoinBudgetChangeRecord {
  const AvoraCoinBudgetChangeRecord({
    required this.changeId,
    required this.actorAvoraId,
    required this.previousVersion,
    required this.newVersion,
    required this.previousReserveBps,
    required this.newReserveBps,
    required this.reason,
    required this.createdAtUtc,
  });

  final String changeId;
  final String actorAvoraId;

  final String previousVersion;
  final String newVersion;

  final int previousReserveBps;
  final int newReserveBps;

  final String reason;
  final DateTime createdAtUtc;
}

class AvoraCoinBudgetRegistry {
  AvoraCoinBudgetRegistry({
    required AvoraCoinEconomyBudgetPolicy initialPolicy,
  }) : _activePolicy = initialPolicy {
    _versions[initialPolicy.policyVersion] = initialPolicy;
  }

  AvoraCoinEconomyBudgetPolicy _activePolicy;

  final Map<String, AvoraCoinEconomyBudgetPolicy> _versions =
      <String, AvoraCoinEconomyBudgetPolicy>{};

  final List<AvoraCoinBudgetChangeRecord> _changeHistory =
      <AvoraCoinBudgetChangeRecord>[];

  AvoraCoinEconomyBudgetPolicy get activePolicy => _activePolicy;

  List<AvoraCoinBudgetChangeRecord> get changeHistory =>
      List<AvoraCoinBudgetChangeRecord>.unmodifiable(
        _changeHistory,
      );

  AvoraCoinEconomyBudgetPolicy? byVersion(
    String version,
  ) {
    return _versions[version.trim()];
  }

  void activateNewPolicy({
    required String changeId,
    required String actorAvoraId,
    required AvoraCoinEconomyBudgetPolicy policy,
    required String reason,
    required DateTime createdAtUtc,
  }) {
    if (changeId.trim().isEmpty ||
        actorAvoraId.trim().isEmpty ||
        policy.policyVersion.trim().isEmpty ||
        reason.trim().isEmpty) {
      throw ArgumentError(
        'coin_budget_change_identity_required',
      );
    }

    if (_versions.containsKey(policy.policyVersion)) {
      throw StateError(
        'coin_budget_policy_version_already_exists',
      );
    }

    final previous = _activePolicy;

    _versions[policy.policyVersion] = policy;
    _activePolicy = policy;

    _changeHistory.add(
      AvoraCoinBudgetChangeRecord(
        changeId: changeId.trim(),
        actorAvoraId: actorAvoraId.trim(),
        previousVersion: previous.policyVersion,
        newVersion: policy.policyVersion,
        previousReserveBps: previous.totalReserveBps,
        newReserveBps: policy.totalReserveBps,
        reason: reason.trim(),
        createdAtUtc: createdAtUtc.toUtc(),
      ),
    );
  }

  static bool ownerMayChangeFutureBudget() => true;

  static bool historicalBudgetVersionsMustRemainReadable() => true;

  static bool oldTransactionsMustKeepOriginalBudgetVersion() => true;

  static bool everyBudgetChangeMustBeAudited() => true;

  static bool futureModulesMustUseActiveBudgetVersion() => true;

  static bool clientMustNotSelfChangeBudgetPolicy() => true;
}
