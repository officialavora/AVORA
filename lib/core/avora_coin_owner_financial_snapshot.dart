import 'avora_coin_allocation_guard.dart';
import 'avora_coin_economy_budget.dart';

class AvoraCoinOwnerFinancialSnapshot {
  const AvoraCoinOwnerFinancialSnapshot({
    required this.policyVersion,
    required this.grossCoinRevenueEquivalent,
    required this.totalAllocated,
    required this.reserveAmount,
    required this.maxDistributable,
    required this.remainingDistributable,
    required this.allocationsByType,
  });

  final String policyVersion;
  final int grossCoinRevenueEquivalent;

  final int totalAllocated;
  final int reserveAmount;
  final int maxDistributable;
  final int remainingDistributable;

  final Map<AvoraCoinAllocationType, int> allocationsByType;

  int allocationFor(AvoraCoinAllocationType type) {
    return allocationsByType[type] ?? 0;
  }

  double get allocationUsagePercent {
    if (maxDistributable == 0) {
      return 0;
    }

    return (totalAllocated / maxDistributable) * 100;
  }
}

class AvoraCoinOwnerFinancialSnapshotBuilder {
  const AvoraCoinOwnerFinancialSnapshotBuilder({
    required AvoraCoinEconomyBudgetPolicy policy,
  }) : _policy = policy;

  final AvoraCoinEconomyBudgetPolicy _policy;

  AvoraCoinOwnerFinancialSnapshot build({
    required int grossCoinRevenueEquivalent,
    required Iterable<AvoraCoinAllocation> allocations,
  }) {
    if (grossCoinRevenueEquivalent < 0) {
      throw ArgumentError('gross_revenue_must_not_be_negative');
    }

    final ids = <String>{};
    final totals = <AvoraCoinAllocationType, int>{};
    var totalAllocated = 0;

    for (final allocation in allocations) {
      if (allocation.allocationId.trim().isEmpty || allocation.amount < 0) {
        throw ArgumentError('invalid_coin_allocation');
      }

      if (!ids.add(allocation.allocationId)) {
        throw StateError('duplicate_allocation_id');
      }

      totalAllocated += allocation.amount;

      totals[allocation.type] =
          (totals[allocation.type] ?? 0) + allocation.amount;
    }

    final reserve = _policy.reserveAmount(
      grossCoinRevenueEquivalent: grossCoinRevenueEquivalent,
    );

    final maximum = _policy.maxDistributableAmount(
      grossCoinRevenueEquivalent: grossCoinRevenueEquivalent,
    );

    final remaining = maximum - totalAllocated;

    return AvoraCoinOwnerFinancialSnapshot(
      policyVersion: _policy.policyVersion,
      grossCoinRevenueEquivalent: grossCoinRevenueEquivalent,
      totalAllocated: totalAllocated,
      reserveAmount: reserve,
      maxDistributable: maximum,
      remainingDistributable: remaining < 0 ? 0 : remaining,
      allocationsByType: Map<AvoraCoinAllocationType, int>.unmodifiable(totals),
    );
  }

  static bool ownerMustSeeGrossCoinEconomy() => true;

  static bool ownerMustSeeAllocationBreakdown() => true;

  static bool ownerMustSeeReserveAndRemainingBudget() => true;

  static bool snapshotMustPreserveBudgetPolicyVersion() => true;

  static bool userFinancialViewMustRemainSeparateFromOwnerView() => true;

  static bool futureCoinModulesMustExtendAllocationBreakdown() => true;
}
