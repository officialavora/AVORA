import 'avora_game_round_record.dart';

class AvoraGameEconomyTotals {
  const AvoraGameEconomyTotals({
    required this.totalBetCoins,
    required this.totalPayoutCoins,
    required this.platformGrossResult,
    required this.roundCount,
  });

  final int totalBetCoins;
  final int totalPayoutCoins;
  final int platformGrossResult;
  final int roundCount;

  double get actualRtpPercent {
    if (totalBetCoins == 0) {
      return 0;
    }

    return (totalPayoutCoins / totalBetCoins) * 100;
  }
}

class AvoraGameEconomyLedger {
  final Map<String, AvoraGameRoundRecord> _records =
      <String, AvoraGameRoundRecord>{};

  void append(AvoraGameRoundRecord record) {
    if (!record.isValid) {
      throw ArgumentError('invalid_game_round_record');
    }

    if (_records.containsKey(record.roundId)) {
      throw StateError('duplicate_game_round');
    }

    _records[record.roundId] = record;
  }

  AvoraGameRoundRecord? byRoundId(String roundId) {
    return _records[roundId];
  }

  List<AvoraGameRoundRecord> forUser(String avoraId) {
    return List<AvoraGameRoundRecord>.unmodifiable(
      _records.values.where(
        (record) => record.userAvoraId == avoraId,
      ),
    );
  }

  List<AvoraGameRoundRecord> forGame(String gameId) {
    return List<AvoraGameRoundRecord>.unmodifiable(
      _records.values.where(
        (record) => record.gameId == gameId,
      ),
    );
  }

  AvoraGameEconomyTotals totals({
    String? gameId,
  }) {
    final records = gameId == null
        ? _records.values
        : _records.values.where(
            (record) => record.gameId == gameId,
          );

    var bets = 0;
    var payouts = 0;
    var count = 0;

    for (final record in records) {
      bets += record.betCoins;
      payouts += record.payoutCoins;
      count++;
    }

    return AvoraGameEconomyTotals(
      totalBetCoins: bets,
      totalPayoutCoins: payouts,
      platformGrossResult: bets - payouts,
      roundCount: count,
    );
  }

  static bool userMustSeeOwnGameHistory() => true;

  static bool ownerMustSeeAllGameHistory() => true;

  static bool ownerMustSeeTotalBetAndPayout() => true;

  static bool ownerMustSeeActualRtpAndRevenue() => true;

  static bool duplicateRoundMustNeverDoubleSettle() => true;

  static bool failedOrBuggedRoundMustRemainTraceable() => true;
}
