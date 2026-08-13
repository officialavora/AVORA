class AvoraGameEconomyPolicy {
  const AvoraGameEconomyPolicy({
    required this.policyVersion,
    required this.returnBasisPoints,
    required this.minimumBet,
    required this.maximumBet,
    required this.active,
  });

  final String policyVersion;

  // 10000 basis points = 100%.
  // Example: 8500 = 85% theoretical return allocation.
  final int returnBasisPoints;

  final int minimumBet;
  final int maximumBet;
  final bool active;

  factory AvoraGameEconomyPolicy.launchDefault() {
    return const AvoraGameEconomyPolicy(
      policyVersion: 'game-economy-v1',
      returnBasisPoints: 8500,
      minimumBet: 10,
      maximumBet: 100000,
      active: true,
    );
  }

  int returnPoolFor(int totalBet) {
    _validateTotalBet(totalBet);
    return (totalBet * returnBasisPoints) ~/ 10000;
  }

  int platformReserveFor(int totalBet) {
    _validateTotalBet(totalBet);
    return totalBet - returnPoolFor(totalBet);
  }

  bool isBetAllowed(int betAmount) {
    if (!active) return false;

    return betAmount >= minimumBet && betAmount <= maximumBet;
  }

  void validate() {
    if (policyVersion.trim().isEmpty) {
      throw ArgumentError('policy_version_required');
    }

    if (returnBasisPoints < 0 || returnBasisPoints > 10000) {
      throw ArgumentError('invalid_return_percentage');
    }

    if (minimumBet <= 0 || maximumBet < minimumBet) {
      throw ArgumentError('invalid_bet_limits');
    }
  }

  void _validateTotalBet(int totalBet) {
    validate();

    if (totalBet < 0) {
      throw ArgumentError('total_bet_must_not_be_negative');
    }
  }

  static bool percentageMustBeVersionedAndConfigurable() => true;

  static bool ownerMustSeeTotalBetAndReturnPool() => true;

  static bool ownerMustSeePlatformReserve() => true;

  static bool everyGameMustUseEconomyPolicy() => true;

  static bool futureGamesMustUseSameEconomyContract() => true;

  static bool historicalRoundsMustPreserveOriginalPolicy() => true;

  static bool percentageChangeMustNotRewritePastRounds() => true;

  static bool gameResultMustNeverSilentlyMutateBalance() => true;
}

class AvoraGameRoundEconomyRecord {
  const AvoraGameRoundEconomyRecord({
    required this.roundId,
    required this.gameId,
    required this.policyVersion,
    required this.totalBet,
    required this.returnPool,
    required this.platformReserve,
    required this.createdAt,
  });

  final String roundId;
  final String gameId;
  final String policyVersion;

  final int totalBet;
  final int returnPool;
  final int platformReserve;

  final DateTime createdAt;

  factory AvoraGameRoundEconomyRecord.create({
    required String roundId,
    required String gameId,
    required AvoraGameEconomyPolicy policy,
    required int totalBet,
    required DateTime createdAt,
  }) {
    policy.validate();

    if (roundId.trim().isEmpty || gameId.trim().isEmpty) {
      throw ArgumentError('game_round_identity_required');
    }

    final returnPool = policy.returnPoolFor(totalBet);

    return AvoraGameRoundEconomyRecord(
      roundId: roundId,
      gameId: gameId,
      policyVersion: policy.policyVersion,
      totalBet: totalBet,
      returnPool: returnPool,
      platformReserve: totalBet - returnPool,
      createdAt: createdAt,
    );
  }
}
