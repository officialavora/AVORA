enum AvoraTradingRole {
  seller,
  merchant,
}

enum AvoraCapacityLevel {
  unavailable,
  low,
  medium,
  high,
}

class AvoraCapacityThresholdConfig {
  /// Available units below this value are shown as LOW.
  final int mediumStartsAt;

  /// Available units at/above this value are shown as HIGH.
  final int highStartsAt;

  const AvoraCapacityThresholdConfig({
    required this.mediumStartsAt,
    required this.highStartsAt,
  })  : assert(mediumStartsAt > 0),
        assert(highStartsAt > mediumStartsAt);
}

class AvoraTradingCapacitySnapshot {
  final String userId;

  final AvoraTradingRole role;

  final bool verified;
  final bool online;
  final bool tradingEnabled;
  final bool riskBlocked;

  /// Seller:
  /// funded sellable coin inventory.
  ///
  /// Merchant:
  /// funded payout reserve.
  final int fundedUnits;

  /// Already locked for active orders/withdrawals.
  final int reservedUnits;

  /// Optional units unavailable due to risk/settlement hold.
  final int heldUnits;

  /// Per-order limits.
  final int minimumOrderUnits;
  final int maximumOrderUnits;

  /// Remaining daily capacity after completed activity.
  final int remainingDailyCapacityUnits;

  const AvoraTradingCapacitySnapshot({
    required this.userId,
    required this.role,
    required this.verified,
    required this.online,
    required this.tradingEnabled,
    required this.fundedUnits,
    required this.reservedUnits,
    required this.heldUnits,
    required this.minimumOrderUnits,
    required this.maximumOrderUnits,
    required this.remainingDailyCapacityUnits,
    this.riskBlocked = false,
  })  : assert(fundedUnits >= 0),
        assert(reservedUnits >= 0),
        assert(heldUnits >= 0),
        assert(minimumOrderUnits > 0),
        assert(maximumOrderUnits >= minimumOrderUnits),
        assert(remainingDailyCapacityUnits >= 0);

  int get rawAvailableUnits {
    final value = fundedUnits - reservedUnits - heldUnits;
    return value > 0 ? value : 0;
  }

  int get availableOrderCapacityUnits {
    final raw = rawAvailableUnits;

    var value = raw;

    if (remainingDailyCapacityUnits < value) {
      value = remainingDailyCapacityUnits;
    }

    if (maximumOrderUnits < value) {
      value = maximumOrderUnits;
    }

    return value > 0 ? value : 0;
  }
}

class AvoraPublicTradingCapacity {
  final String userId;
  final AvoraTradingRole role;

  final bool verified;
  final bool online;

  final AvoraCapacityLevel capacityLevel;

  final bool canAcceptOrder;

  final int minimumOrderUnits;

  /// Safe server-calculated order capacity.
  /// This is not the user's private gross wallet balance.
  final int maximumOrderAvailableNowUnits;

  const AvoraPublicTradingCapacity({
    required this.userId,
    required this.role,
    required this.verified,
    required this.online,
    required this.capacityLevel,
    required this.canAcceptOrder,
    required this.minimumOrderUnits,
    required this.maximumOrderAvailableNowUnits,
  });
}

class AvoraTradingCapacityEngine {
  const AvoraTradingCapacityEngine._();

  static AvoraPublicTradingCapacity publicView({
    required AvoraTradingCapacitySnapshot snapshot,
    required AvoraCapacityThresholdConfig thresholds,
  }) {
    final capacity = snapshot.availableOrderCapacityUnits;

    final operational = snapshot.verified &&
        snapshot.online &&
        snapshot.tradingEnabled &&
        !snapshot.riskBlocked;

    final level = _levelFor(
      operational ? capacity : 0,
      thresholds,
    );

    final canAccept = operational && capacity >= snapshot.minimumOrderUnits;

    return AvoraPublicTradingCapacity(
      userId: snapshot.userId,
      role: snapshot.role,
      verified: snapshot.verified,
      online: snapshot.online,
      capacityLevel: level,
      canAcceptOrder: canAccept,
      minimumOrderUnits: snapshot.minimumOrderUnits,
      maximumOrderAvailableNowUnits: canAccept ? capacity : 0,
    );
  }

  static AvoraCapacityLevel _levelFor(
    int availableUnits,
    AvoraCapacityThresholdConfig thresholds,
  ) {
    if (availableUnits <= 0) {
      return AvoraCapacityLevel.unavailable;
    }

    if (availableUnits < thresholds.mediumStartsAt) {
      return AvoraCapacityLevel.low;
    }

    if (availableUnits < thresholds.highStartsAt) {
      return AvoraCapacityLevel.medium;
    }

    return AvoraCapacityLevel.high;
  }
}
