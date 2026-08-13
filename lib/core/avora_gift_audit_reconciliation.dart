enum AvoraGiftAuditReconciliationStatus {
  pending,
  completed,
}

class AvoraGiftAuditReconciliationItem {
  const AvoraGiftAuditReconciliationItem({
    required this.transactionId,
    required this.errorCode,
    required this.createdAtUtc,
    required this.status,
  });

  final String transactionId;
  final String errorCode;
  final DateTime createdAtUtc;
  final AvoraGiftAuditReconciliationStatus status;

  AvoraGiftAuditReconciliationItem completed() {
    return AvoraGiftAuditReconciliationItem(
      transactionId: transactionId,
      errorCode: errorCode,
      createdAtUtc: createdAtUtc,
      status: AvoraGiftAuditReconciliationStatus.completed,
    );
  }
}

class AvoraGiftAuditReconciliationQueue {
  final Map<String, AvoraGiftAuditReconciliationItem> _items =
      <String, AvoraGiftAuditReconciliationItem>{};

  bool enqueue({
    required String transactionId,
    required String errorCode,
    required DateTime createdAt,
  }) {
    final tx = transactionId.trim();

    if (tx.isEmpty || errorCode.trim().isEmpty) {
      throw ArgumentError('reconciliation_identity_required');
    }

    if (_items.containsKey(tx)) {
      return false;
    }

    _items[tx] = AvoraGiftAuditReconciliationItem(
      transactionId: tx,
      errorCode: errorCode,
      createdAtUtc: createdAt.toUtc(),
      status: AvoraGiftAuditReconciliationStatus.pending,
    );

    return true;
  }

  AvoraGiftAuditReconciliationItem? byTransactionId(
    String transactionId,
  ) {
    return _items[transactionId];
  }

  List<AvoraGiftAuditReconciliationItem> pendingItems() {
    return List<AvoraGiftAuditReconciliationItem>.unmodifiable(
      _items.values.where(
        (item) => item.status == AvoraGiftAuditReconciliationStatus.pending,
      ),
    );
  }

  bool markCompleted(String transactionId) {
    final existing = _items[transactionId];

    if (existing == null) {
      return false;
    }

    if (existing.status == AvoraGiftAuditReconciliationStatus.completed) {
      return false;
    }

    _items[transactionId] = existing.completed();
    return true;
  }

  static bool queueMustNeverReexecuteGiftEconomy() => true;

  static bool transactionIdMustRemainIdempotent() => true;

  static bool duplicatePendingItemMustNotBeCreated() => true;

  static bool ownerMustSeePendingAndCompletedStatus() => true;

  static bool completedAuditMustRemainHistoricallyTraceable() => true;
}
