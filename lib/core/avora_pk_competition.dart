enum AvoraPkSurface {
  audioPk,
  livePk,
}

enum AvoraPkResult {
  sideAWin,
  sideBWin,
  draw,
  sideAForfeit,
  sideBForfeit,
  cancelled,
}

enum AvoraPkParticipantSide {
  sideA,
  sideB,
}

enum AvoraPkValidityDenyReason {
  none,
  notCompleted,
  durationTooShort,
  unverifiedParticipant,
  emptyTeam,
  sameUserOnBothSides,
  linkedAccountAbuse,
  repeatedOpponentFarming,
  collusionSuspected,
  circularGifting,
  reversedOrRefundedScore,
  invalidEconomicEvents,
  duplicateSessionAbuse,
  policyExcluded,
  moderationInvalidated,
}

enum AvoraPkRewardKind {
  pkPoints,
  promoCoins,
  badge,
  frame,
  eventToken,
  cosmetic,
  withdrawableReward,
}

class AvoraPkMatchRecord {
  final String matchId;

  final AvoraPkSurface surface;

  final Set<String> sideAAvoraIds;
  final Set<String> sideBAvoraIds;

  final DateTime startedAt;
  final DateTime endedAt;

  final AvoraPkResult result;

  /// Server-authoritative score. May be derived from eligible gifting
  /// or another event/game scoring rule.
  final int sideAScoreUnits;
  final int sideBScoreUnits;

  final bool completed;

  final bool allParticipantsVerified;

  final bool linkedAccountAbuse;
  final bool repeatedOpponentFarming;
  final bool collusionSuspected;
  final bool circularGifting;
  final bool reversedOrRefundedScore;
  final bool invalidEconomicEvents;
  final bool duplicateSessionAbuse;
  final bool policyExcluded;
  final bool moderationInvalidated;

  const AvoraPkMatchRecord({
    required this.matchId,
    required this.surface,
    required this.sideAAvoraIds,
    required this.sideBAvoraIds,
    required this.startedAt,
    required this.endedAt,
    required this.result,
    required this.sideAScoreUnits,
    required this.sideBScoreUnits,
    required this.completed,
    required this.allParticipantsVerified,
    this.linkedAccountAbuse = false,
    this.repeatedOpponentFarming = false,
    this.collusionSuspected = false,
    this.circularGifting = false,
    this.reversedOrRefundedScore = false,
    this.invalidEconomicEvents = false,
    this.duplicateSessionAbuse = false,
    this.policyExcluded = false,
    this.moderationInvalidated = false,
  })  : assert(sideAScoreUnits >= 0),
        assert(sideBScoreUnits >= 0);

  Duration get duration => endedAt.difference(startedAt);

  bool containsUser(String avoraId) {
    return sideAAvoraIds.contains(avoraId) || sideBAvoraIds.contains(avoraId);
  }

  AvoraPkParticipantSide? sideFor(String avoraId) {
    if (sideAAvoraIds.contains(avoraId)) {
      return AvoraPkParticipantSide.sideA;
    }

    if (sideBAvoraIds.contains(avoraId)) {
      return AvoraPkParticipantSide.sideB;
    }

    return null;
  }
}

class AvoraPkCompetitionPolicy {
  final String id;

  final Duration minimumValidMatchDuration;

  final bool requireVerifiedParticipants;

  /// Net PK-point deltas.
  final int winPointDelta;
  final int lossPointDelta;
  final int drawPointDelta;
  final int forfeitPointDelta;

  /// Optional floor/cap for accumulated PK points.
  final int minimumPkPoints;
  final int? maximumPkPoints;

  const AvoraPkCompetitionPolicy({
    required this.id,
    this.minimumValidMatchDuration = const Duration(seconds: 30),
    this.requireVerifiedParticipants = true,
    this.winPointDelta = 3,
    this.lossPointDelta = 0,
    this.drawPointDelta = 1,
    this.forfeitPointDelta = -2,
    this.minimumPkPoints = 0,
    this.maximumPkPoints,
  }) : assert(
          maximumPkPoints == null || maximumPkPoints >= minimumPkPoints,
        );
}

class AvoraPkValidityDecision {
  final bool validForCompetition;

  final AvoraPkValidityDenyReason reason;

  const AvoraPkValidityDecision({
    required this.validForCompetition,
    required this.reason,
  });
}

class AvoraPkUserMatchOutcome {
  final String userAvoraId;

  final bool valid;

  final bool won;
  final bool lost;
  final bool drew;
  final bool forfeited;

  final int pointDelta;

  const AvoraPkUserMatchOutcome({
    required this.userAvoraId,
    required this.valid,
    required this.won,
    required this.lost,
    required this.drew,
    required this.forfeited,
    required this.pointDelta,
  });
}

class AvoraPkPeriodStats {
  final String userAvoraId;

  final int validMatches;
  final int validWins;
  final int validLosses;
  final int validDraws;
  final int validForfeits;

  final int pointsEarned;
  final int pointsDeducted;
  final int netPointDelta;

  final int currentWinStreak;
  final int bestWinStreak;

  const AvoraPkPeriodStats({
    required this.userAvoraId,
    required this.validMatches,
    required this.validWins,
    required this.validLosses,
    required this.validDraws,
    required this.validForfeits,
    required this.pointsEarned,
    required this.pointsDeducted,
    required this.netPointDelta,
    required this.currentWinStreak,
    required this.bestWinStreak,
  });
}

class AvoraPkRewardTier {
  final String id;

  /// Configurable daily/weekly/monthly target.
  final int minimumValidWins;

  /// Optional point requirement.
  final int minimumNetPkPoints;

  /// Optional external target requirement, for example eligible gifting.
  final int minimumEligibleTargetUnits;

  final AvoraPkRewardKind rewardKind;

  final int rewardUnits;

  const AvoraPkRewardTier({
    required this.id,
    required this.minimumValidWins,
    required this.minimumNetPkPoints,
    required this.minimumEligibleTargetUnits,
    required this.rewardKind,
    required this.rewardUnits,
  })  : assert(minimumValidWins >= 0),
        assert(minimumEligibleTargetUnits >= 0),
        assert(rewardUnits >= 0);
}

class AvoraPkRewardProgram {
  final String id;

  final List<AvoraPkRewardTier> tiers;

  /// Withdrawable reward requires explicit country/compliance permission.
  final bool allowWithdrawableRewards;

  const AvoraPkRewardProgram({
    required this.id,
    required this.tiers,
    this.allowWithdrawableRewards = false,
  });
}

class AvoraPkRewardQualification {
  final List<AvoraPkRewardTier> reachedTiers;

  const AvoraPkRewardQualification({
    required this.reachedTiers,
  });
}

class AvoraPkPointBalanceResult {
  final int beforePoints;
  final int requestedDelta;
  final int appliedDelta;
  final int afterPoints;

  const AvoraPkPointBalanceResult({
    required this.beforePoints,
    required this.requestedDelta,
    required this.appliedDelta,
    required this.afterPoints,
  });
}

class AvoraPkCompetitionEngine {
  const AvoraPkCompetitionEngine._();

  static AvoraPkValidityDecision validateMatch({
    required AvoraPkMatchRecord match,
    required AvoraPkCompetitionPolicy policy,
  }) {
    if (!match.completed || match.result == AvoraPkResult.cancelled) {
      return const AvoraPkValidityDecision(
        validForCompetition: false,
        reason: AvoraPkValidityDenyReason.notCompleted,
      );
    }

    if (match.sideAAvoraIds.isEmpty || match.sideBAvoraIds.isEmpty) {
      return const AvoraPkValidityDecision(
        validForCompetition: false,
        reason: AvoraPkValidityDenyReason.emptyTeam,
      );
    }

    if (match.sideAAvoraIds.intersection(match.sideBAvoraIds).isNotEmpty) {
      return const AvoraPkValidityDecision(
        validForCompetition: false,
        reason: AvoraPkValidityDenyReason.sameUserOnBothSides,
      );
    }

    if (match.duration < policy.minimumValidMatchDuration) {
      return const AvoraPkValidityDecision(
        validForCompetition: false,
        reason: AvoraPkValidityDenyReason.durationTooShort,
      );
    }

    if (policy.requireVerifiedParticipants && !match.allParticipantsVerified) {
      return const AvoraPkValidityDecision(
        validForCompetition: false,
        reason: AvoraPkValidityDenyReason.unverifiedParticipant,
      );
    }

    if (match.linkedAccountAbuse) {
      return const AvoraPkValidityDecision(
        validForCompetition: false,
        reason: AvoraPkValidityDenyReason.linkedAccountAbuse,
      );
    }

    if (match.repeatedOpponentFarming) {
      return const AvoraPkValidityDecision(
        validForCompetition: false,
        reason: AvoraPkValidityDenyReason.repeatedOpponentFarming,
      );
    }

    if (match.collusionSuspected) {
      return const AvoraPkValidityDecision(
        validForCompetition: false,
        reason: AvoraPkValidityDenyReason.collusionSuspected,
      );
    }

    if (match.circularGifting) {
      return const AvoraPkValidityDecision(
        validForCompetition: false,
        reason: AvoraPkValidityDenyReason.circularGifting,
      );
    }

    if (match.reversedOrRefundedScore) {
      return const AvoraPkValidityDecision(
        validForCompetition: false,
        reason: AvoraPkValidityDenyReason.reversedOrRefundedScore,
      );
    }

    if (match.invalidEconomicEvents) {
      return const AvoraPkValidityDecision(
        validForCompetition: false,
        reason: AvoraPkValidityDenyReason.invalidEconomicEvents,
      );
    }

    if (match.duplicateSessionAbuse) {
      return const AvoraPkValidityDecision(
        validForCompetition: false,
        reason: AvoraPkValidityDenyReason.duplicateSessionAbuse,
      );
    }

    if (match.policyExcluded) {
      return const AvoraPkValidityDecision(
        validForCompetition: false,
        reason: AvoraPkValidityDenyReason.policyExcluded,
      );
    }

    if (match.moderationInvalidated) {
      return const AvoraPkValidityDecision(
        validForCompetition: false,
        reason: AvoraPkValidityDenyReason.moderationInvalidated,
      );
    }

    return const AvoraPkValidityDecision(
      validForCompetition: true,
      reason: AvoraPkValidityDenyReason.none,
    );
  }

  static AvoraPkUserMatchOutcome outcomeForUser({
    required String userAvoraId,
    required AvoraPkMatchRecord match,
    required AvoraPkCompetitionPolicy policy,
  }) {
    final validation = validateMatch(
      match: match,
      policy: policy,
    );

    final side = match.sideFor(userAvoraId);

    if (!validation.validForCompetition || side == null) {
      return AvoraPkUserMatchOutcome(
        userAvoraId: userAvoraId,
        valid: false,
        won: false,
        lost: false,
        drew: false,
        forfeited: false,
        pointDelta: 0,
      );
    }

    var won = false;
    var lost = false;
    var drew = false;
    var forfeited = false;
    var delta = 0;

    switch (match.result) {
      case AvoraPkResult.sideAWin:
        won = side == AvoraPkParticipantSide.sideA;
        lost = !won;
        delta = won ? policy.winPointDelta : policy.lossPointDelta;

      case AvoraPkResult.sideBWin:
        won = side == AvoraPkParticipantSide.sideB;
        lost = !won;
        delta = won ? policy.winPointDelta : policy.lossPointDelta;

      case AvoraPkResult.draw:
        drew = true;
        delta = policy.drawPointDelta;

      case AvoraPkResult.sideAForfeit:
        if (side == AvoraPkParticipantSide.sideA) {
          forfeited = true;
          lost = true;
          delta = policy.forfeitPointDelta;
        } else {
          won = true;
          delta = policy.winPointDelta;
        }

      case AvoraPkResult.sideBForfeit:
        if (side == AvoraPkParticipantSide.sideB) {
          forfeited = true;
          lost = true;
          delta = policy.forfeitPointDelta;
        } else {
          won = true;
          delta = policy.winPointDelta;
        }

      case AvoraPkResult.cancelled:
        break;
    }

    return AvoraPkUserMatchOutcome(
      userAvoraId: userAvoraId,
      valid: true,
      won: won,
      lost: lost,
      drew: drew,
      forfeited: forfeited,
      pointDelta: delta,
    );
  }

  static AvoraPkPeriodStats buildPeriodStats({
    required String userAvoraId,
    required List<AvoraPkMatchRecord> matches,
    required AvoraPkCompetitionPolicy policy,
  }) {
    var validMatches = 0;
    var wins = 0;
    var losses = 0;
    var draws = 0;
    var forfeits = 0;

    var earned = 0;
    var deducted = 0;

    var currentStreak = 0;
    var bestStreak = 0;

    final ordered = matches
        .where((match) => match.containsUser(userAvoraId))
        .toList(growable: false)
      ..sort((a, b) => a.endedAt.compareTo(b.endedAt));

    for (final match in ordered) {
      final outcome = outcomeForUser(
        userAvoraId: userAvoraId,
        match: match,
        policy: policy,
      );

      if (!outcome.valid) {
        continue;
      }

      validMatches++;

      if (outcome.won) {
        wins++;
        currentStreak++;

        if (currentStreak > bestStreak) {
          bestStreak = currentStreak;
        }
      } else {
        currentStreak = 0;
      }

      if (outcome.lost) {
        losses++;
      }

      if (outcome.drew) {
        draws++;
      }

      if (outcome.forfeited) {
        forfeits++;
      }

      if (outcome.pointDelta >= 0) {
        earned += outcome.pointDelta;
      } else {
        deducted += -outcome.pointDelta;
      }
    }

    return AvoraPkPeriodStats(
      userAvoraId: userAvoraId,
      validMatches: validMatches,
      validWins: wins,
      validLosses: losses,
      validDraws: draws,
      validForfeits: forfeits,
      pointsEarned: earned,
      pointsDeducted: deducted,
      netPointDelta: earned - deducted,
      currentWinStreak: currentStreak,
      bestWinStreak: bestStreak,
    );
  }

  static AvoraPkPointBalanceResult applyPointDelta({
    required int currentPoints,
    required int requestedDelta,
    required AvoraPkCompetitionPolicy policy,
  }) {
    if (currentPoints < policy.minimumPkPoints) {
      throw ArgumentError(
        'currentPoints cannot be below configured minimum.',
      );
    }

    var next = currentPoints + requestedDelta;

    if (next < policy.minimumPkPoints) {
      next = policy.minimumPkPoints;
    }

    final max = policy.maximumPkPoints;

    if (max != null && next > max) {
      next = max;
    }

    return AvoraPkPointBalanceResult(
      beforePoints: currentPoints,
      requestedDelta: requestedDelta,
      appliedDelta: next - currentPoints,
      afterPoints: next,
    );
  }

  static AvoraPkRewardQualification qualifyRewards({
    required AvoraPkPeriodStats stats,
    required int eligibleTargetUnits,
    required AvoraPkRewardProgram program,
  }) {
    final reached = <AvoraPkRewardTier>[];

    for (final tier in program.tiers) {
      if (stats.validWins < tier.minimumValidWins) {
        continue;
      }

      if (stats.netPointDelta < tier.minimumNetPkPoints) {
        continue;
      }

      if (eligibleTargetUnits < tier.minimumEligibleTargetUnits) {
        continue;
      }

      if (tier.rewardKind == AvoraPkRewardKind.withdrawableReward &&
          !program.allowWithdrawableRewards) {
        continue;
      }

      reached.add(tier);
    }

    return AvoraPkRewardQualification(
      reachedTiers: List.unmodifiable(reached),
    );
  }

  /// Audio PK and Live-PK share the same competition engine.
  static bool audioAndLivePkUseSameCompetitionRules() {
    return true;
  }

  /// Playing music does not automatically increase PK score.
  static bool mediaPlaybackCountsTowardPkScore() {
    return false;
  }

  /// A started PK is not automatically a valid/rewardable PK.
  static bool everyStartedPkCountsForReward() {
    return false;
  }

  /// Merely repeating the same opponent must not farm rewards.
  static bool repeatedOpponentPatternAutomaticallyEligible() {
    return false;
  }

  /// Safety/moderation enforcement remains separately audited.
  static bool pkPointDeductionReplacesSafetyEnforcement() {
    return false;
  }
}
