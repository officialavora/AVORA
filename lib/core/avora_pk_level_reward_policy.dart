// Owner/Admin configurable PK qualification + level reward policy.
//
// Important:
// - A normal PK may still be played with any valid stake/value.
// - Only qualifying wins count toward PK reward levels.
// - Losing a PK never increases qualifying-win progress.
// - Thresholds and rewards are policy/config values, not permanent constants.
// - This layer does not directly credit wallets or mutate authoritative ledgers.

enum AvoraPkRewardLevel {
  level1,
  level2,
  level3,
  level4,
  level5,
}

enum AvoraPkRewardType {
  coins,
  points,
  badge,
  frame,
  entrance,
  custom,
}

class AvoraPkLevelReward {
  const AvoraPkLevelReward({
    required this.level,
    required this.requiredQualifyingWins,
    required this.rewardType,
    required this.rewardAmount,
    required this.rewardCode,
    this.enabled = true,
  });

  final AvoraPkRewardLevel level;

  /// Number of qualifying PK wins needed to reach this level.
  final int requiredQualifyingWins;

  final AvoraPkRewardType rewardType;

  /// Numeric reward quantity when applicable.
  final int rewardAmount;

  /// Stable configurable reward identifier.
  /// Example: pk_level_1_reward
  final String rewardCode;

  final bool enabled;

  void validate() {
    if (requiredQualifyingWins <= 0) {
      throw StateError('pk_level_requires_positive_win_threshold');
    }

    if (rewardAmount < 0) {
      throw StateError('pk_level_reward_amount_cannot_be_negative');
    }

    if (rewardCode.trim().isEmpty) {
      throw StateError('pk_level_reward_code_required');
    }
  }
}

class AvoraPkLevelRewardPolicy {
  AvoraPkLevelRewardPolicy({
    required this.minimumQualifyingPkValue,
    required List<AvoraPkLevelReward> levels,
    this.enabled = true,
  }) : levels = List<AvoraPkLevelReward>.unmodifiable(levels) {
    validate();
  }

  /// Example default: 5,000,000.
  ///
  /// Owner/Admin may change this through future controlled configuration.
  final int minimumQualifyingPkValue;

  final List<AvoraPkLevelReward> levels;
  final bool enabled;

  void validate() {
    if (minimumQualifyingPkValue <= 0) {
      throw StateError('minimum_qualifying_pk_value_must_be_positive');
    }

    if (levels.isEmpty) {
      throw StateError('pk_reward_policy_requires_levels');
    }

    final seenLevels = <AvoraPkRewardLevel>{};
    var previousWins = 0;

    for (final reward in levels) {
      reward.validate();

      if (!seenLevels.add(reward.level)) {
        throw StateError('duplicate_pk_reward_level');
      }

      if (reward.requiredQualifyingWins <= previousWins) {
        throw StateError(
          'pk_reward_levels_must_have_increasing_win_thresholds',
        );
      }

      previousWins = reward.requiredQualifyingWins;
    }
  }

  /// Starting defaults only.
  ///
  /// They remain replaceable by Owner/Admin controlled configuration.
  factory AvoraPkLevelRewardPolicy.defaults() {
    return AvoraPkLevelRewardPolicy(
      minimumQualifyingPkValue: 5000000,
      levels: const <AvoraPkLevelReward>[
        AvoraPkLevelReward(
          level: AvoraPkRewardLevel.level1,
          requiredQualifyingWins: 5,
          rewardType: AvoraPkRewardType.points,
          rewardAmount: 100,
          rewardCode: 'pk_level_1_reward',
        ),
        AvoraPkLevelReward(
          level: AvoraPkRewardLevel.level2,
          requiredQualifyingWins: 10,
          rewardType: AvoraPkRewardType.points,
          rewardAmount: 250,
          rewardCode: 'pk_level_2_reward',
        ),
        AvoraPkLevelReward(
          level: AvoraPkRewardLevel.level3,
          requiredQualifyingWins: 25,
          rewardType: AvoraPkRewardType.points,
          rewardAmount: 750,
          rewardCode: 'pk_level_3_reward',
        ),
        AvoraPkLevelReward(
          level: AvoraPkRewardLevel.level4,
          requiredQualifyingWins: 50,
          rewardType: AvoraPkRewardType.points,
          rewardAmount: 2000,
          rewardCode: 'pk_level_4_reward',
        ),
        AvoraPkLevelReward(
          level: AvoraPkRewardLevel.level5,
          requiredQualifyingWins: 100,
          rewardType: AvoraPkRewardType.points,
          rewardAmount: 5000,
          rewardCode: 'pk_level_5_reward',
        ),
      ],
    );
  }

  bool isQualifyingPkValue(int pkValue) {
    if (!enabled) {
      return false;
    }

    return pkValue >= minimumQualifyingPkValue;
  }

  bool shouldCountWin({
    required int pkValue,
    required bool won,
    required bool validMatch,
    required bool cancelled,
    required bool forfeited,
  }) {
    if (!enabled || !won || !validMatch || cancelled || forfeited) {
      return false;
    }

    return isQualifyingPkValue(pkValue);
  }

  AvoraPkRewardLevel? highestReachedLevel(
    int qualifyingWins,
  ) {
    if (!enabled || qualifyingWins <= 0) {
      return null;
    }

    AvoraPkRewardLevel? reached;

    for (final reward in levels) {
      if (!reward.enabled) {
        continue;
      }

      if (qualifyingWins >= reward.requiredQualifyingWins) {
        reached = reward.level;
      } else {
        break;
      }
    }

    return reached;
  }

  List<AvoraPkLevelReward> newlyReachedRewards({
    required int previousQualifyingWins,
    required int currentQualifyingWins,
  }) {
    if (!enabled || currentQualifyingWins <= previousQualifyingWins) {
      return const <AvoraPkLevelReward>[];
    }

    return List<AvoraPkLevelReward>.unmodifiable(
      levels.where(
        (reward) =>
            reward.enabled &&
            previousQualifyingWins < reward.requiredQualifyingWins &&
            currentQualifyingWins >= reward.requiredQualifyingWins,
      ),
    );
  }

  AvoraPkLevelReward? rewardForLevel(
    AvoraPkRewardLevel level,
  ) {
    for (final reward in levels) {
      if (reward.level == level) {
        return reward;
      }
    }

    return null;
  }

  static bool thresholdsMustRemainConfigurable() => true;

  static bool rewardsMustRemainConfigurable() => true;

  static bool losingPkMustNotIncreaseRewardProgress() => true;

  static bool lowValuePkMayPlayButMustNotCountForReward() => true;

  static bool rewardPolicyMustNotDirectlyCreditWallet() => true;

  static bool ownerMayChangeFutureThresholds() => true;
}

class AvoraPkRewardProgress {
  const AvoraPkRewardProgress({
    required this.qualifyingWins,
    required this.currentLevel,
  });

  final int qualifyingWins;
  final AvoraPkRewardLevel? currentLevel;

  factory AvoraPkRewardProgress.empty() {
    return const AvoraPkRewardProgress(
      qualifyingWins: 0,
      currentLevel: null,
    );
  }

  AvoraPkRewardProgress recordMatch({
    required AvoraPkLevelRewardPolicy policy,
    required int pkValue,
    required bool won,
    required bool validMatch,
    bool cancelled = false,
    bool forfeited = false,
  }) {
    final counts = policy.shouldCountWin(
      pkValue: pkValue,
      won: won,
      validMatch: validMatch,
      cancelled: cancelled,
      forfeited: forfeited,
    );

    if (!counts) {
      return this;
    }

    final nextWins = qualifyingWins + 1;

    return AvoraPkRewardProgress(
      qualifyingWins: nextWins,
      currentLevel: policy.highestReachedLevel(nextWins),
    );
  }
}

enum AvoraPkOverflowRewardMode {
  disabled,
  repeatLastLevelReward,
  fixedMilestoneReward,
}

class AvoraPkOverflowRewardPolicy {
  const AvoraPkOverflowRewardPolicy({
    required this.mode,
    required this.winsPerMilestone,
    required this.rewardType,
    required this.rewardAmount,
    required this.rewardCodePrefix,
  });

  final AvoraPkOverflowRewardMode mode;

  /// Example: after the highest configured level,
  /// every additional 25 qualifying wins may create another reward milestone.
  final int winsPerMilestone;

  final AvoraPkRewardType rewardType;
  final int rewardAmount;
  final String rewardCodePrefix;

  void validate() {
    if (mode != AvoraPkOverflowRewardMode.disabled && winsPerMilestone <= 0) {
      throw StateError('pk_overflow_milestone_must_be_positive');
    }

    if (rewardAmount < 0) {
      throw StateError('pk_overflow_reward_cannot_be_negative');
    }

    if (mode != AvoraPkOverflowRewardMode.disabled &&
        rewardCodePrefix.trim().isEmpty) {
      throw StateError('pk_overflow_reward_code_prefix_required');
    }
  }
}

class AvoraPkOverflowRewardResult {
  const AvoraPkOverflowRewardResult({
    required this.milestoneNumber,
    required this.rewardType,
    required this.rewardAmount,
    required this.rewardCode,
  });

  final int milestoneNumber;
  final AvoraPkRewardType rewardType;
  final int rewardAmount;
  final String rewardCode;
}

extension AvoraPkLevelRewardOverflowExtension on AvoraPkLevelRewardPolicy {
  AvoraPkLevelReward? get highestConfiguredReward {
    if (levels.isEmpty) {
      return null;
    }

    return levels.last;
  }

  List<AvoraPkOverflowRewardResult> newlyReachedOverflowRewards({
    required int previousQualifyingWins,
    required int currentQualifyingWins,
    required AvoraPkOverflowRewardPolicy overflowPolicy,
  }) {
    overflowPolicy.validate();

    if (!enabled ||
        overflowPolicy.mode == AvoraPkOverflowRewardMode.disabled ||
        currentQualifyingWins <= previousQualifyingWins) {
      return const <AvoraPkOverflowRewardResult>[];
    }

    final highest = highestConfiguredReward;
    if (highest == null) {
      return const <AvoraPkOverflowRewardResult>[];
    }

    final topThreshold = highest.requiredQualifyingWins;

    if (currentQualifyingWins <= topThreshold) {
      return const <AvoraPkOverflowRewardResult>[];
    }

    final previousExtraWins = previousQualifyingWins > topThreshold
        ? previousQualifyingWins - topThreshold
        : 0;

    final currentExtraWins = currentQualifyingWins - topThreshold;

    final previousMilestones =
        previousExtraWins ~/ overflowPolicy.winsPerMilestone;

    final currentMilestones =
        currentExtraWins ~/ overflowPolicy.winsPerMilestone;

    if (currentMilestones <= previousMilestones) {
      return const <AvoraPkOverflowRewardResult>[];
    }

    final rewards = <AvoraPkOverflowRewardResult>[];

    for (var milestone = previousMilestones + 1;
        milestone <= currentMilestones;
        milestone++) {
      switch (overflowPolicy.mode) {
        case AvoraPkOverflowRewardMode.disabled:
          break;

        case AvoraPkOverflowRewardMode.repeatLastLevelReward:
          rewards.add(
            AvoraPkOverflowRewardResult(
              milestoneNumber: milestone,
              rewardType: highest.rewardType,
              rewardAmount: highest.rewardAmount,
              rewardCode: '${overflowPolicy.rewardCodePrefix}_$milestone',
            ),
          );
          break;

        case AvoraPkOverflowRewardMode.fixedMilestoneReward:
          rewards.add(
            AvoraPkOverflowRewardResult(
              milestoneNumber: milestone,
              rewardType: overflowPolicy.rewardType,
              rewardAmount: overflowPolicy.rewardAmount,
              rewardCode: '${overflowPolicy.rewardCodePrefix}_$milestone',
            ),
          );
          break;
      }
    }

    return List<AvoraPkOverflowRewardResult>.unmodifiable(rewards);
  }
}
