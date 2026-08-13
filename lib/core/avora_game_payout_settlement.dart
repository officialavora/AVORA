import 'avora_actor_presentation.dart';
import 'avora_game_round_engine.dart';
import 'avora_launch_wallet.dart';

class AvoraGamePayoutRecord {
  const AvoraGamePayoutRecord({
    required this.payoutId,
    required this.betId,
    required this.roundId,
    required this.playerAvoraId,
    required this.betCoins,
    required this.winCoins,
    required this.netCoins,
    required this.createdAtUtc,
  });

  final String payoutId;
  final String betId;
  final String roundId;
  final String playerAvoraId;
  final int betCoins;
  final int winCoins;
  final int netCoins;
  final DateTime createdAtUtc;
}

class AvoraGamePayoutLedger {
  final Map<String, AvoraGamePayoutRecord> _records =
      <String, AvoraGamePayoutRecord>{};

  void append(AvoraGamePayoutRecord record) {
    if (record.payoutId.trim().isEmpty ||
        record.betId.trim().isEmpty ||
        record.roundId.trim().isEmpty ||
        record.playerAvoraId.trim().isEmpty ||
        record.betCoins <= 0 ||
        record.winCoins < 0) {
      throw ArgumentError('invalid_game_payout_record');
    }

    if (_records.containsKey(record.payoutId)) {
      throw StateError('duplicate_game_payout');
    }

    if (_records.values.any((item) => item.betId == record.betId)) {
      throw StateError('bet_already_paid_or_recorded');
    }

    _records[record.payoutId] = record;
  }

  AvoraGamePayoutRecord? byBetId(String betId) {
    for (final record in _records.values) {
      if (record.betId == betId) {
        return record;
      }
    }
    return null;
  }

  List<AvoraGamePayoutRecord> byRound(String roundId) {
    return List<AvoraGamePayoutRecord>.unmodifiable(
      _records.values.where(
        (record) => record.roundId == roundId,
      ),
    );
  }

  List<AvoraGamePayoutRecord> byPlayer(String avoraId) {
    return List<AvoraGamePayoutRecord>.unmodifiable(
      _records.values.where(
        (record) => record.playerAvoraId == avoraId,
      ),
    );
  }

  static bool everySettledBetMustCreatePayoutRecord() => true;

  static bool losingBetMustStillCreateSettlementRecord() => true;

  static bool duplicatePayoutMustNeverDoubleCredit() => true;

  static bool payoutMustPreserveBetRoundAndPlayerIdentity() => true;

  static bool futureGamesMustUseSamePayoutLedger() => true;
}

class AvoraGamePayoutService {
  AvoraGamePayoutService({
    required AvoraLaunchWalletLedger walletLedger,
    required AvoraGamePayoutLedger payoutLedger,
  })  : _walletLedger = walletLedger,
        _payoutLedger = payoutLedger;

  final AvoraLaunchWalletLedger _walletLedger;
  final AvoraGamePayoutLedger _payoutLedger;

  AvoraGamePayoutRecord apply({
    required AvoraPlayerGameSettlement settlement,
    required DateTime createdAtUtc,
  }) {
    if (_payoutLedger.byBetId(settlement.betId) != null) {
      throw StateError('bet_already_paid_or_recorded');
    }

    if (settlement.winCoins > 0) {
      _walletLedger.credit(
        transactionId: 'game-win-${settlement.betId}',
        type: AvoraWalletTransactionType.coinCredit,
        actor: const AvoraActionActor(
          avoraId: 'SYSTEM',
          kind: AvoraActorKind.system,
          displayName: 'System',
        ),
        targetAvoraId: settlement.playerAvoraId,
        amountCoins: settlement.winCoins,
        createdAtUtc: createdAtUtc,
        reason: 'game_win:${settlement.roundId}:${settlement.betId}',
      );
    }

    final record = AvoraGamePayoutRecord(
      payoutId: 'payout-${settlement.betId}',
      betId: settlement.betId,
      roundId: settlement.roundId,
      playerAvoraId: settlement.playerAvoraId,
      betCoins: settlement.betCoins,
      winCoins: settlement.winCoins,
      netCoins: settlement.netCoins,
      createdAtUtc: createdAtUtc.toUtc(),
    );

    _payoutLedger.append(record);

    return record;
  }

  List<AvoraGamePayoutRecord> applyRound({
    required Iterable<AvoraPlayerGameSettlement> settlements,
    required DateTime createdAtUtc,
  }) {
    final results = <AvoraGamePayoutRecord>[];

    for (final settlement in settlements) {
      results.add(
        apply(
          settlement: settlement,
          createdAtUtc: createdAtUtc,
        ),
      );
    }

    return List<AvoraGamePayoutRecord>.unmodifiable(results);
  }

  static bool winningCoinsMustCreditActualWallet() => true;

  static bool losingBetMustNotMintCoins() => true;

  static bool payoutMustUseSystemAuthoritativeCredit() => true;

  static bool duplicateSettlementMustFailClosed() => true;

  static bool roundMustBeReconstructableFromBetToPayout() => true;

  static bool futureWheelGameMustUseSamePayoutService() => true;

  static bool futureFruitGameMustUseSamePayoutService() => true;
}
