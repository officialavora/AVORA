enum AvoraOwnerPolicyProgramKind {
  hostSalary,
  csWeekly,
  familyRankReward,
  agencyRankReward,
  custom,
}

enum AvoraOwnerPolicyCycle {
  daily,
  weekly,
  monthly,
  seasonal,
  custom,
}

class AvoraEditableRewardTier {
  AvoraEditableRewardTier({
    required this.tierId,
    required this.level,
    required this.displayName,
    required this.targetMetricUnits,
    required this.rewardComponents,
    this.timeRequirementEnabled = false,
    this.requiredValidDays = 0,
    this.requiredMinutesPerValidDay = 0,
    this.enabled = true,
  });

  final String tierId;
  final int level;
  final String displayName;

  /// Existing Target Program remains authoritative for actual target counting.
  final int targetMetricUnits;

  /// Flexible owner-editable reward components.
  ///
  /// Example keys:
  /// hostSalaryUsdMinor
  /// agencyCommissionUsdMinor
  /// bdCommissionUsdMinor
  /// customRewardUnits
  final Map<String, int> rewardComponents;

  final bool timeRequirementEnabled;
  final int requiredValidDays;
  final int requiredMinutesPerValidDay;
  final bool enabled;

  bool get valid {
    if (tierId.trim().isEmpty ||
        level <= 0 ||
        displayName.trim().isEmpty ||
        targetMetricUnits < 0 ||
        requiredValidDays < 0 ||
        requiredMinutesPerValidDay < 0) {
      return false;
    }

    for (final entry in rewardComponents.entries) {
      if (entry.key.trim().isEmpty || entry.value < 0) {
        return false;
      }
    }

    return true;
  }

  AvoraEditableRewardTier copyWith({
    String? tierId,
    int? level,
    String? displayName,
    int? targetMetricUnits,
    Map<String, int>? rewardComponents,
    bool? timeRequirementEnabled,
    int? requiredValidDays,
    int? requiredMinutesPerValidDay,
    bool? enabled,
  }) {
    return AvoraEditableRewardTier(
      tierId: tierId ?? this.tierId,
      level: level ?? this.level,
      displayName: displayName ?? this.displayName,
      targetMetricUnits: targetMetricUnits ?? this.targetMetricUnits,
      rewardComponents:
          Map.unmodifiable(rewardComponents ?? this.rewardComponents),
      timeRequirementEnabled:
          timeRequirementEnabled ?? this.timeRequirementEnabled,
      requiredValidDays: requiredValidDays ?? this.requiredValidDays,
      requiredMinutesPerValidDay:
          requiredMinutesPerValidDay ?? this.requiredMinutesPerValidDay,
      enabled: enabled ?? this.enabled,
    );
  }
}

class AvoraOwnerPolicyPreset {
  AvoraOwnerPolicyPreset({
    required this.policyId,
    required this.version,
    required this.displayName,
    required this.kind,
    required this.cycle,
    required this.timeZoneId,
    required this.effectiveFromUtc,
    required this.tiers,
    this.effectiveUntilUtc,
    this.enabled = true,
  });

  final String policyId;
  final int version;
  final String displayName;

  final AvoraOwnerPolicyProgramKind kind;
  final AvoraOwnerPolicyCycle cycle;

  /// Business-time zone, e.g. Asia/Riyadh.
  final String timeZoneId;

  final DateTime effectiveFromUtc;
  final DateTime? effectiveUntilUtc;

  final List<AvoraEditableRewardTier> tiers;

  final bool enabled;

  String get snapshotKey => '$policyId:v$version';

  bool get valid {
    if (policyId.trim().isEmpty ||
        version <= 0 ||
        displayName.trim().isEmpty ||
        timeZoneId.trim().isEmpty ||
        !effectiveFromUtc.isUtc ||
        tiers.isEmpty ||
        tiers.any((tier) => !tier.valid)) {
      return false;
    }

    final until = effectiveUntilUtc;

    if (until != null && (!until.isUtc || !until.isAfter(effectiveFromUtc))) {
      return false;
    }

    final ids = tiers.map((tier) => tier.tierId).toSet();
    final levels = tiers.map((tier) => tier.level).toSet();

    return ids.length == tiers.length && levels.length == tiers.length;
  }
}

class AvoraOwnerPolicyPresetEngine {
  const AvoraOwnerPolicyPresetEngine._();

  /// Owner UI button: "Copy Previous Tier".
  ///
  /// Copies values only. New tier gets a fresh ID/level so history does not
  /// accidentally point to the previous tier.
  static AvoraEditableRewardTier clonePreviousTier({
    required AvoraEditableRewardTier previous,
    required String newTierId,
    required int newLevel,
    String? newDisplayName,
  }) {
    return previous.copyWith(
      tierId: newTierId.trim(),
      level: newLevel,
      displayName: newDisplayName ?? 'Level $newLevel',
    );
  }

  /// Editable EXAMPLE only.
  ///
  /// USD amounts are stored in cents/minor units:
  /// 300 = $3.00
  /// 150 = $1.50
  /// 50  = $0.50
  ///
  /// Owner may replace every value later without rewriting old snapshots.
  static AvoraOwnerPolicyPreset sampleTenLevelHostAgencyBd({
    required DateTime effectiveFromUtc,
  }) {
    AvoraEditableRewardTier tier({
      required int level,
      required int target,
      required int validDays,
      required int hostUsdMinor,
      required int agencyUsdMinor,
      required int bdUsdMinor,
    }) {
      return AvoraEditableRewardTier(
        tierId: 'HOST-TIER-$level',
        level: level,
        displayName: 'Target Level $level',
        targetMetricUnits: target,
        timeRequirementEnabled: true,
        requiredValidDays: validDays,
        requiredMinutesPerValidDay: 120,
        rewardComponents: Map.unmodifiable({
          'hostSalaryUsdMinor': hostUsdMinor,
          'agencyCommissionUsdMinor': agencyUsdMinor,
          'bdCommissionUsdMinor': bdUsdMinor,
        }),
      );
    }

    return AvoraOwnerPolicyPreset(
      policyId: 'HOST-AGENCY-BD-SAMPLE',
      version: 1,
      displayName: 'Host / Agency / BD Sample',
      kind: AvoraOwnerPolicyProgramKind.hostSalary,
      cycle: AvoraOwnerPolicyCycle.monthly,
      timeZoneId: 'Asia/Riyadh',
      effectiveFromUtc: effectiveFromUtc,
      tiers: [
        tier(
          level: 1,
          target: 500000,
          validDays: 15,
          hostUsdMinor: 300,
          agencyUsdMinor: 150,
          bdUsdMinor: 50,
        ),
        tier(
          level: 2,
          target: 1000000,
          validDays: 13,
          hostUsdMinor: 600,
          agencyUsdMinor: 300,
          bdUsdMinor: 100,
        ),
        tier(
          level: 3,
          target: 2000000,
          validDays: 12,
          hostUsdMinor: 1200,
          agencyUsdMinor: 600,
          bdUsdMinor: 200,
        ),
        tier(
          level: 4,
          target: 3000000,
          validDays: 11,
          hostUsdMinor: 1800,
          agencyUsdMinor: 900,
          bdUsdMinor: 300,
        ),
        tier(
          level: 5,
          target: 5000000,
          validDays: 10,
          hostUsdMinor: 3000,
          agencyUsdMinor: 1500,
          bdUsdMinor: 500,
        ),
        tier(
          level: 6,
          target: 7500000,
          validDays: 10,
          hostUsdMinor: 4500,
          agencyUsdMinor: 2250,
          bdUsdMinor: 750,
        ),
        tier(
          level: 7,
          target: 10000000,
          validDays: 9,
          hostUsdMinor: 6000,
          agencyUsdMinor: 3000,
          bdUsdMinor: 1000,
        ),
        tier(
          level: 8,
          target: 15000000,
          validDays: 9,
          hostUsdMinor: 9000,
          agencyUsdMinor: 4500,
          bdUsdMinor: 1500,
        ),
        tier(
          level: 9,
          target: 20000000,
          validDays: 8,
          hostUsdMinor: 12000,
          agencyUsdMinor: 6000,
          bdUsdMinor: 2000,
        ),
        tier(
          level: 10,
          target: 30000000,
          validDays: 8,
          hostUsdMinor: 18000,
          agencyUsdMinor: 9000,
          bdUsdMinor: 3000,
        ),
      ],
    );
  }

  static bool clientCanPublishFinancialPolicyDirectly() => false;

  static bool historicalPolicySnapshotsCanBeRewritten() => false;

  static bool ownerCanEditFuturePolicyVersions() => true;

  static bool policyChangeControlMustBeUsedForRunningPolicy() => true;
}

class AvoraCsWeeklyQualificationPolicy {
  const AvoraCsWeeklyQualificationPolicy({
    required this.policyId,
    required this.version,
    required this.minimumVerifiedInvites,
    required this.requiredOfficialRoomValidDays,
    required this.requiredMinutesPerValidDay,
    required this.rewardReferenceCurrency,
    required this.rewardReferenceFiatMinor,
    required this.rewardValueType,
    required this.destinationKey,
    required this.settlementAdapterKey,
    this.enabled = true,
  });

  final String policyId;
  final int version;

  /// Only successfully verified invited users count.
  final int minimumVerifiedInvites;

  /// Existing Room Activity Time engine supplies this count.
  final int requiredOfficialRoomValidDays;

  /// Example: 120 = 2 hours.
  final int requiredMinutesPerValidDay;

  /// Reference amount only. Actual Coin conversion is done downstream using
  /// the authoritative historical pricing/rate snapshot.
  final String rewardReferenceCurrency;
  final int rewardReferenceFiatMinor;

  final String rewardValueType;
  final String destinationKey;
  final String settlementAdapterKey;

  final bool enabled;

  String get snapshotKey => '$policyId:v$version';

  bool get valid =>
      policyId.trim().isNotEmpty &&
      version > 0 &&
      minimumVerifiedInvites >= 0 &&
      requiredOfficialRoomValidDays >= 0 &&
      requiredMinutesPerValidDay >= 0 &&
      rewardReferenceCurrency.trim().isNotEmpty &&
      rewardReferenceFiatMinor >= 0 &&
      rewardValueType.trim().isNotEmpty &&
      destinationKey.trim().isNotEmpty &&
      settlementAdapterKey.trim().isNotEmpty;
}

enum AvoraCsWeeklyQualificationDenyReason {
  none,
  invalidPolicy,
  beneficiaryNotVerified,
  verifiedInviteRequirementNotMet,
  officialRoomTimeRequirementNotMet,
}

class AvoraCsWeeklyQualificationResult {
  const AvoraCsWeeklyQualificationResult({
    required this.eligible,
    required this.reason,
    required this.policySnapshotKey,
    required this.verifiedInviteCount,
    required this.validOfficialRoomDays,
  });

  final bool eligible;
  final AvoraCsWeeklyQualificationDenyReason reason;
  final String policySnapshotKey;

  final int verifiedInviteCount;
  final int validOfficialRoomDays;
}

class AvoraCsWeeklyQualificationEngine {
  const AvoraCsWeeklyQualificationEngine._();

  /// Input counts must already come from the authoritative Invite and
  /// Room Activity engines.
  static AvoraCsWeeklyQualificationResult evaluate({
    required AvoraCsWeeklyQualificationPolicy policy,
    required bool beneficiaryVerified,
    required int verifiedInviteCount,
    required int validOfficialRoomDaysMeetingRequiredMinutes,
  }) {
    AvoraCsWeeklyQualificationResult result(
      bool eligible,
      AvoraCsWeeklyQualificationDenyReason reason,
    ) {
      return AvoraCsWeeklyQualificationResult(
        eligible: eligible,
        reason: reason,
        policySnapshotKey: policy.snapshotKey,
        verifiedInviteCount: verifiedInviteCount,
        validOfficialRoomDays: validOfficialRoomDaysMeetingRequiredMinutes,
      );
    }

    if (!policy.valid ||
        !policy.enabled ||
        verifiedInviteCount < 0 ||
        validOfficialRoomDaysMeetingRequiredMinutes < 0) {
      return result(
        false,
        AvoraCsWeeklyQualificationDenyReason.invalidPolicy,
      );
    }

    if (!beneficiaryVerified) {
      return result(
        false,
        AvoraCsWeeklyQualificationDenyReason.beneficiaryNotVerified,
      );
    }

    if (verifiedInviteCount < policy.minimumVerifiedInvites) {
      return result(
        false,
        AvoraCsWeeklyQualificationDenyReason.verifiedInviteRequirementNotMet,
      );
    }

    if (validOfficialRoomDaysMeetingRequiredMinutes <
        policy.requiredOfficialRoomValidDays) {
      return result(
        false,
        AvoraCsWeeklyQualificationDenyReason.officialRoomTimeRequirementNotMet,
      );
    }

    return result(
      true,
      AvoraCsWeeklyQualificationDenyReason.none,
    );
  }

  static AvoraCsWeeklyQualificationPolicy samplePolicy() {
    return const AvoraCsWeeklyQualificationPolicy(
      policyId: 'CS-WEEKLY-SAMPLE',
      version: 1,
      minimumVerifiedInvites: 3,
      requiredOfficialRoomValidDays: 7,
      requiredMinutesPerValidDay: 120,
      rewardReferenceCurrency: 'USD',
      rewardReferenceFiatMinor: 500,
      rewardValueType: 'salaryCoinEquivalent',
      destinationKey: 'user_coin_wallet',
      settlementAdapterKey: 'salary',
    );
  }

  static bool genericInviteEngineRemainsAuthoritative() => true;

  static bool roomActivityEngineRemainsAuthoritative() => true;

  static bool unverifiedInviteCanCount() => false;

  static bool directlyCreditsWeeklyReward() => false;
}

class AvoraLeaderboardRewardBand {
  const AvoraLeaderboardRewardBand({
    required this.bandId,
    required this.fromRank,
    required this.toRank,
    required this.rewardBasisPoints,
    this.fixedRewardUnits = 0,
  });

  final String bandId;

  /// Inclusive rank range.
  final int fromRank;
  final int toRank;

  /// Example: 1000 = 10%.
  final int rewardBasisPoints;

  /// Optional fixed reward alternative/addition configured by Owner.
  final int fixedRewardUnits;

  bool get valid =>
      bandId.trim().isNotEmpty &&
      fromRank > 0 &&
      toRank >= fromRank &&
      rewardBasisPoints >= 0 &&
      rewardBasisPoints <= 10000 &&
      fixedRewardUnits >= 0;
}

enum AvoraLeaderboardRewardProgramKind {
  family,
  agency,
}

class AvoraLeaderboardRewardPolicy {
  const AvoraLeaderboardRewardPolicy({
    required this.policyId,
    required this.version,
    required this.kind,
    required this.rewardValueType,
    required this.destinationKey,
    required this.settlementAdapterKey,
    required this.bands,
    this.enabled = true,
  });

  final String policyId;
  final int version;

  final AvoraLeaderboardRewardProgramKind kind;

  final String rewardValueType;
  final String destinationKey;
  final String settlementAdapterKey;

  final List<AvoraLeaderboardRewardBand> bands;

  final bool enabled;

  String get snapshotKey => '$policyId:v$version';

  bool get valid =>
      policyId.trim().isNotEmpty &&
      version > 0 &&
      rewardValueType.trim().isNotEmpty &&
      destinationKey.trim().isNotEmpty &&
      settlementAdapterKey.trim().isNotEmpty &&
      bands.isNotEmpty &&
      bands.every((band) => band.valid);
}

class AvoraLeaderboardRewardDecision {
  const AvoraLeaderboardRewardDecision({
    required this.eligible,
    required this.rank,
    required this.policySnapshotKey,
    this.band,
  });

  final bool eligible;
  final int rank;
  final String policySnapshotKey;
  final AvoraLeaderboardRewardBand? band;
}

class AvoraLeaderboardRewardEngine {
  const AvoraLeaderboardRewardEngine._();

  /// Rank must come from existing AvoraLeaderboardEngine.
  static AvoraLeaderboardRewardDecision evaluate({
    required AvoraLeaderboardRewardPolicy policy,
    required int authoritativeRank,
    required bool beneficiaryVerified,
  }) {
    if (!policy.valid ||
        !policy.enabled ||
        !beneficiaryVerified ||
        authoritativeRank <= 0) {
      return AvoraLeaderboardRewardDecision(
        eligible: false,
        rank: authoritativeRank,
        policySnapshotKey: policy.snapshotKey,
      );
    }

    for (final band in policy.bands) {
      if (authoritativeRank >= band.fromRank &&
          authoritativeRank <= band.toRank) {
        return AvoraLeaderboardRewardDecision(
          eligible: true,
          rank: authoritativeRank,
          policySnapshotKey: policy.snapshotKey,
          band: band,
        );
      }
    }

    return AvoraLeaderboardRewardDecision(
      eligible: false,
      rank: authoritativeRank,
      policySnapshotKey: policy.snapshotKey,
    );
  }

  static AvoraLeaderboardRewardPolicy sampleFamilyPolicy() {
    return const AvoraLeaderboardRewardPolicy(
      policyId: 'FAMILY-RANK-SAMPLE',
      version: 1,
      kind: AvoraLeaderboardRewardProgramKind.family,
      rewardValueType: 'percentageReward',
      destinationKey: 'family_reward_destination',
      settlementAdapterKey: 'leaderboard_reward',
      bands: [
        AvoraLeaderboardRewardBand(
          bandId: 'TOP-3',
          fromRank: 1,
          toRank: 3,
          rewardBasisPoints: 1000,
        ),
        AvoraLeaderboardRewardBand(
          bandId: 'TOP-5',
          fromRank: 4,
          toRank: 5,
          rewardBasisPoints: 500,
        ),
        AvoraLeaderboardRewardBand(
          bandId: 'TOP-10',
          fromRank: 6,
          toRank: 10,
          rewardBasisPoints: 200,
        ),
      ],
    );
  }

  static AvoraLeaderboardRewardPolicy sampleAgencyPolicy() {
    return const AvoraLeaderboardRewardPolicy(
      policyId: 'AGENCY-RANK-SAMPLE',
      version: 1,
      kind: AvoraLeaderboardRewardProgramKind.agency,
      rewardValueType: 'percentageReward',
      destinationKey: 'agency_reward_destination',
      settlementAdapterKey: 'leaderboard_reward',
      bands: [
        AvoraLeaderboardRewardBand(
          bandId: 'TOP-3',
          fromRank: 1,
          toRank: 3,
          rewardBasisPoints: 1000,
        ),
        AvoraLeaderboardRewardBand(
          bandId: 'TOP-5',
          fromRank: 4,
          toRank: 5,
          rewardBasisPoints: 500,
        ),
        AvoraLeaderboardRewardBand(
          bandId: 'TOP-10',
          fromRank: 6,
          toRank: 10,
          rewardBasisPoints: 200,
        ),
      ],
    );
  }

  static bool existingLeaderboardEngineRemainsAuthoritative() => true;

  static bool unverifiedBeneficiaryCanReceiveRankReward() => false;

  static bool directlyMutatesRewardLedger() => false;

  static bool universalAutoSettlementRequired() => true;
}
