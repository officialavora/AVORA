enum AvoraGameEconomyMode {
  none,
  timedSelectionRound,
  skillEntryFee,
  prizePool,
  arcadeSpend,
  custom,
}

enum AvoraGameRoundState {
  scheduled,
  bettingOpen,
  bettingClosed,
  resolving,
  resolved,
  cancelled,
  voided,
}

enum AvoraGameWagerOutcome {
  pending,
  won,
  lost,
  refunded,
  voided,
}

enum AvoraGameBetDenyReason {
  none,
  wrongEconomyMode,
  roundNotOpen,
  bettingWindowClosed,
  optionUnavailable,
  invalidBetUnits,
  belowMinimum,
  aboveMaximum,
  playerRoundLimitExceeded,
  insufficientVirtualCoins,
  identityNotEligible,
  riskBlocked,
  duplicateWagerId,
}

class AvoraGameOptionPolicy {
  final String optionId;
  final String displayName;
  final bool enabled;

  /// Gross payout multiplier.
  /// 10000 bps = 1.00x
  /// 20000 bps = 2.00x
  final int payoutMultiplierBps;

  const AvoraGameOptionPolicy({
    required this.optionId,
    required this.displayName,
    required this.enabled,
    required this.payoutMultiplierBps,
  }) : assert(payoutMultiplierBps >= 0);
}

class AvoraGameEconomyPolicyVersion {
  final String policyVersionId;
  final String gameId;

  final AvoraGameEconomyMode economyMode;

  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;

  final bool enabled;

  /// Example: 30 seconds, but never hardcoded.
  final Duration bettingDuration;

  final int minimumBetUnits;
  final int maximumBetUnits;

  /// Maximum total virtual coins one player may place
  /// in one round.
  final int maximumPlayerUnitsPerRound;

  /// Aggregate policy target.
  /// 9000 bps = theoretical 90% return target.
  final int targetReturnBps;

  /// Example: 1000 bps = 10% platform retention target.
  final int platformRetainBps;

  final List<AvoraGameOptionPolicy> options;

  const AvoraGameEconomyPolicyVersion({
    required this.policyVersionId,
    required this.gameId,
    required this.economyMode,
    required this.effectiveFrom,
    required this.enabled,
    required this.bettingDuration,
    required this.minimumBetUnits,
    required this.maximumBetUnits,
    required this.maximumPlayerUnitsPerRound,
    required this.targetReturnBps,
    required this.platformRetainBps,
    required this.options,
    this.effectiveUntil,
  })  : assert(minimumBetUnits >= 1),
        assert(maximumBetUnits >= minimumBetUnits),
        assert(maximumPlayerUnitsPerRound >= minimumBetUnits),
        assert(targetReturnBps >= 0 && targetReturnBps <= 10000),
        assert(platformRetainBps >= 0 && platformRetainBps <= 10000);

  bool activeAt(DateTime now) {
    if (!enabled || now.isBefore(effectiveFrom)) {
      return false;
    }

    final until = effectiveUntil;

    if (until != null && !now.isBefore(until)) {
      return false;
    }

    return true;
  }

  AvoraGameOptionPolicy? optionById(String optionId) {
    for (final option in options) {
      if (option.optionId == optionId) {
        return option;
      }
    }

    return null;
  }
}

class AvoraGameRound {
  final String roundId;
  final String gameId;

  final String policyVersionId;

  final DateTime scheduledAt;
  final DateTime bettingOpensAt;
  final DateTime bettingClosesAt;

  final AvoraGameRoundState state;

  final Set<String> winningOptionIds;

  final DateTime? resolvedAt;

  const AvoraGameRound({
    required this.roundId,
    required this.gameId,
    required this.policyVersionId,
    required this.scheduledAt,
    required this.bettingOpensAt,
    required this.bettingClosesAt,
    required this.state,
    this.winningOptionIds = const {},
    this.resolvedAt,
  });

  bool bettingOpenAt(DateTime now) {
    return state == AvoraGameRoundState.bettingOpen &&
        !now.isBefore(bettingOpensAt) &&
        now.isBefore(bettingClosesAt);
  }
}

class AvoraGameWager {
  final String wagerId;
  final String roundId;
  final String gameId;

  /// Immutable authoritative AVORA ID.
  final String playerAvoraId;

  final String optionId;

  final int betUnits;

  final DateTime placedAt;

  final String policyVersionId;

  const AvoraGameWager({
    required this.wagerId,
    required this.roundId,
    required this.gameId,
    required this.playerAvoraId,
    required this.optionId,
    required this.betUnits,
    required this.placedAt,
    required this.policyVersionId,
  });
}

class AvoraGameBetDecision {
  final bool allowed;
  final AvoraGameBetDenyReason reason;

  const AvoraGameBetDecision({
    required this.allowed,
    required this.reason,
  });
}

class AvoraGameWagerSettlement {
  final String wagerId;
  final String roundId;
  final String gameId;
  final String playerAvoraId;

  final String optionId;

  final int betUnits;

  /// Gross virtual-coin payout.
  final int payoutUnits;

  /// payoutUnits - betUnits.
  final int netUnits;

  final AvoraGameWagerOutcome outcome;

  final String policyVersionId;

  final DateTime settledAt;

  const AvoraGameWagerSettlement({
    required this.wagerId,
    required this.roundId,
    required this.gameId,
    required this.playerAvoraId,
    required this.optionId,
    required this.betUnits,
    required this.payoutUnits,
    required this.netUnits,
    required this.outcome,
    required this.policyVersionId,
    required this.settledAt,
  });
}

class AvoraGameRoundStatistics {
  final String roundId;
  final String gameId;

  final int selectionCount;
  final int uniquePlayerCount;

  final int totalWageredUnits;
  final int totalPayoutUnits;

  final int retainedUnits;

  /// Actual gross payout / total wager, 0..+
  final int observedReturnBps;

  const AvoraGameRoundStatistics({
    required this.roundId,
    required this.gameId,
    required this.selectionCount,
    required this.uniquePlayerCount,
    required this.totalWageredUnits,
    required this.totalPayoutUnits,
    required this.retainedUnits,
    required this.observedReturnBps,
  });
}

class AvoraGameRankingContribution {
  final String playerAvoraId;

  final int wageredUnits;
  final int payoutUnits;
  final int netWinningUnits;
  final int winCount;

  const AvoraGameRankingContribution({
    required this.playerAvoraId,
    required this.wageredUnits,
    required this.payoutUnits,
    required this.netWinningUnits,
    required this.winCount,
  });
}

class AvoraGameRoundEngine {
  const AvoraGameRoundEngine._();

  static AvoraGameRound createRound({
    required String roundId,
    required AvoraGameEconomyPolicyVersion policy,
    required DateTime bettingOpensAt,
  }) {
    return AvoraGameRound(
      roundId: roundId,
      gameId: policy.gameId,
      policyVersionId: policy.policyVersionId,
      scheduledAt: bettingOpensAt,
      bettingOpensAt: bettingOpensAt,
      bettingClosesAt: bettingOpensAt.add(policy.bettingDuration),
      state: AvoraGameRoundState.scheduled,
    );
  }

  static AvoraGameBetDecision canPlaceBet({
    required AvoraGameEconomyPolicyVersion policy,
    required AvoraGameRound round,
    required String optionId,
    required int requestedBetUnits,
    required int alreadyBetByPlayerInRound,
    required int availableVirtualCoinUnits,
    required bool identityEligible,
    required bool riskBlocked,
    required bool wagerIdAlreadyExists,
    required DateTime now,
  }) {
    if (policy.economyMode != AvoraGameEconomyMode.timedSelectionRound) {
      return const AvoraGameBetDecision(
        allowed: false,
        reason: AvoraGameBetDenyReason.wrongEconomyMode,
      );
    }

    if (round.state != AvoraGameRoundState.bettingOpen) {
      return const AvoraGameBetDecision(
        allowed: false,
        reason: AvoraGameBetDenyReason.roundNotOpen,
      );
    }

    if (!round.bettingOpenAt(now)) {
      return const AvoraGameBetDecision(
        allowed: false,
        reason: AvoraGameBetDenyReason.bettingWindowClosed,
      );
    }

    final option = policy.optionById(optionId);

    if (option == null || !option.enabled) {
      return const AvoraGameBetDecision(
        allowed: false,
        reason: AvoraGameBetDenyReason.optionUnavailable,
      );
    }

    if (requestedBetUnits <= 0) {
      return const AvoraGameBetDecision(
        allowed: false,
        reason: AvoraGameBetDenyReason.invalidBetUnits,
      );
    }

    if (requestedBetUnits < policy.minimumBetUnits) {
      return const AvoraGameBetDecision(
        allowed: false,
        reason: AvoraGameBetDenyReason.belowMinimum,
      );
    }

    if (requestedBetUnits > policy.maximumBetUnits) {
      return const AvoraGameBetDecision(
        allowed: false,
        reason: AvoraGameBetDenyReason.aboveMaximum,
      );
    }

    if (alreadyBetByPlayerInRound + requestedBetUnits >
        policy.maximumPlayerUnitsPerRound) {
      return const AvoraGameBetDecision(
        allowed: false,
        reason: AvoraGameBetDenyReason.playerRoundLimitExceeded,
      );
    }

    if (availableVirtualCoinUnits < requestedBetUnits) {
      return const AvoraGameBetDecision(
        allowed: false,
        reason: AvoraGameBetDenyReason.insufficientVirtualCoins,
      );
    }

    if (!identityEligible) {
      return const AvoraGameBetDecision(
        allowed: false,
        reason: AvoraGameBetDenyReason.identityNotEligible,
      );
    }

    if (riskBlocked) {
      return const AvoraGameBetDecision(
        allowed: false,
        reason: AvoraGameBetDenyReason.riskBlocked,
      );
    }

    if (wagerIdAlreadyExists) {
      return const AvoraGameBetDecision(
        allowed: false,
        reason: AvoraGameBetDenyReason.duplicateWagerId,
      );
    }

    return const AvoraGameBetDecision(
      allowed: true,
      reason: AvoraGameBetDenyReason.none,
    );
  }

  static AvoraGameWagerSettlement settleWager({
    required AvoraGameEconomyPolicyVersion policy,
    required AvoraGameRound round,
    required AvoraGameWager wager,
    required DateTime settledAt,
  }) {
    if (round.state != AvoraGameRoundState.resolved) {
      throw StateError('Round must be resolved before settlement.');
    }

    final option = policy.optionById(wager.optionId);

    if (option == null) {
      throw StateError('Wager option missing from policy version.');
    }

    final won = round.winningOptionIds.contains(wager.optionId);

    final payout =
        won ? (wager.betUnits * option.payoutMultiplierBps) ~/ 10000 : 0;

    return AvoraGameWagerSettlement(
      wagerId: wager.wagerId,
      roundId: wager.roundId,
      gameId: wager.gameId,
      playerAvoraId: wager.playerAvoraId,
      optionId: wager.optionId,
      betUnits: wager.betUnits,
      payoutUnits: payout,
      netUnits: payout - wager.betUnits,
      outcome: won ? AvoraGameWagerOutcome.won : AvoraGameWagerOutcome.lost,
      policyVersionId: wager.policyVersionId,
      settledAt: settledAt,
    );
  }

  static AvoraGameRoundStatistics buildStatistics({
    required AvoraGameRound round,
    required List<AvoraGameWagerSettlement> settlements,
  }) {
    final totalWagered = settlements.fold<int>(
      0,
      (sum, item) => sum + item.betUnits,
    );

    final totalPayout = settlements.fold<int>(
      0,
      (sum, item) => sum + item.payoutUnits,
    );

    final players = settlements.map((item) => item.playerAvoraId).toSet();

    final observedReturnBps =
        totalWagered == 0 ? 0 : (totalPayout * 10000) ~/ totalWagered;

    return AvoraGameRoundStatistics(
      roundId: round.roundId,
      gameId: round.gameId,
      selectionCount: settlements.length,
      uniquePlayerCount: players.length,
      totalWageredUnits: totalWagered,
      totalPayoutUnits: totalPayout,
      retainedUnits: totalWagered - totalPayout,
      observedReturnBps: observedReturnBps,
    );
  }

  static List<AvoraGameRankingContribution> buildRankingContributions(
    List<AvoraGameWagerSettlement> settlements,
  ) {
    final grouped = <String, List<AvoraGameWagerSettlement>>{};

    for (final settlement in settlements) {
      grouped
          .putIfAbsent(
            settlement.playerAvoraId,
            () => [],
          )
          .add(settlement);
    }

    final rows = <AvoraGameRankingContribution>[];

    for (final entry in grouped.entries) {
      final wagered = entry.value.fold<int>(
        0,
        (sum, item) => sum + item.betUnits,
      );

      final payout = entry.value.fold<int>(
        0,
        (sum, item) => sum + item.payoutUnits,
      );

      final wins = entry.value
          .where((item) => item.outcome == AvoraGameWagerOutcome.won)
          .length;

      rows.add(
        AvoraGameRankingContribution(
          playerAvoraId: entry.key,
          wageredUnits: wagered,
          payoutUnits: payout,
          netWinningUnits: payout - wagered,
          winCount: wins,
        ),
      );
    }

    rows.sort((a, b) {
      final byPayout = b.payoutUnits.compareTo(a.payoutUnits);

      if (byPayout != 0) {
        return byPayout;
      }

      final byWins = b.winCount.compareTo(a.winCount);

      if (byWins != 0) {
        return byWins;
      }

      return a.playerAvoraId.compareTo(b.playerAvoraId);
    });

    return List.unmodifiable(rows);
  }

  /// Shared leaderboard engine handles Today/Week/Month/All-Time.
  static bool gameRankingNeedsSeparateTimeBucketEngine() {
    return false;
  }

  /// Top 10/50/etc is configuration, not a fixed engine limit.
  static bool topRankingLimitIsHardcoded() {
    return false;
  }

  /// Virtual coin winnings do not automatically become cash.
  static bool virtualGameWinningAutomaticallyBecomesWithdrawableCash() {
    return false;
  }

  /// A specific player is never secretly chosen to win/lose.
  static bool supportsHiddenPerUserOutcomeManipulation() {
    return false;
  }

  /// Every wager and settlement keeps the policy version used.
  static bool historicalRoundPolicyCanBeRewrittenRetroactively() {
    return false;
  }

  /// Ludo/Carrom/etc do not have to use timed-selection rounds.
  static bool everyGameMustUseThirtySecondBettingRounds() {
    return false;
  }
}
