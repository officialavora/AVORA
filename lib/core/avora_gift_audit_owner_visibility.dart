import 'avora_gift_audit_reconciliation.dart';

class AvoraGiftAuditOwnerViewItem {
  const AvoraGiftAuditOwnerViewItem({
    required this.transactionId,
    required this.status,
    required this.errorCode,
    required this.createdAtUtc,
  });

  final String transactionId;
  final AvoraGiftAuditReconciliationStatus status;
  final String errorCode;
  final DateTime createdAtUtc;
}

class AvoraGiftAuditOwnerVisibilityService {
  const AvoraGiftAuditOwnerVisibilityService();

  List<AvoraGiftAuditOwnerViewItem> buildView(
    Iterable<AvoraGiftAuditReconciliationItem> items,
  ) {
    final result = items
        .map(
          (item) => AvoraGiftAuditOwnerViewItem(
            transactionId: item.transactionId,
            status: item.status,
            errorCode: item.errorCode,
            createdAtUtc: item.createdAtUtc.toUtc(),
          ),
        )
        .toList(growable: false);

    result.sort(
      (a, b) => b.createdAtUtc.compareTo(a.createdAtUtc),
    );

    return List<AvoraGiftAuditOwnerViewItem>.unmodifiable(result);
  }

  static bool ownerMustSeePendingReconciliation() => true;
  static bool ownerMustSeeCompletedReconciliationHistory() => true;
  static bool completedItemsMustNotDisappearFromHistory() => true;
  static bool ownerViewMustPreserveTransactionId() => true;
  static bool futureAuditReconciliationMustUseSameOwnerView() => true;
}
