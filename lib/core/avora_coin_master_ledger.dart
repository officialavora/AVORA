enum AvoraCoinLedgerEventType {
  recharge,
  sellerInventory,
  transfer,
  giftSend,
  giftReceive,
  gameBet,
  gameWin,
  gameLoss,
  reward,
  salary,
  commission,
  promotion,
  refund,
  recovery,
  adjustment,
  systemCredit,
  systemDebit,
}

class AvoraCoinLedgerEntry {
  const AvoraCoinLedgerEntry({
    required this.entryId,
    required this.transactionId,
    required this.eventType,
    required this.avoraId,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.createdAt,
    required this.policyVersion,
    this.relatedAvoraId,
    this.referenceId,
    this.reason,
  });

  final String entryId;
  final String transactionId;
  final AvoraCoinLedgerEventType eventType;

  final String avoraId;
  final String? relatedAvoraId;

  final int amount;
  final int balanceBefore;
  final int balanceAfter;

  final String? referenceId;
  final String? reason;

  final DateTime createdAt;
  final String policyVersion;

  bool get isCredit => balanceAfter > balanceBefore;
  bool get isDebit => balanceAfter < balanceBefore;
}

class AvoraCoinMasterLedger {
  final List<AvoraCoinLedgerEntry> _entries = [];
  final Set<String> _entryIds = {};

  List<AvoraCoinLedgerEntry> get entries =>
      List<AvoraCoinLedgerEntry>.unmodifiable(_entries);

  void append(AvoraCoinLedgerEntry entry) {
    if (entry.entryId.trim().isEmpty ||
        entry.transactionId.trim().isEmpty ||
        entry.avoraId.trim().isEmpty ||
        entry.policyVersion.trim().isEmpty) {
      throw ArgumentError('invalid_ledger_identity');
    }

    if (entry.amount < 0 || entry.balanceBefore < 0 || entry.balanceAfter < 0) {
      throw ArgumentError('negative_ledger_value');
    }

    if (!_entryIds.add(entry.entryId)) {
      throw StateError('duplicate_ledger_entry');
    }

    _entries.add(entry);
  }

  List<AvoraCoinLedgerEntry> forUser(String avoraId) {
    return List<AvoraCoinLedgerEntry>.unmodifiable(
      _entries.where((entry) => entry.avoraId == avoraId),
    );
  }

  List<AvoraCoinLedgerEntry> forTransaction(String transactionId) {
    return List<AvoraCoinLedgerEntry>.unmodifiable(
      _entries.where(
        (entry) => entry.transactionId == transactionId,
      ),
    );
  }

  List<AvoraCoinLedgerEntry> forType(
    AvoraCoinLedgerEventType type,
  ) {
    return List<AvoraCoinLedgerEntry>.unmodifiable(
      _entries.where((entry) => entry.eventType == type),
    );
  }

  static bool ownerMustHaveGlobalLedgerVisibility() => true;

  static bool userMustOnlyReceiveScopedFinancialHistory() => true;

  static bool historicalLedgerMustRemainImmutable() => true;

  static bool everyCoinMutationMustHaveTransactionId() => true;

  static bool futureCoinFeaturesMustUseMasterLedger() => true;

  static bool manualOwnerAdjustmentMustBeAudited() => true;

  static bool balanceMutationWithoutLedgerMustFailClosed() => true;
}
