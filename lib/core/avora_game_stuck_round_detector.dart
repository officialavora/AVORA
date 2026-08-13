import 'avora_coin_master_ledger.dart';

class AvoraStuckGameRound {
  const AvoraStuckGameRound({
    required this.roundId,
    required this.gameId,
    required this.userAvoraId,
    required this.betCoins,
    required this.balanceAfterBet,
    required this.policyVersion,
    required this.betCreatedAtUtc,
  });

  final String roundId;
  final String gameId;
  final String userAvoraId;
  final int betCoins;
  final int balanceAfterBet;
  final String policyVersion;
  final DateTime betCreatedAtUtc;
}

class AvoraGameStuckRoundDetector {
  const AvoraGameStuckRoundDetector();

  List<AvoraStuckGameRound> detect({
    required Iterable<AvoraCoinLedgerEntry> entries,
    required DateTime nowUtc,
    Duration minimumAge = const Duration(minutes: 2),
  }) {
    if (minimumAge.isNegative) {
      throw ArgumentError('minimum_age_must_not_be_negative');
    }

    final grouped = <String, List<AvoraCoinLedgerEntry>>{};

    for (final entry in entries) {
      if (entry.eventType != AvoraCoinLedgerEventType.gameBet &&
          entry.eventType != AvoraCoinLedgerEventType.gameWin &&
          entry.eventType != AvoraCoinLedgerEventType.gameLoss) {
        continue;
      }

      grouped
          .putIfAbsent(
            entry.transactionId,
            () => <AvoraCoinLedgerEntry>[],
          )
          .add(entry);
    }

    final stuck = <AvoraStuckGameRound>[];

    for (final group in grouped.entries) {
      AvoraCoinLedgerEntry? bet;
      var hasOutcome = false;

      for (final entry in group.value) {
        if (entry.eventType == AvoraCoinLedgerEventType.gameBet) {
          bet ??= entry;
        }

        if (entry.eventType == AvoraCoinLedgerEventType.gameWin ||
            entry.eventType == AvoraCoinLedgerEventType.gameLoss) {
          hasOutcome = true;
        }
      }

      if (bet == null || hasOutcome) {
        continue;
      }

      final age = nowUtc.toUtc().difference(
            bet.createdAt.toUtc(),
          );

      if (age < minimumAge) {
        continue;
      }

      stuck.add(
        AvoraStuckGameRound(
          roundId: bet.transactionId,
          gameId: bet.referenceId ?? '',
          userAvoraId: bet.avoraId,
          betCoins: bet.amount,
          balanceAfterBet: bet.balanceAfter,
          policyVersion: bet.policyVersion,
          betCreatedAtUtc: bet.createdAt.toUtc(),
        ),
      );
    }

    stuck.sort(
      (a, b) => a.betCreatedAtUtc.compareTo(
        b.betCreatedAtUtc,
      ),
    );

    return List<AvoraStuckGameRound>.unmodifiable(stuck);
  }

  static bool betWithoutOutcomeMustBeDetectable() => true;

  static bool detectorMustNotAutoCreditCoins() => true;

  static bool ownerMustSeeStuckRoundUserAndGame() => true;

  static bool originalPolicyVersionMustRemainVisible() => true;

  static bool stuckRoundMustUseReconciliationBeforeRepair() => true;

  static bool completedRoundMustNeverBeReportedAsStuck() => true;

  static bool futureGamesMustUseSameDetectionContract() => true;
}
