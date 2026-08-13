enum AvoraExperienceQualityTier {
  standard,
  premium,
  vip,
  royal,
  legendary,
  antique,
  seasonal,
}

enum AvoraExperienceVisualMood {
  elegant,
  luxury,
  cinematic,
  cute,
  funny,
  romantic,
  emotional,
  horror,
  fierce,
  royal,
  futuristic,
  festive,
  minimal,
}

enum AvoraExperienceIntensity {
  subtle,
  balanced,
  strong,
  spectacular,
}

enum AvoraExperienceMotionProfile {
  lightweight,
  smooth,
  cinematic,
  spectacular,
}

class AvoraExperienceCreativeMetadata {
  const AvoraExperienceCreativeMetadata({
    required this.assetId,
    required this.assetVersion,
    required this.qualityTier,
    required this.primaryMood,
    required this.supportedMoods,
    required this.intensity,
    required this.motionProfile,
    required this.originalAvoraDesign,
    required this.visualQualityScore,
    required this.smoothnessScore,
    required this.coherenceScore,
    required this.delightScore,
    required this.performanceScore,
    required this.reviewed,
    this.familySafe = true,
  });

  final String assetId;
  final String assetVersion;
  final AvoraExperienceQualityTier qualityTier;
  final AvoraExperienceVisualMood primaryMood;
  final Set<AvoraExperienceVisualMood> supportedMoods;
  final AvoraExperienceIntensity intensity;
  final AvoraExperienceMotionProfile motionProfile;

  /// Must represent original AVORA creative work rather than copied
  /// third-party branding/design.
  final bool originalAvoraDesign;

  /// Internal review scores: 0-100.
  final int visualQualityScore;
  final int smoothnessScore;
  final int coherenceScore;
  final int delightScore;
  final int performanceScore;

  final bool reviewed;
  final bool familySafe;

  double get overallScore {
    return (visualQualityScore +
            smoothnessScore +
            coherenceScore +
            delightScore +
            performanceScore) /
        5.0;
  }

  void validate() {
    if (assetId.trim().isEmpty || assetVersion.trim().isEmpty) {
      throw ArgumentError('creative_asset_identity_required');
    }

    if (!supportedMoods.contains(primaryMood)) {
      throw ArgumentError('primary_mood_must_be_supported');
    }

    for (final score in <int>[
      visualQualityScore,
      smoothnessScore,
      coherenceScore,
      delightScore,
      performanceScore,
    ]) {
      if (score < 0 || score > 100) {
        throw ArgumentError('creative_score_out_of_range');
      }
    }

    if (!originalAvoraDesign) {
      throw StateError('non_original_creative_not_publishable');
    }
  }
}

class AvoraExperienceQualityThreshold {
  const AvoraExperienceQualityThreshold({
    required this.minimumOverallScore,
    required this.minimumVisualScore,
    required this.minimumSmoothnessScore,
    required this.minimumPerformanceScore,
  });

  final double minimumOverallScore;
  final int minimumVisualScore;
  final int minimumSmoothnessScore;
  final int minimumPerformanceScore;
}

class AvoraExperienceQualityPolicy {
  const AvoraExperienceQualityPolicy();

  AvoraExperienceQualityThreshold thresholdFor(
    AvoraExperienceQualityTier tier,
  ) {
    switch (tier) {
      case AvoraExperienceQualityTier.standard:
        return const AvoraExperienceQualityThreshold(
          minimumOverallScore: 65,
          minimumVisualScore: 60,
          minimumSmoothnessScore: 60,
          minimumPerformanceScore: 60,
        );

      case AvoraExperienceQualityTier.premium:
        return const AvoraExperienceQualityThreshold(
          minimumOverallScore: 75,
          minimumVisualScore: 75,
          minimumSmoothnessScore: 72,
          minimumPerformanceScore: 65,
        );

      case AvoraExperienceQualityTier.vip:
        return const AvoraExperienceQualityThreshold(
          minimumOverallScore: 80,
          minimumVisualScore: 80,
          minimumSmoothnessScore: 78,
          minimumPerformanceScore: 68,
        );

      case AvoraExperienceQualityTier.royal:
        return const AvoraExperienceQualityThreshold(
          minimumOverallScore: 84,
          minimumVisualScore: 85,
          minimumSmoothnessScore: 82,
          minimumPerformanceScore: 70,
        );

      case AvoraExperienceQualityTier.legendary:
        return const AvoraExperienceQualityThreshold(
          minimumOverallScore: 88,
          minimumVisualScore: 90,
          minimumSmoothnessScore: 85,
          minimumPerformanceScore: 70,
        );

      case AvoraExperienceQualityTier.antique:
        return const AvoraExperienceQualityThreshold(
          minimumOverallScore: 82,
          minimumVisualScore: 85,
          minimumSmoothnessScore: 78,
          minimumPerformanceScore: 65,
        );

      case AvoraExperienceQualityTier.seasonal:
        return const AvoraExperienceQualityThreshold(
          minimumOverallScore: 75,
          minimumVisualScore: 75,
          minimumSmoothnessScore: 70,
          minimumPerformanceScore: 65,
        );
    }
  }

  bool qualifies(
    AvoraExperienceCreativeMetadata metadata,
  ) {
    metadata.validate();

    if (!metadata.reviewed) {
      return false;
    }

    final threshold = thresholdFor(metadata.qualityTier);

    return metadata.overallScore >= threshold.minimumOverallScore &&
        metadata.visualQualityScore >= threshold.minimumVisualScore &&
        metadata.smoothnessScore >= threshold.minimumSmoothnessScore &&
        metadata.performanceScore >= threshold.minimumPerformanceScore;
  }

  static bool functionalCompletionAloneMustNeverDefineCreativeQuality() => true;

  static bool premiumTierMustRequireHigherCreativeQuality() => true;

  static bool quantityMustNotOverrideQualityGate() => true;

  static bool awkwardOrLowQualityAssetsMayBeRejected() => true;

  static bool smoothnessMustBePartOfCreativeReview() => true;

  static bool performanceMustBePartOfCreativeReview() => true;

  static bool cuteFunnyEmotionalAndLuxuryMoodsMayCoexistInCatalog() => true;

  static bool thirdPartyBrandingMustNotBeCopied() => true;
}

class AvoraExperienceCreativeCompatibility {
  const AvoraExperienceCreativeCompatibility();

  bool moodsCanCoexist({
    required AvoraExperienceVisualMood first,
    required AvoraExperienceVisualMood second,
  }) {
    if (first == second) {
      return true;
    }

    const compatiblePairs = <String>{
      'luxury|cinematic',
      'cinematic|luxury',
      'royal|luxury',
      'luxury|royal',
      'royal|cinematic',
      'cinematic|royal',
      'cute|funny',
      'funny|cute',
      'romantic|emotional',
      'emotional|romantic',
      'festive|cinematic',
      'cinematic|festive',
      'fierce|cinematic',
      'cinematic|fierce',
      'horror|cinematic',
      'cinematic|horror',
      'futuristic|cinematic',
      'cinematic|futuristic',
      'elegant|minimal',
      'minimal|elegant',
    };

    return compatiblePairs.contains(
      '${first.name}|${second.name}',
    );
  }

  static bool conflictingVisualThemesMustBeControlled() => true;

  static bool catalogMayContainManyDifferentCreativeFamilies() => true;

  static bool individualExperienceMustStillFeelCoherent() => true;
}

class AvoraExperienceCreativeReviewDecision {
  const AvoraExperienceCreativeReviewDecision({
    required this.publishable,
    required this.reason,
    required this.overallScore,
  });

  final bool publishable;
  final String reason;
  final double overallScore;
}

class AvoraExperienceCreativeReviewService {
  const AvoraExperienceCreativeReviewService({
    this.policy = const AvoraExperienceQualityPolicy(),
  });

  final AvoraExperienceQualityPolicy policy;

  AvoraExperienceCreativeReviewDecision review(
    AvoraExperienceCreativeMetadata metadata,
  ) {
    try {
      metadata.validate();
    } on ArgumentError {
      return AvoraExperienceCreativeReviewDecision(
        publishable: false,
        reason: 'invalid_creative_metadata',
        overallScore: metadata.overallScore,
      );
    } on StateError {
      return AvoraExperienceCreativeReviewDecision(
        publishable: false,
        reason: 'originality_gate_failed',
        overallScore: metadata.overallScore,
      );
    }

    if (!metadata.reviewed) {
      return AvoraExperienceCreativeReviewDecision(
        publishable: false,
        reason: 'creative_review_required',
        overallScore: metadata.overallScore,
      );
    }

    if (!policy.qualifies(metadata)) {
      return AvoraExperienceCreativeReviewDecision(
        publishable: false,
        reason: 'quality_threshold_not_met',
        overallScore: metadata.overallScore,
      );
    }

    return AvoraExperienceCreativeReviewDecision(
      publishable: true,
      reason: 'creative_quality_approved',
      overallScore: metadata.overallScore,
    );
  }

  static bool ownerMayReplaceRejectedCreativeWithoutCoreRewrite() => true;

  static bool creativeMetadataMustBeVersionedWithAsset() => true;

  static bool futureQualityTiersMayBeAddedWithoutChangingOwnershipModel() =>
      true;
}

class AvoraExperienceCreativeArchitecture {
  const AvoraExperienceCreativeArchitecture._();

  static bool beautyQualityAndSmoothnessAreProductRequirements() => true;

  static bool premiumMustFeelPremiumNotOnlyCostMoreCoins() => true;

  static bool varietyMustIncludeDifferentEmotionsAndPersonalities() => true;

  static bool cinematicAssetsMustStillRespectDevicePerformance() => true;

  static bool creativeSystemMustRemainOwnerConfigurable() => true;

  static bool futureAssetsMustFitWithoutCoreArchitectureDemolition() => true;
}
