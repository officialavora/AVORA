enum AvoraWithdrawalStatus {
  requested,
  review,
  reserved,
  assigned,
  paid,
  failed,
  cancelled,
  reversed,
}

enum AvoraWithdrawalDenyReason {
  none,
  invalidAmount,
  userNotVerified,
  adultNotVerified,
  payoutBlocked,
  belowMinimum,
  abovePerRequestLimit,
  insufficientWithdrawableBalance,
  dailyUserLimitExceeded,
  monthlyUserLimitExceeded,
  platformReserveUnavailable,
  merchantUnavailable,
  merchantNotVerified,
  merchantRiskBlocked,
  merchantCapacityUnavailable,
}

class AvoraWithdrawalBalanceSnapshot {
  /// Final settled balance that is actually eligible for payout.
  final int withdrawableUnits;

  /// Free/VIP/Invite/Event promotional value.
  /// Not cash-withdrawable by default.
  final int promotionalUnits;

  /// Rankings, levels, event scores, etc.
  /// These are not money.
  final int progressionPoints;

  /// Earnings not yet cleared for withdrawal.
  final int pendingSettlementUnits;

  const AvoraWithdrawalBalanceSnapshot({
    required this.withdrawableUnits,
    this.promotionalUnits = 0,
    this.progressionPoints = 0,
    this.pendingSettlementUnits = 0,
  })  : assert(withdrawableUnits >= 0),
        assert(promotionalUnits >= 0),
        assert(progressionPoints >= 0),
        assert(pendingSettlementUnits >= 0);
}

class AvoraWithdrawalUserProfile {
  final String userId;

  final bool identityVerified;
  final bool adultVerified;

  final bool payoutBlocked;

  final AvoraWithdrawalBalanceSnapshot balances;

  final int withdrawnTodayUnits;
  final int withdrawnThisMonthUnits;

  const AvoraWithdrawalUserProfile({
    required this.userId,
    required this.identityVerified,
    required this.adultVerified,
    required this.balances,
    this.payoutBlocked = false,
    this.withdrawnTodayUnits = 0,
    this.withdrawnThisMonthUnits = 0,
  })  : assert(withdrawnTodayUnits >= 0),
        assert(withdrawnThisMonthUnits >= 0);
}

class AvoraMerchantPayoutCapacity {
  final String merchantUserId;

  final bool merchantVerified;
  final bool payoutEnabled;
  final bool riskBlocked;

  /// Merchant-funded payout reserve.
  final int fundedReserveUnits;

  /// Amount already reserved for pending withdrawals.
  final int reservedOutstandingUnits;

  final int dailyPayoutLimitUnits;
  final int paidTodayUnits;

  const AvoraMerchantPayoutCapacity({
    required this.merchantUserId,
    required this.merchantVerified,
    required this.payoutEnabled,
    required this.fundedReserveUnits,
    required this.reservedOutstandingUnits,
    required this.dailyPayoutLimitUnits,
    required this.paidTodayUnits,
    this.riskBlocked = false,
  })  : assert(fundedReserveUnits >= 0),
        assert(reservedOutstandingUnits >= 0),
        assert(dailyPayoutLimitUnits >= 0),
        assert(paidTodayUnits >= 0);

  int get availableReserveUnits {
    final value = fundedReserveUnits - reservedOutstandingUnits;
    return value > 0 ? value : 0;
  }

  int get remainingDailyCapacityUnits {
    final value = dailyPayoutLimitUnits - paidTodayUnits;
    return value > 0 ? value : 0;
  }

  int get availablePayoutCapacityUnits {
    final reserve = availableReserveUnits;
    final daily = remainingDailyCapacityUnits;

    return reserve < daily ? reserve : daily;
  }
}

class AvoraPlatformWithdrawalReserve {
  final int fundedReserveUnits;
  final int reservedOutstandingUnits;

  const AvoraPlatformWithdrawalReserve({
    required this.fundedReserveUnits,
    required this.reservedOutstandingUnits,
  })  : assert(fundedReserveUnits >= 0),
        assert(reservedOutstandingUnits >= 0);

  int get availableReserveUnits {
    final value = fundedReserveUnits - reservedOutstandingUnits;
    return value > 0 ? value : 0;
  }
}

class AvoraWithdrawalPolicyConfig {
  final int minimumWithdrawalUnits;
  final int maximumPerRequestUnits;

  final int dailyUserLimitUnits;
  final int monthlyUserLimitUnits;

  const AvoraWithdrawalPolicyConfig({
    required this.minimumWithdrawalUnits,
    required this.maximumPerRequestUnits,
    required this.dailyUserLimitUnits,
    required this.monthlyUserLimitUnits,
  })  : assert(minimumWithdrawalUnits > 0),
        assert(maximumPerRequestUnits >= minimumWithdrawalUnits),
        assert(dailyUserLimitUnits > 0),
        assert(monthlyUserLimitUnits > 0);
}

class AvoraWithdrawalDecision {
  final bool canAssignToMerchant;

  /// When liquidity/capacity is unavailable,
  /// request can stay queued instead of disappearing.
  final bool keepQueued;

  final AvoraWithdrawalDenyReason reason;

  final int requestedUnits;

  const AvoraWithdrawalDecision({
    required this.canAssignToMerchant,
    required this.keepQueued,
    required this.reason,
    required this.requestedUnits,
  });
}

class AvoraWithdrawalGuard {
  const AvoraWithdrawalGuard._();

  static AvoraWithdrawalDecision evaluate({
    required int requestedUnits,
    required AvoraWithdrawalUserProfile user,
    required AvoraWithdrawalPolicyConfig policy,
    required AvoraPlatformWithdrawalReserve platformReserve,
    AvoraMerchantPayoutCapacity? merchant,
  }) {
    AvoraWithdrawalDecision deny(
      AvoraWithdrawalDenyReason reason, {
      bool queue = false,
    }) {
      return AvoraWithdrawalDecision(
        canAssignToMerchant: false,
        keepQueued: queue,
        reason: reason,
        requestedUnits: requestedUnits,
      );
    }

    if (requestedUnits <= 0) {
      return deny(AvoraWithdrawalDenyReason.invalidAmount);
    }

    if (!user.identityVerified) {
      return deny(
        AvoraWithdrawalDenyReason.userNotVerified,
      );
    }

    if (!user.adultVerified) {
      return deny(
        AvoraWithdrawalDenyReason.adultNotVerified,
      );
    }

    if (user.payoutBlocked) {
      return deny(
        AvoraWithdrawalDenyReason.payoutBlocked,
      );
    }

    if (requestedUnits < policy.minimumWithdrawalUnits) {
      return deny(
        AvoraWithdrawalDenyReason.belowMinimum,
      );
    }

    if (requestedUnits > policy.maximumPerRequestUnits) {
      return deny(
        AvoraWithdrawalDenyReason.abovePerRequestLimit,
      );
    }

    if (requestedUnits > user.balances.withdrawableUnits) {
      return deny(
        AvoraWithdrawalDenyReason.insufficientWithdrawableBalance,
      );
    }

    if (user.withdrawnTodayUnits + requestedUnits >
        policy.dailyUserLimitUnits) {
      return deny(
        AvoraWithdrawalDenyReason.dailyUserLimitExceeded,
      );
    }

    if (user.withdrawnThisMonthUnits + requestedUnits >
        policy.monthlyUserLimitUnits) {
      return deny(
        AvoraWithdrawalDenyReason.monthlyUserLimitExceeded,
      );
    }

    if (requestedUnits > platformReserve.availableReserveUnits) {
      return deny(
        AvoraWithdrawalDenyReason.platformReserveUnavailable,
        queue: true,
      );
    }

    if (merchant == null || !merchant.payoutEnabled) {
      return deny(
        AvoraWithdrawalDenyReason.merchantUnavailable,
        queue: true,
      );
    }

    if (!merchant.merchantVerified) {
      return deny(
        AvoraWithdrawalDenyReason.merchantNotVerified,
      );
    }

    if (merchant.riskBlocked) {
      return deny(
        AvoraWithdrawalDenyReason.merchantRiskBlocked,
      );
    }

    if (requestedUnits > merchant.availablePayoutCapacityUnits) {
      return deny(
        AvoraWithdrawalDenyReason.merchantCapacityUnavailable,
        queue: true,
      );
    }

    return AvoraWithdrawalDecision(
      canAssignToMerchant: true,
      keepQueued: false,
      reason: AvoraWithdrawalDenyReason.none,
      requestedUnits: requestedUnits,
    );
  }
}
