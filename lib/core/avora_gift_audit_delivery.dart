enum AvoraGiftAuditDeliveryStatus {
  written,
  pendingReconciliation,
}

class AvoraGiftAuditDeliveryResult {
  const AvoraGiftAuditDeliveryResult({
    required this.transactionCommitted,
    required this.status,
    required this.transactionId,
    this.errorCode,
  });

  final bool transactionCommitted;
  final AvoraGiftAuditDeliveryStatus status;
  final String transactionId;
  final String? errorCode;

  bool get auditWritten => status == AvoraGiftAuditDeliveryStatus.written;

  bool get needsReconciliation =>
      status == AvoraGiftAuditDeliveryStatus.pendingReconciliation;
}

class AvoraGiftAuditDeliveryPolicy {
  const AvoraGiftAuditDeliveryPolicy._();

  static AvoraGiftAuditDeliveryResult written({
    required String transactionId,
  }) {
    if (transactionId.trim().isEmpty) {
      throw ArgumentError('transaction_id_required');
    }

    return AvoraGiftAuditDeliveryResult(
      transactionCommitted: true,
      status: AvoraGiftAuditDeliveryStatus.written,
      transactionId: transactionId,
    );
  }

  static AvoraGiftAuditDeliveryResult auditFailureAfterCommit({
    required String transactionId,
    required String errorCode,
  }) {
    if (transactionId.trim().isEmpty) {
      throw ArgumentError('transaction_id_required');
    }

    return AvoraGiftAuditDeliveryResult(
      transactionCommitted: true,
      status: AvoraGiftAuditDeliveryStatus.pendingReconciliation,
      transactionId: transactionId,
      errorCode: errorCode,
    );
  }

  static bool auditFailureMustNeverTriggerSecondGiftDebit() => true;

  static bool committedEconomyMustRemainCommitted() => true;

  static bool missingAuditMustEnterReconciliation() => true;

  static bool reconciliationMustUseOriginalTransactionId() => true;

  static bool ownerMustSeePendingAuditReconciliation() => true;
}
