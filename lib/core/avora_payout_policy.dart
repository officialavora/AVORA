enum AvoraWalletValueType {
  /// User-purchased/spendable virtual currency.
  coins,

  /// Eligible receiver/creator earning representation.
  diamonds,

  /// Levels, rankings, targets and event score.
  /// Never cash by itself.
  rewardPoints,

  /// Optional future non-cash/cosmetic reward currency.
  crystals,

  /// Final settled fiat-denominated payout balance.
  withdrawableBalance,
}

enum AvoraPayoutSource {
  eligibleGiftEarning,
  hostSalary,
  creatorPartnerEarning,
  staffCommission,

  /// Keep separately configurable because call monetization
  /// may require additional country/store review.
  privateCallEarning,

  gameWinning,
  luckyGiftReturn,
  luckyPocketClaim,

  inviteBonus,
  eventBonus,
  vipBonus,
  promotionalReward,
}

class AvoraCountryPayoutPolicy {
  final String countryCode;

  /// ISO currency code such as INR, USD, SAR.
  final String currencyCode;

  /// Stored in the currency's minor unit.
  ///
  /// INR example:
  /// 100000 paise = ₹1,000.
  final int minimumWithdrawalMinorUnits;

  final int? maximumWithdrawalMinorUnits;

  final bool allowEligibleGiftEarnings;
  final bool allowHostSalary;
  final bool allowCreatorPartnerEarnings;
  final bool allowStaffCommission;
  final bool allowPrivateCallEarnings;

  final bool allowGameWinnings;
  final bool allowLuckyGiftReturns;
  final bool allowLuckyPocketClaims;

  final bool allowInviteBonus;
  final bool allowEventBonus;
  final bool allowVipBonus;
  final bool allowPromotionalReward;

  const AvoraCountryPayoutPolicy({
    required this.countryCode,
    required this.currencyCode,
    required this.minimumWithdrawalMinorUnits,
    this.maximumWithdrawalMinorUnits,
    this.allowEligibleGiftEarnings = true,
    this.allowHostSalary = true,
    this.allowCreatorPartnerEarnings = true,
    this.allowStaffCommission = true,
    this.allowPrivateCallEarnings = false,
    this.allowGameWinnings = false,
    this.allowLuckyGiftReturns = false,
    this.allowLuckyPocketClaims = false,
    this.allowInviteBonus = false,
    this.allowEventBonus = false,
    this.allowVipBonus = false,
    this.allowPromotionalReward = false,
  })  : assert(minimumWithdrawalMinorUnits > 0),
        assert(
          maximumWithdrawalMinorUnits == null ||
              maximumWithdrawalMinorUnits >= minimumWithdrawalMinorUnits,
        );

  /// Recommended conservative India launch profile.
  ///
  /// ₹1,000 minimum withdrawal.
  /// Gaming/chance/free-promo sources are non-withdrawable.
  const AvoraCountryPayoutPolicy.indiaLaunch()
      : countryCode = 'IN',
        currencyCode = 'INR',
        minimumWithdrawalMinorUnits = 100000,
        maximumWithdrawalMinorUnits = null,
        allowEligibleGiftEarnings = true,
        allowHostSalary = true,
        allowCreatorPartnerEarnings = true,
        allowStaffCommission = true,
        allowPrivateCallEarnings = false,
        allowGameWinnings = false,
        allowLuckyGiftReturns = false,
        allowLuckyPocketClaims = false,
        allowInviteBonus = false,
        allowEventBonus = false,
        allowVipBonus = false,
        allowPromotionalReward = false;

  bool sourceCanBecomeWithdrawable(
    AvoraPayoutSource source,
  ) {
    switch (source) {
      case AvoraPayoutSource.eligibleGiftEarning:
        return allowEligibleGiftEarnings;

      case AvoraPayoutSource.hostSalary:
        return allowHostSalary;

      case AvoraPayoutSource.creatorPartnerEarning:
        return allowCreatorPartnerEarnings;

      case AvoraPayoutSource.staffCommission:
        return allowStaffCommission;

      case AvoraPayoutSource.privateCallEarning:
        return allowPrivateCallEarnings;

      case AvoraPayoutSource.gameWinning:
        return allowGameWinnings;

      case AvoraPayoutSource.luckyGiftReturn:
        return allowLuckyGiftReturns;

      case AvoraPayoutSource.luckyPocketClaim:
        return allowLuckyPocketClaims;

      case AvoraPayoutSource.inviteBonus:
        return allowInviteBonus;

      case AvoraPayoutSource.eventBonus:
        return allowEventBonus;

      case AvoraPayoutSource.vipBonus:
        return allowVipBonus;

      case AvoraPayoutSource.promotionalReward:
        return allowPromotionalReward;
    }
  }

  bool withdrawalAmountAllowed(
    int requestedMinorUnits,
  ) {
    if (requestedMinorUnits < minimumWithdrawalMinorUnits) {
      return false;
    }

    final maximum = maximumWithdrawalMinorUnits;

    if (maximum != null && requestedMinorUnits > maximum) {
      return false;
    }

    return true;
  }
}

class AvoraWalletValuePolicy {
  const AvoraWalletValuePolicy._();

  static bool isDirectlyWithdrawable(
    AvoraWalletValueType type,
  ) {
    return type == AvoraWalletValueType.withdrawableBalance;
  }

  static bool isProgressOnly(
    AvoraWalletValueType type,
  ) {
    return type == AvoraWalletValueType.rewardPoints;
  }
}
