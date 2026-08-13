class AvoraCoinEconomyBudgetPolicy {
  const AvoraCoinEconomyBudgetPolicy({
    required this.policyVersion,
    required this.infrastructureBps,
    required this.realtimeMinutesBps,
    required this.operationsSalaryBps,
    required this.paymentRiskBps,
    required this.promoSafetyBps,
  }) : assert(
          infrastructureBps >= 0 &&
              realtimeMinutesBps >= 0 &&
              operationsSalaryBps >= 0 &&
              paymentRiskBps >= 0 &&
              promoSafetyBps >= 0 &&
              infrastructureBps +
                      realtimeMinutesBps +
                      operationsSalaryBps +
                      paymentRiskBps +
                      promoSafetyBps <=
                  10000,
        );

  final String policyVersion;

  final int infrastructureBps;
  final int realtimeMinutesBps;
  final int operationsSalaryBps;
  final int paymentRiskBps;
  final int promoSafetyBps;

  int get totalReserveBps =>
      infrastructureBps +
      realtimeMinutesBps +
      operationsSalaryBps +
      paymentRiskBps +
      promoSafetyBps;

  int get maxDistributableBps => 10000 - totalReserveBps;

  double get totalReservePercent => totalReserveBps / 100;

  double get maxDistributablePercent => maxDistributableBps / 100;

  int reserveAmount({
    required int grossCoinRevenueEquivalent,
  }) {
    if (grossCoinRevenueEquivalent < 0) {
      throw ArgumentError('gross_revenue_must_not_be_negative');
    }

    return (grossCoinRevenueEquivalent * totalReserveBps) ~/ 10000;
  }

  int maxDistributableAmount({
    required int grossCoinRevenueEquivalent,
  }) {
    if (grossCoinRevenueEquivalent < 0) {
      throw ArgumentError('gross_revenue_must_not_be_negative');
    }

    return (grossCoinRevenueEquivalent * maxDistributableBps) ~/ 10000;
  }

  static AvoraCoinEconomyBudgetPolicy launchDefault() {
    return const AvoraCoinEconomyBudgetPolicy(
      policyVersion: 'coin-budget-v1',

      // 8%
      infrastructureBps: 800,

      // 7%
      realtimeMinutesBps: 700,

      // 5%
      operationsSalaryBps: 500,

      // 3%
      paymentRiskBps: 300,

      // 2%
      promoSafetyBps: 200,
    );
  }

  static bool everyCoinFeatureMustUseUniversalBudget() => true;

  static bool futureModulesMustInheritActiveBudgetPolicy() => true;

  static bool ownerCanAdjustBudgetAllocations() => true;

  static bool historicalPoliciesMustRemainVersioned() => true;

  static bool grossRevenueAndUserReturnMustRemainSeparate() => true;

  static bool platformProfitMustNeverBeAssumedGuaranteed() => true;
}
