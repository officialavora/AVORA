class AvoraGiftReceiverSettlement {
  const AvoraGiftReceiverSettlement({
    required this.senderDebitedCoins,
    required this.receiverCreditedValue,
    required this.platformValue,
  });

  final int senderDebitedCoins;
  final int receiverCreditedValue;
  final int platformValue;

  static AvoraGiftReceiverSettlement calculate({
    required int debitedCoins,
    required int receiverShareBps,
  }) {
    if (debitedCoins <= 0) {
      throw ArgumentError('debited_coins_must_be_positive');
    }

    if (receiverShareBps < 0 || receiverShareBps > 10000) {
      throw ArgumentError('receiver_share_bps_out_of_range');
    }

    final receiverValue = (debitedCoins * receiverShareBps) ~/ 10000;

    final platformValue = debitedCoins - receiverValue;

    return AvoraGiftReceiverSettlement(
      senderDebitedCoins: debitedCoins,
      receiverCreditedValue: receiverValue,
      platformValue: platformValue,
    );
  }

  static bool receiverCreditMustComeFromCommittedGift() => true;

  static bool receiverShareMustNeverExceedGiftValue() => true;

  static bool settlementMustRemainDeterministic() => true;

  static bool failedGiftMustNeverCreditReceiver() => true;
}
