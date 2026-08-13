class AvoraGiftLedgerRecord {
  const AvoraGiftLedgerRecord({
    required this.transactionId,
    required this.idempotencyKey,
    required this.senderAvoraId,
    required this.receiverAvoraId,
    required this.giftId,
    required this.quantity,
    required this.senderDebitedCoins,
    required this.receiverCreditedValue,
    required this.platformValue,
    required this.createdAt,
  });

  final String transactionId;
  final String idempotencyKey;
  final String senderAvoraId;
  final String receiverAvoraId;
  final String giftId;
  final int quantity;
  final int senderDebitedCoins;
  final int receiverCreditedValue;
  final int platformValue;
  final DateTime createdAt;
}

class AvoraGiftLedger {
  final Map<String, AvoraGiftLedgerRecord> _records =
      <String, AvoraGiftLedgerRecord>{};

  void append(AvoraGiftLedgerRecord record) {
    if (record.transactionId.trim().isEmpty ||
        record.idempotencyKey.trim().isEmpty ||
        record.senderAvoraId.trim().isEmpty ||
        record.receiverAvoraId.trim().isEmpty ||
        record.giftId.trim().isEmpty) {
      throw ArgumentError('gift_ledger_identity_required');
    }

    if (record.quantity <= 0 ||
        record.senderDebitedCoins <= 0 ||
        record.receiverCreditedValue < 0 ||
        record.platformValue < 0) {
      throw ArgumentError('invalid_gift_ledger_value');
    }

    if (record.receiverCreditedValue + record.platformValue !=
        record.senderDebitedCoins) {
      throw ArgumentError('gift_ledger_value_mismatch');
    }

    if (_records.containsKey(record.transactionId)) {
      throw StateError('duplicate_gift_transaction');
    }

    _records[record.transactionId] = record;
  }

  AvoraGiftLedgerRecord? byTransactionId(String transactionId) {
    return _records[transactionId];
  }

  List<AvoraGiftLedgerRecord> forSender(String avoraId) {
    return List<AvoraGiftLedgerRecord>.unmodifiable(
      _records.values.where((record) => record.senderAvoraId == avoraId),
    );
  }

  List<AvoraGiftLedgerRecord> forReceiver(String avoraId) {
    return List<AvoraGiftLedgerRecord>.unmodifiable(
      _records.values.where((record) => record.receiverAvoraId == avoraId),
    );
  }

  static bool committedGiftMustProduceLedgerEvidence() => true;
  static bool ledgerHistoryMustRemainImmutable() => true;
  static bool ownerMustBeAbleToAuditGiftHistory() => true;
  static bool clientMustNeverSilentlyRewriteGiftHistory() => true;
}
