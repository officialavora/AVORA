enum AvoraCoinSource {
  purchased,
  earned,
  promotional,
  vipBonus,
  inviteBonus,
  eventBonus,
  adjustment,
}

enum AvoraRewardUsage {
  spend,
  gift,
  transfer,
  exchange,
  withdraw,
}

class AvoraRewardEconomyPolicy {
  /// Purchased currency should remain distinct from
  /// free/promotional issuance.
  final bool purchasedCoinsExpire;

  /// Free promotional coins may be usable for engagement
  /// without automatically becoming cash-out liability.
  final bool promoCanGift;
  final bool promoCanTransfer;
  final bool promoCanWithdraw;

  /// Percentage of promo-funded gifting that may create
  /// withdrawable receiver diamond credit.
  ///
  /// 10000 = 100%
  /// Recommended default = 0.
  final int promoWithdrawableDiamondBps;

  /// Optional promo issuance controls.
  final int? dailyPromoCoinCap;
  final int? monthlyPromoCoinCap;

  const AvoraRewardEconomyPolicy({
    this.purchasedCoinsExpire = false,
    this.promoCanGift = true,
    this.promoCanTransfer = false,
    this.promoCanWithdraw = false,
    this.promoWithdrawableDiamondBps = 0,
    this.dailyPromoCoinCap,
    this.monthlyPromoCoinCap,
  })  : assert(
          promoWithdrawableDiamondBps >= 0 &&
              promoWithdrawableDiamondBps <= 10000,
        ),
        assert(
          dailyPromoCoinCap == null || dailyPromoCoinCap >= 0,
        ),
        assert(
          monthlyPromoCoinCap == null || monthlyPromoCoinCap >= 0,
        );

  bool usageAllowed({
    required AvoraCoinSource source,
    required AvoraRewardUsage usage,
  }) {
    final promotional = switch (source) {
      AvoraCoinSource.promotional ||
      AvoraCoinSource.vipBonus ||
      AvoraCoinSource.inviteBonus ||
      AvoraCoinSource.eventBonus =>
        true,
      _ => false,
    };

    if (!promotional) {
      return true;
    }

    return switch (usage) {
      AvoraRewardUsage.spend => true,
      AvoraRewardUsage.gift => promoCanGift,
      AvoraRewardUsage.transfer => promoCanTransfer,
      AvoraRewardUsage.exchange => false,
      AvoraRewardUsage.withdraw => promoCanWithdraw,
    };
  }

  int withdrawableDiamondCreditFromPromo({
    required int giftAmount,
  }) {
    if (giftAmount <= 0) {
      return 0;
    }

    return (giftAmount * promoWithdrawableDiamondBps) ~/ 10000;
  }
}

class AvoraPolicyVersion {
  final String id;
  final String version;

  /// Null means global base policy.
  final String? countryCode;

  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;

  final AvoraRewardEconomyPolicy economyPolicy;

  const AvoraPolicyVersion({
    required this.id,
    required this.version,
    required this.effectiveFrom,
    required this.economyPolicy,
    this.countryCode,
    this.effectiveUntil,
  });

  bool isEffectiveAt(DateTime time) {
    if (time.isBefore(effectiveFrom)) {
      return false;
    }

    final until = effectiveUntil;

    if (until != null && time.isAfter(until)) {
      return false;
    }

    return true;
  }
}
