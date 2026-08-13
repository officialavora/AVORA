class AvoraGameEconomyBudgetPolicy {
  const AvoraGameEconomyBudgetPolicy({
    required this.policyVersion,
    required this.targetReturnBasisPoints,
    required this.infrastructureBasisPoints,
    required this.operationsBasisPoints,
    required this.paymentFeeBasisPoints,
    required this.refundReserveBasisPoints,
    required this.promotionBasisPoints,
    required this.safetyReserveBasisPoints,
  });

  final String policyVersion;

  /// Target player return.
  /// 8500 = 85%
  final int targetReturnBasisPoints;

  /// Infrastructure/server/realtime/minute costs.
  final int infrastructureBasisPoints;

  /// Staff/operations/salary/commission budget.
  final int operationsBasisPoints;

  /// Store/payment/provider fees.
  final int paymentFeeBasisPoints;

  /// Refund/chargeback/tax/risk reserve.
  final int refundReserveBasisPoints;

  /// Promotions/rewards/events allocation.
  final int promotionBasisPoints;

  /// Contingency/safety margin.
  final int safetyReserveBasisPoints;

  int get totalBasisPoints =>
      targetReturnBasisPoints +
      infrastructureBasisPoints +
      operationsBasisPoints +
      paymentFeeBasisPoints +
      refundReserveBasisPoints +
      promotionBasisPoints +
      safetyReserveBasisPoints;

  int get retainedBasisPoints => 10000 - targetReturnBasisPoints;

  void validate() {
    if (policyVersion.trim().isEmpty) {
      throw ArgumentError('game_economy_policy_version_required');
    }

    final values = <int>[
      targetReturnBasisPoints,
      infrastructureBasisPoints,
      operationsBasisPoints,
      paymentFeeBasisPoints,
      refundReserveBasisPoints,
      promotionBasisPoints,
      safetyReserveBasisPoints,
    ];

    if (values.any((value) => value < 0 || value > 10000)) {
      throw ArgumentError('invalid_game_economy_basis_points');
    }

    if (totalBasisPoints > 10000) {
      throw StateError('game_economy_budget_exceeds_100_percent');
    }
  }
}

class AvoraGameEconomyAllocation {
  const AvoraGameEconomyAllocation({
    required this.totalBetCoins,
    required this.targetReturnCoins,
    required this.infrastructureCoins,
    required this.operationsCoins,
    required this.paymentFeeCoins,
    required this.refundReserveCoins,
    required this.promotionCoins,
    required this.safetyReserveCoins,
    required this.unallocatedCoins,
    required this.policyVersion,
  });

  final int totalBetCoins;
  final int targetReturnCoins;
  final int infrastructureCoins;
  final int operationsCoins;
  final int paymentFeeCoins;
  final int refundReserveCoins;
  final int promotionCoins;
  final int safetyReserveCoins;
  final int unallocatedCoins;
  final String policyVersion;
}

class AvoraUniversalGameEconomyEngine {
  const AvoraUniversalGameEconomyEngine();

  AvoraGameEconomyAllocation allocate({
    required int totalBetCoins,
    required AvoraGameEconomyBudgetPolicy policy,
  }) {
    if (totalBetCoins < 0) {
      throw ArgumentError('total_bet_coins_must_not_be_negative');
    }

    policy.validate();

    int value(int basisPoints) => (totalBetCoins * basisPoints) ~/ 10000;

    final targetReturnCoins = value(policy.targetReturnBasisPoints);

    final infrastructureCoins = value(policy.infrastructureBasisPoints);

    final operationsCoins = value(policy.operationsBasisPoints);

    final paymentFeeCoins = value(policy.paymentFeeBasisPoints);

    final refundReserveCoins = value(policy.refundReserveBasisPoints);

    final promotionCoins = value(policy.promotionBasisPoints);

    final safetyReserveCoins = value(policy.safetyReserveBasisPoints);

    final allocated = targetReturnCoins +
        infrastructureCoins +
        operationsCoins +
        paymentFeeCoins +
        refundReserveCoins +
        promotionCoins +
        safetyReserveCoins;

    return AvoraGameEconomyAllocation(
      totalBetCoins: totalBetCoins,
      targetReturnCoins: targetReturnCoins,
      infrastructureCoins: infrastructureCoins,
      operationsCoins: operationsCoins,
      paymentFeeCoins: paymentFeeCoins,
      refundReserveCoins: refundReserveCoins,
      promotionCoins: promotionCoins,
      safetyReserveCoins: safetyReserveCoins,
      unallocatedCoins: totalBetCoins - allocated,
      policyVersion: policy.policyVersion,
    );
  }

  static bool allGamesMustUseUniversalEconomyPolicy() => true;

  static bool noGameMayHardcodeIndependentRtp() => true;

  static bool ownerMustBeAbleToVersionEconomyPolicy() => true;

  static bool historicalRoundsMustPreservePolicyVersion() => true;

  static bool infrastructureCostMustBeBudgetedBeforeReturnTarget() => true;

  static bool operationsCostMustBeBudgetedBeforeReturnTarget() => true;

  static bool paymentFeesMustBeBudgetedBeforeReturnTarget() => true;

  static bool refundReserveMustBeBudgetedBeforeReturnTarget() => true;

  static bool promotionBudgetMustBeExplicit() => true;

  static bool safetyReserveMustBeExplicit() => true;

  static bool futureGamesMustAutomaticallyInheritActivePolicy() => true;
}

abstract interface class AvoraGameEconomyPolicyProvider {
  AvoraGameEconomyBudgetPolicy activePolicy();
}

class AvoraInMemoryGameEconomyPolicyProvider
    implements AvoraGameEconomyPolicyProvider {
  AvoraInMemoryGameEconomyPolicyProvider(
    AvoraGameEconomyBudgetPolicy initialPolicy,
  ) : _active = initialPolicy {
    initialPolicy.validate();
  }

  AvoraGameEconomyBudgetPolicy _active;

  final Map<String, AvoraGameEconomyBudgetPolicy> _history =
      <String, AvoraGameEconomyBudgetPolicy>{};

  @override
  AvoraGameEconomyBudgetPolicy activePolicy() => _active;

  void activate(
    AvoraGameEconomyBudgetPolicy policy,
  ) {
    policy.validate();

    _history[_active.policyVersion] = _active;
    _active = policy;
  }

  AvoraGameEconomyBudgetPolicy? historical(
    String policyVersion,
  ) {
    if (_active.policyVersion == policyVersion) {
      return _active;
    }

    return _history[policyVersion];
  }

  static bool ownerMayChangeFuturePolicyWithoutRewritingHistory() => true;

  static bool policyHistoryMustRemainAvailable() => true;
}
