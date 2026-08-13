import 'avora_gifting.dart';

class AvoraGiftSettlementConfig {
  /// 10000 basis points = 100%.
  final int standardDiamondCreditBps;

  /// Standard gift progress/count contribution.
  final int standardProgressCreditBps;

  /// Lucky Gift progress/count contribution.
  /// Example:
  /// 400 = 4%
  /// 500 = 5%
  /// 1000 = 10%
  /// 2000 = 20%
  final int luckyProgressCreditBps;

  const AvoraGiftSettlementConfig({
    this.standardDiamondCreditBps = 10000,
    this.standardProgressCreditBps = 10000,
    this.luckyProgressCreditBps = 1000,
  })  : assert(
          standardDiamondCreditBps >= 0 && standardDiamondCreditBps <= 10000,
        ),
        assert(
          standardProgressCreditBps >= 0 && standardProgressCreditBps <= 10000,
        ),
        assert(
          luckyProgressCreditBps >= 0 && luckyProgressCreditBps <= 10000,
        );
}

class AvoraGiftSettlement {
  final AvoraGiftKind kind;

  /// Coins charged to sender before any Lucky Gift return.
  final int senderCoinDebit;

  /// Backup diamonds credited to receiver.
  /// Lucky Gift returns zero here.
  final int receiverDiamondCredit;

  /// Amount used by generic progress/count systems before
  /// role/context-specific eligibility rules are applied.
  final int progressCreditAmount;

  /// Lucky Gift payout returned to sender by the server.
  /// Standard Gift always returns zero here.
  final int luckyReturnCoins;

  const AvoraGiftSettlement({
    required this.kind,
    required this.senderCoinDebit,
    required this.receiverDiamondCredit,
    required this.progressCreditAmount,
    required this.luckyReturnCoins,
  });

  int get senderNetCoinCost => senderCoinDebit - luckyReturnCoins;
}

class AvoraGiftSettlementEngine {
  const AvoraGiftSettlementEngine._();

  static AvoraGiftSettlement settle({
    required AvoraGiftTransaction transaction,
    AvoraGiftSettlementConfig config = const AvoraGiftSettlementConfig(),

    /// Must come from trusted server-side Lucky Gift logic.
    /// Client UI must never decide this value.
    int serverLuckyReturnCoins = 0,
  }) {
    if (!transaction.isConfirmed) {
      return AvoraGiftSettlement(
        kind: transaction.kind,
        senderCoinDebit: 0,
        receiverDiamondCredit: 0,
        progressCreditAmount: 0,
        luckyReturnCoins: 0,
      );
    }

    switch (transaction.kind) {
      case AvoraGiftKind.standard:
        return AvoraGiftSettlement(
          kind: AvoraGiftKind.standard,
          senderCoinDebit: transaction.totalAmount,
          receiverDiamondCredit: _applyBps(
            transaction.totalAmount,
            config.standardDiamondCreditBps,
          ),
          progressCreditAmount: _applyBps(
            transaction.totalAmount,
            config.standardProgressCreditBps,
          ),
          luckyReturnCoins: 0,
        );

      case AvoraGiftKind.lucky:
        return AvoraGiftSettlement(
          kind: AvoraGiftKind.lucky,
          senderCoinDebit: transaction.totalAmount,
          receiverDiamondCredit: 0,
          progressCreditAmount: _applyBps(
            transaction.totalAmount,
            config.luckyProgressCreditBps,
          ),
          luckyReturnCoins:
              serverLuckyReturnCoins < 0 ? 0 : serverLuckyReturnCoins,
        );
    }
  }

  static int _applyBps(
    int amount,
    int basisPoints,
  ) {
    return (amount * basisPoints) ~/ 10000;
  }
}
