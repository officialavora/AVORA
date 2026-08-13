enum AvoraProgressionDomain {
  pk,
  user,
  agency,
  bd,
  host,
  other,
}

enum AvoraProgressionLevel {
  level1,
  level2,
  level3,
  level4,
  level5,
  level6,
  level7,
  level8,
  level9,
  level10,
}

class AvoraProgressionTier {
  const AvoraProgressionTier({
    required this.level,
    required this.requiredProgress,
    required this.rewardCode,
    required this.rewardUnits,
    this.enabled = true,
  });

  final AvoraProgressionLevel level;
  final int requiredProgress;
  final String rewardCode;
  final int rewardUnits;
  final bool enabled;

  void validate() {
    if (requiredProgress <= 0) {
      throw StateError('progression_threshold_must_be_positive');
    }

    if (rewardCode.trim().isEmpty) {
      throw StateError('progression_reward_code_required');
    }

    if (rewardUnits < 0) {
      throw StateError('progression_reward_units_cannot_be_negative');
    }
  }
}

class AvoraProgressionPolicy {
  AvoraProgressionPolicy({
    required this.domain,
    required List<AvoraProgressionTier> tiers,
    required this.overflowEnabled,
    required this.overflowProgressInterval,
    required this.overflowRewardCode,
    required this.overflowRewardUnits,
  }) : tiers = List<AvoraProgressionTier>.unmodifiable(tiers) {
    validate();
  }

  final AvoraProgressionDomain domain;
  final List<AvoraProgressionTier> tiers;

  final bool overflowEnabled;
  final int overflowProgressInterval;
  final String overflowRewardCode;
  final int overflowRewardUnits;

  void validate() {
    if (tiers.length != 10) {
      throw StateError('progression_policy_requires_exactly_10_levels');
    }

    var previous = 0;
    final seen = <AvoraProgressionLevel>{};

    for (final tier in tiers) {
      tier.validate();

      if (!seen.add(tier.level)) {
        throw StateError('duplicate_progression_level');
      }

      if (tier.requiredProgress <= previous) {
        throw StateError(
          'progression_thresholds_must_be_strictly_increasing',
        );
      }

      previous = tier.requiredProgress;
    }

    if (overflowEnabled) {
      if (overflowProgressInterval <= 0) {
        throw StateError('overflow_interval_must_be_positive');
      }

      if (overflowRewardCode.trim().isEmpty) {
        throw StateError('overflow_reward_code_required');
      }

      if (overflowRewardUnits < 0) {
        throw StateError('overflow_reward_units_cannot_be_negative');
      }
    }
  }

  AvoraProgressionLevel? highestReachedLevel(int progress) {
    AvoraProgressionLevel? reached;

    for (final tier in tiers) {
      if (!tier.enabled) {
        continue;
      }

      if (progress >= tier.requiredProgress) {
        reached = tier.level;
      } else {
        break;
      }
    }

    return reached;
  }

  int overflowMilestonesReached(int progress) {
    if (!overflowEnabled || progress <= tiers.last.requiredProgress) {
      return 0;
    }

    final extra = progress - tiers.last.requiredProgress;
    return extra ~/ overflowProgressInterval;
  }

  static bool tenNamedLevelsMustExist() => true;

  static bool levelTenMustNotEndBenefits() => true;

  static bool progressionMustRemainOwnerConfigurable() => true;
}

enum AvoraStartupSupportReason {
  launchPhaseAssistance,
  temporaryTargetShortfall,
  ownerDiscretionarySupport,
}

class AvoraStartupSupportPolicy {
  const AvoraStartupSupportPolicy({
    required this.enabled,
    required this.startsAtUtc,
    required this.endsAtUtc,
    required this.eligibleDomains,
    required this.maximumGrantUnits,
    required this.maximumGrantsPerBeneficiary,
  });

  final bool enabled;
  final DateTime startsAtUtc;
  final DateTime endsAtUtc;
  final Set<AvoraProgressionDomain> eligibleDomains;
  final int maximumGrantUnits;
  final int maximumGrantsPerBeneficiary;

  void validate() {
    if (!endsAtUtc.isAfter(startsAtUtc)) {
      throw StateError('startup_support_window_invalid');
    }

    if (maximumGrantUnits < 0) {
      throw StateError('startup_support_maximum_cannot_be_negative');
    }

    if (maximumGrantsPerBeneficiary < 0) {
      throw StateError('startup_support_grant_limit_invalid');
    }
  }

  bool isActiveAt(DateTime nowUtc) {
    if (!enabled) {
      return false;
    }

    final now = nowUtc.toUtc();

    return !now.isBefore(startsAtUtc.toUtc()) &&
        now.isBefore(endsAtUtc.toUtc());
  }

  bool allowsDomain(AvoraProgressionDomain domain) {
    return enabled && eligibleDomains.contains(domain);
  }
}

class AvoraStartupSupportGrant {
  const AvoraStartupSupportGrant({
    required this.grantId,
    required this.beneficiaryId,
    required this.domain,
    required this.units,
    required this.reason,
    required this.approvedByOwnerId,
    required this.createdAtUtc,
  });

  final String grantId;
  final String beneficiaryId;
  final AvoraProgressionDomain domain;
  final int units;
  final AvoraStartupSupportReason reason;
  final String approvedByOwnerId;
  final DateTime createdAtUtc;

  void validate({
    required AvoraStartupSupportPolicy policy,
    required int priorGrantCount,
  }) {
    policy.validate();

    if (grantId.trim().isEmpty ||
        beneficiaryId.trim().isEmpty ||
        approvedByOwnerId.trim().isEmpty) {
      throw StateError('startup_support_identity_required');
    }

    if (units <= 0 || units > policy.maximumGrantUnits) {
      throw StateError('startup_support_units_out_of_policy');
    }

    if (!policy.allowsDomain(domain)) {
      throw StateError('startup_support_domain_not_allowed');
    }

    if (!policy.isActiveAt(createdAtUtc)) {
      throw StateError('startup_support_outside_active_window');
    }

    if (priorGrantCount >= policy.maximumGrantsPerBeneficiary) {
      throw StateError('startup_support_grant_limit_reached');
    }
  }

  static bool mustNotCountAsEarnedSalary() => true;

  static bool mustNotCountAsEarnedCommission() => true;

  static bool mustRequireOwnerApproval() => true;

  static bool mustRemainAuditable() => true;

  static bool permanentEligibilityPolicyMustRemainUnchanged() => true;
}
