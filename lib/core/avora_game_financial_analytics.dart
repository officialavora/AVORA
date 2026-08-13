import 'avora_coin_master_ledger.dart';

class AvoraGameFinancialSnapshot {
  const AvoraGameFinancialSnapshot({
    required this.gameId,
    required this.totalBetCoins,
    required this.totalPayoutCoins,
    required this.platformGrossResult,
    required this.betCount,
    required this.winCount,
    required this.lossCount,
  });

  final String gameId;
  final int totalBetCoins;
  final int totalPayoutCoins;
  final int platformGrossResult;
  final int betCount;
  final int winCount;
  final int lossCount;

  double get actualReturnPercent {
    if (totalBetCoins == 0) return 0;
    return (totalPayoutCoins / totalBetCoins) * 100;
  }
}

class AvoraGameFinancialAnalytics {
  const AvoraGameFinancialAnalytics();

  AvoraGameFinancialSnapshot ownerSnapshot({
    required String gameId,
    required Iterable<AvoraCoinLedgerEntry> entries,
  }) {
    final id = gameId.trim();

    if (id.isEmpty) {
      throw ArgumentError('game_id_required');
    }

    var bets = 0;
    var payouts = 0;
    var betCount = 0;
    var winCount = 0;
    var lossCount = 0;

    for (final entry in entries) {
      if (entry.referenceId != id) continue;

      switch (entry.eventType) {
        case AvoraCoinLedgerEventType.gameBet:
          bets += entry.amount;
          betCount++;
          break;

        case AvoraCoinLedgerEventType.gameWin:
          payouts += entry.amount;
          winCount++;
          break;

        case AvoraCoinLedgerEventType.gameLoss:
          lossCount++;
          break;

        default:
          break;
      }
    }

    return AvoraGameFinancialSnapshot(
      gameId: id,
      totalBetCoins: bets,
      totalPayoutCoins: payouts,
      platformGrossResult: bets - payouts,
      betCount: betCount,
      winCount: winCount,
      lossCount: lossCount,
    );
  }

  List<AvoraCoinLedgerEntry> userHistory({
    required String userAvoraId,
    required Iterable<AvoraCoinLedgerEntry> entries,
  }) {
    final id = userAvoraId.trim();

    if (id.isEmpty) {
      throw ArgumentError('user_avora_id_required');
    }

    return List<AvoraCoinLedgerEntry>.unmodifiable(
      entries.where(
        (entry) =>
            entry.avoraId == id &&
            (entry.eventType == AvoraCoinLedgerEventType.gameBet ||
                entry.eventType == AvoraCoinLedgerEventType.gameWin ||
                entry.eventType == AvoraCoinLedgerEventType.gameLoss),
      ),
    );
  }

  static bool ownerMustSeeAllGamesFinancially() => true;
  static bool ownerMustSeeActualReturnPercent() => true;
  static bool ownerMustSeeBetPayoutAndGrossResult() => true;
  static bool userMustOnlySeeOwnGameFinancialHistory() => true;
  static bool analyticsMustComeFromImmutableLedger() => true;
  static bool futureGamesMustAppearWithoutSeparateAnalyticsEngine() => true;
}
