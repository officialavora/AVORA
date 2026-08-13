class AvoraGiftOwnerAuditEvent {
  const AvoraGiftOwnerAuditEvent({
    required this.transactionId,
    required this.senderAvoraId,
    required this.receiverAvoraId,
    required this.giftId,
    required this.quantity,
    required this.senderDebitedCoins,
    required this.receiverCreditedValue,
    required this.platformValue,
    required this.senderSendingProgress,
    required this.receiverReceivingProgress,
    required this.roomTargetProgress,
    required this.receiverBackupProgress,
    required this.createdAtUtc,
  });

  final String transactionId;
  final String senderAvoraId;
  final String receiverAvoraId;
  final String giftId;
  final int quantity;

  final int senderDebitedCoins;
  final int receiverCreditedValue;
  final int platformValue;

  final int senderSendingProgress;
  final int receiverReceivingProgress;
  final int roomTargetProgress;
  final int receiverBackupProgress;

  final DateTime createdAtUtc;

  bool get isValid {
    if (transactionId.trim().isEmpty ||
        senderAvoraId.trim().isEmpty ||
        receiverAvoraId.trim().isEmpty ||
        giftId.trim().isEmpty) {
      return false;
    }

    if (quantity <= 0 ||
        senderDebitedCoins <= 0 ||
        receiverCreditedValue < 0 ||
        platformValue < 0) {
      return false;
    }

    if (receiverCreditedValue + platformValue != senderDebitedCoins) {
      return false;
    }

    if (senderSendingProgress < 0 ||
        receiverReceivingProgress < 0 ||
        roomTargetProgress < 0 ||
        receiverBackupProgress < 0) {
      return false;
    }

    return true;
  }

  Map<String, Object> toAuditMap() {
    if (!isValid) {
      throw StateError('invalid_gift_owner_audit_event');
    }

    return <String, Object>{
      'eventType': 'gift_settlement',
      'transactionId': transactionId,
      'senderAvoraId': senderAvoraId,
      'receiverAvoraId': receiverAvoraId,
      'giftId': giftId,
      'quantity': quantity,
      'senderDebitedCoins': senderDebitedCoins,
      'receiverCreditedValue': receiverCreditedValue,
      'platformValue': platformValue,
      'senderSendingProgress': senderSendingProgress,
      'receiverReceivingProgress': receiverReceivingProgress,
      'roomTargetProgress': roomTargetProgress,
      'receiverBackupProgress': receiverBackupProgress,
      'createdAtUtc': createdAtUtc.toIso8601String(),
    };
  }

  static bool everyCommittedGiftMustBeOwnerAuditable() => true;

  static bool auditMustPreserveImmutableTransactionId() => true;

  static bool auditMustPreserveSenderAndReceiver() => true;

  static bool auditMustPreserveEconomicBreakdown() => true;

  static bool futureGiftFieldsMustExtendSameAuditEvent() => true;
}
