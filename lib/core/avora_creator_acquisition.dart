enum AvoraCreatorSourcePlatform {
  instagram,
  facebook,
  snapchat,
  tiktok,
  youtube,
  otherApp,
  offlineAgency,
  directRecruitment,
}

enum AvoraCreatorPartnerStage {
  candidate,
  trial,
  active,
  featured,
  suspended,
}

class AvoraCreatorAcquisitionProfile {
  final String userId;

  final AvoraCreatorSourcePlatform sourcePlatform;

  final String? externalHandle;

  final int? externalFollowerCount;

  final String? countryCode;
  final String? languageCode;

  final String recruitedByUserId;
  final String? sourceCampaignId;

  final bool externalAuthenticityVerified;

  final DateTime onboardedAt;

  const AvoraCreatorAcquisitionProfile({
    required this.userId,
    required this.sourcePlatform,
    required this.recruitedByUserId,
    required this.onboardedAt,
    this.externalHandle,
    this.externalFollowerCount,
    this.countryCode,
    this.languageCode,
    this.sourceCampaignId,
    this.externalAuthenticityVerified = false,
  }) : assert(
          externalFollowerCount == null || externalFollowerCount >= 0,
        );
}

class AvoraCreatorPerformanceSnapshot {
  final int verifiedNewUsers;
  final int validPurchaserCount;
  final int confirmedRechargeCoins;
  final int confirmedGiftCoins;
  final int validLiveMinutes;
  final int activeDays;

  final int netEligibleCommercialCoins;

  const AvoraCreatorPerformanceSnapshot({
    this.verifiedNewUsers = 0,
    this.validPurchaserCount = 0,
    this.confirmedRechargeCoins = 0,
    this.confirmedGiftCoins = 0,
    this.validLiveMinutes = 0,
    this.activeDays = 0,
    this.netEligibleCommercialCoins = 0,
  })  : assert(verifiedNewUsers >= 0),
        assert(validPurchaserCount >= 0),
        assert(confirmedRechargeCoins >= 0),
        assert(confirmedGiftCoins >= 0),
        assert(validLiveMinutes >= 0),
        assert(activeDays >= 0),
        assert(netEligibleCommercialCoins >= 0);
}

class AvoraCreatorBenefitGateConfig {
  final int minValidPurchasers;
  final int minNetEligibleCommercialCoins;
  final int minValidLiveMinutes;
  final int minActiveDays;

  /// 10000 = 100%.
  final int maxBenefitCostBps;

  final bool requireExternalAuthenticity;

  const AvoraCreatorBenefitGateConfig({
    required this.minValidPurchasers,
    required this.minNetEligibleCommercialCoins,
    required this.minValidLiveMinutes,
    required this.minActiveDays,
    required this.maxBenefitCostBps,
    this.requireExternalAuthenticity = true,
  })  : assert(minValidPurchasers >= 0),
        assert(minNetEligibleCommercialCoins >= 0),
        assert(minValidLiveMinutes >= 0),
        assert(minActiveDays >= 0),
        assert(
          maxBenefitCostBps >= 0 && maxBenefitCostBps <= 10000,
        );
}

class AvoraCreatorBenefitDecision {
  final bool eligible;

  final String reason;

  final int maximumBenefitBudgetCoins;

  const AvoraCreatorBenefitDecision({
    required this.eligible,
    required this.reason,
    required this.maximumBenefitBudgetCoins,
  });
}

class AvoraCreatorBenefitGate {
  const AvoraCreatorBenefitGate._();

  static AvoraCreatorBenefitDecision evaluate({
    required AvoraCreatorAcquisitionProfile creator,
    required AvoraCreatorPerformanceSnapshot performance,
    required AvoraCreatorBenefitGateConfig config,
    required int estimatedBenefitCostCoins,
    required bool identityVerified,
    required bool adultVerified,
  }) {
    if (!identityVerified || !adultVerified) {
      return const AvoraCreatorBenefitDecision(
        eligible: false,
        reason: 'creator_verification_required',
        maximumBenefitBudgetCoins: 0,
      );
    }

    if (config.requireExternalAuthenticity &&
        !creator.externalAuthenticityVerified) {
      return const AvoraCreatorBenefitDecision(
        eligible: false,
        reason: 'external_authenticity_required',
        maximumBenefitBudgetCoins: 0,
      );
    }

    if (performance.validPurchaserCount < config.minValidPurchasers) {
      return const AvoraCreatorBenefitDecision(
        eligible: false,
        reason: 'purchaser_target_not_met',
        maximumBenefitBudgetCoins: 0,
      );
    }

    if (performance.netEligibleCommercialCoins <
        config.minNetEligibleCommercialCoins) {
      return const AvoraCreatorBenefitDecision(
        eligible: false,
        reason: 'commercial_target_not_met',
        maximumBenefitBudgetCoins: 0,
      );
    }

    if (performance.validLiveMinutes < config.minValidLiveMinutes) {
      return const AvoraCreatorBenefitDecision(
        eligible: false,
        reason: 'live_activity_target_not_met',
        maximumBenefitBudgetCoins: 0,
      );
    }

    if (performance.activeDays < config.minActiveDays) {
      return const AvoraCreatorBenefitDecision(
        eligible: false,
        reason: 'active_day_target_not_met',
        maximumBenefitBudgetCoins: 0,
      );
    }

    final budget =
        (performance.netEligibleCommercialCoins * config.maxBenefitCostBps) ~/
            10000;

    if (estimatedBenefitCostCoins < 0 || estimatedBenefitCostCoins > budget) {
      return AvoraCreatorBenefitDecision(
        eligible: false,
        reason: 'benefit_cost_exceeds_budget',
        maximumBenefitBudgetCoins: budget,
      );
    }

    return AvoraCreatorBenefitDecision(
      eligible: true,
      reason: 'creator_commercially_qualified',
      maximumBenefitBudgetCoins: budget,
    );
  }
}
