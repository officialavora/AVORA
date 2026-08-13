import 'avora_seller_capacity.dart';

enum AvoraTradingOrderDenyReason {
  none,
  invalidAmount,
  sellerUnavailable,
  belowMinimum,
  aboveConfiguredMaximum,
  insufficientAvailableCapacity,
}

class AvoraTradingOrderDecision {
  final bool allowed;
  final AvoraTradingOrderDenyReason reason;

  /// Safe server-computed maximum that can be ordered right now.
  final int maximumAvailableNowUnits;

  const AvoraTradingOrderDecision({
    required this.allowed,
    required this.reason,
    required this.maximumAvailableNowUnits,
  });
}

class AvoraTradingOrderGuard {
  const AvoraTradingOrderGuard._();

  static AvoraTradingOrderDecision evaluate({
    required int requestedUnits,
    required AvoraTradingCapacitySnapshot seller,
  }) {
    final available = seller.availableOrderCapacityUnits;

    if (requestedUnits <= 0) {
      return AvoraTradingOrderDecision(
        allowed: false,
        reason: AvoraTradingOrderDenyReason.invalidAmount,
        maximumAvailableNowUnits: available,
      );
    }

    final operational = seller.verified &&
        seller.online &&
        seller.tradingEnabled &&
        !seller.riskBlocked;

    if (!operational) {
      return const AvoraTradingOrderDecision(
        allowed: false,
        reason: AvoraTradingOrderDenyReason.sellerUnavailable,
        maximumAvailableNowUnits: 0,
      );
    }

    if (requestedUnits < seller.minimumOrderUnits) {
      return AvoraTradingOrderDecision(
        allowed: false,
        reason: AvoraTradingOrderDenyReason.belowMinimum,
        maximumAvailableNowUnits: available,
      );
    }

    if (requestedUnits > seller.maximumOrderUnits) {
      return AvoraTradingOrderDecision(
        allowed: false,
        reason: AvoraTradingOrderDenyReason.aboveConfiguredMaximum,
        maximumAvailableNowUnits: available,
      );
    }

    if (requestedUnits > available) {
      return AvoraTradingOrderDecision(
        allowed: false,
        reason: AvoraTradingOrderDenyReason.insufficientAvailableCapacity,
        maximumAvailableNowUnits: available,
      );
    }

    return AvoraTradingOrderDecision(
      allowed: true,
      reason: AvoraTradingOrderDenyReason.none,
      maximumAvailableNowUnits: available,
    );
  }
}
