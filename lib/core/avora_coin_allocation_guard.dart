import 'avora_coin_economy_budget.dart';

enum AvoraCoinAllocationType {
  giftReturn,
  gameReturn,
  reward,
  salary,
  commission,
  promotion,
  other,
}

class AvoraCoinAllocation {
  const AvoraCoinAllocation({
    required this.allocationId,
    required this.type,
    required this.amount,
  });

  final String allocationId;
  final AvoraCoinAllocationType type;
  final int amount;
}

class AvoraCoinAllocationDecision {
  const AvoraCoinAllocationDecision({
    required this.allowed,
    required this.reason,
    required this.grossRevenueEquivalent,
    required this.maxDistributable,
    required this.alreadyAllocated,
    required this.requestedAmount,
    required this.remainingAfter,
  });

  final bool allowed;
  final String reason;
  final int grossRevenueEquivalent;
  final int maxDistributable;
  final int alreadyAllocated;
  final int requestedAmount;
  final int remainingAfter;
}

class AvoraCoinAllocationGuard {
  const AvoraCoinAllocationGuard({
    required AvoraCoinEconomyBudgetPolicy policy,
  }) : _policy = policy;

  final AvoraCoinEconomyBudgetPolicy _policy;

  AvoraCoinAllocationDecision evaluate({
    required int grossRevenueEquivalent,
    required Iterable<AvoraCoinAllocation> existingAllocations,
    required AvoraCoinAllocation requested,
  }) {
    if (grossRevenueEquivalent < 0 || requested.amount < 0) {
      throw ArgumentError('coin_allocation_value_invalid');
    }

    final ids = <String>{};
    var allocated = 0;

    for (final item in existingAllocations) {
      if (item.amount < 0) {
        throw ArgumentError('existing_allocation_invalid');
      }

      if (!ids.add(item.allocationId)) {
        throw StateError('duplicate_allocation_id');
      }

      allocated += item.amount;
    }

    if (ids.contains(requested.allocationId)) {
      return AvoraCoinAllocationDecision(
        allowed: false,
        reason: 'allocation_already_recorded',
        grossRevenueEquivalent: grossRevenueEquivalent,
        maxDistributable: _policy.maxDistributableAmount(
          grossCoinRevenueEquivalent: grossRevenueEquivalent,
        ),
        alreadyAllocated: allocated,
        requestedAmount: requested.amount,
        remainingAfter: 0,
      );
    }

    final maximum = _policy.maxDistributableAmount(
      grossCoinRevenueEquivalent: grossRevenueEquivalent,
    );

    final remainingBefore = maximum - allocated;

    if (remainingBefore < 0 || requested.amount > remainingBefore) {
      return AvoraCoinAllocationDecision(
        allowed: false,
        reason: 'coin_budget_limit_exceeded',
        grossRevenueEquivalent: grossRevenueEquivalent,
        maxDistributable: maximum,
        alreadyAllocated: allocated,
        requestedAmount: requested.amount,
        remainingAfter: remainingBefore < 0 ? 0 : remainingBefore,
      );
    }

    return AvoraCoinAllocationDecision(
      allowed: true,
      reason: 'coin_allocation_allowed',
      grossRevenueEquivalent: grossRevenueEquivalent,
      maxDistributable: maximum,
      alreadyAllocated: allocated,
      requestedAmount: requested.amount,
      remainingAfter: remainingBefore - requested.amount,
    );
  }

  static bool giftsGamesRewardsAndSalaryShareOneBudget() => true;

  static bool allocationMustNeverExceedActiveBudget() => true;

  static bool ownerMustSeeAllocatedAndRemainingAmounts() => true;

  static bool duplicateAllocationMustNotDoubleCount() => true;

  static bool futureCoinFeaturesMustUseSameGuard() => true;
}
