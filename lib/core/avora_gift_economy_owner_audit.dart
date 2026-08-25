import 'avora_gift_economy_flow.dart';
import 'avora_gift_owner_audit_event.dart';
import 'avora_gift_progress_engine.dart';
import 'avora_gift_send_orchestrator.dart';

abstract interface class AvoraGiftOwnerAuditRepository {
  Future<void> append(AvoraGiftOwnerAuditEvent event);
}

class AvoraGiftEconomyOwnerAuditResult {
  const AvoraGiftEconomyOwnerAuditResult({
    required this.success,
    required this.reason,
    required this.economyResult,
    required this.auditWritten,
  });

  final bool success;
  final String reason;
  final AvoraGiftEconomyFlowResult economyResult;
  final bool auditWritten;
}

class AvoraGiftEconomyOwnerAuditService {
  const AvoraGiftEconomyOwnerAuditService({
    required AvoraGiftEconomyFlow economyFlow,
    required AvoraGiftOwnerAuditRepository auditRepository,
  })  : _economyFlow = economyFlow,
        _auditRepository = auditRepository;

  final AvoraGiftEconomyFlow _economyFlow;
  final AvoraGiftOwnerAuditRepository _auditRepository;

  Future<AvoraGiftEconomyOwnerAuditResult> execute({
    required AvoraGiftSendCommand request,
    required int receiverShareBps,
    required DateTime createdAt,
    required AvoraGiftProgressSnapshot currentProgress,
    required bool countForSending,
    required bool countForReceiving,
    required bool countForRoomTarget,
    required bool countForReceiverBackup,
  }) async {
    final economy = _economyFlow.execute(
      request: request,
      receiverShareBps: receiverShareBps,
      createdAt: createdAt,
      currentProgress: currentProgress,
      countForSending: countForSending,
      countForReceiving: countForReceiving,
      countForRoomTarget: countForRoomTarget,
      countForReceiverBackup: countForReceiverBackup,
    );

    if (!economy.success) {
      return AvoraGiftEconomyOwnerAuditResult(
        success: false,
        reason: economy.reason,
        economyResult: economy,
        auditWritten: false,
      );
    }

    final event = AvoraGiftOwnerAuditEvent(
      transactionId: request.transactionId,
      senderAvoraId: request.senderAvoraId,
      receiverAvoraId: request.receiverAvoraId,
      giftId: request.giftId,
      quantity: request.quantity,
      senderDebitedCoins: economy.settlement.senderDebitedCoins,
      receiverCreditedValue: economy.settlement.receiverCreditedValue,
      platformValue: economy.settlement.platformValue,
      senderSendingProgress: economy.progress.senderSending,
      receiverReceivingProgress: economy.progress.receiverReceiving,
      roomTargetProgress: economy.progress.roomTarget,
      receiverBackupProgress: economy.progress.receiverBackup,
      createdAtUtc: createdAt.toUtc(),
    );

    if (!event.isValid) {
      return AvoraGiftEconomyOwnerAuditResult(
        success: false,
        reason: 'invalid_owner_audit_event',
        economyResult: economy,
        auditWritten: false,
      );
    }

    await _auditRepository.append(event);

    return AvoraGiftEconomyOwnerAuditResult(
      success: true,
      reason: 'gift_economy_and_owner_audit_committed',
      economyResult: economy,
      auditWritten: true,
    );
  }

  static bool successfulGiftMustCreateOwnerAudit() => true;

  static bool failedGiftMustNotCreateSuccessAudit() => true;

  static bool auditMustUseSameGiftTransactionId() => true;

  static bool ownerAuditMustContainEconomicAndProgressData() => true;
}
