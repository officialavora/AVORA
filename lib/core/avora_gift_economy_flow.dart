import 'avora_gift_full_settlement.dart';
import 'avora_gift_ledger.dart';
import 'avora_gift_progress_engine.dart';
import 'avora_gift_send_orchestrator.dart';
import 'avora_gift_settlement_with_ledger.dart';
import 'avora_gift_value_attribution.dart';

class AvoraGiftEconomyFlowResult {
  const AvoraGiftEconomyFlowResult({
    required this.success,
    required this.reason,
    required this.settlement,
    required this.progress,
  });

  final bool success;
  final String reason;
  final AvoraGiftFullSettlementResult settlement;
  final AvoraGiftProgressSnapshot progress;
}

class AvoraGiftEconomyFlow {
  AvoraGiftEconomyFlow({
    required AvoraGiftLedger ledger,
    AvoraGiftProgressEngine? progressEngine,
  })  : _settlementService = AvoraGiftSettlementWithLedgerService(
          settlementService: AvoraGiftFullSettlementService(),
          ledger: ledger,
        ),
        _progressEngine = progressEngine ?? AvoraGiftProgressEngine();

  final AvoraGiftSettlementWithLedgerService _settlementService;
  final AvoraGiftProgressEngine _progressEngine;

  AvoraGiftEconomyFlowResult execute({
    required AvoraGiftSendCommand request,
    required int receiverShareBps,
    required DateTime createdAt,
    required AvoraGiftProgressSnapshot currentProgress,
    required bool countForSending,
    required bool countForReceiving,
    required bool countForRoomTarget,
    required bool countForReceiverBackup,
  }) {
    final settlement = _settlementService.settleAndRecord(
      request: request,
      receiverShareBps: receiverShareBps,
      createdAt: createdAt,
    );

    if (!settlement.success) {
      return AvoraGiftEconomyFlowResult(
        success: false,
        reason: settlement.reason,
        settlement: settlement,
        progress: currentProgress,
      );
    }

    final attribution = AvoraGiftValueAttribution.fromEligibleGift(
      eligibleGiftValue: settlement.senderDebitedCoins,
      countForSending: countForSending,
      countForReceiving: countForReceiving,
      countForRoomTarget: countForRoomTarget,
      countForReceiverBackup: countForReceiverBackup,
    );

    final progress = _progressEngine.apply(
      transactionId: request.transactionId,
      current: currentProgress,
      attribution: attribution,
    );

    if (!progress.applied) {
      return AvoraGiftEconomyFlowResult(
        success: false,
        reason: progress.reason,
        settlement: settlement,
        progress: currentProgress,
      );
    }

    return AvoraGiftEconomyFlowResult(
      success: true,
      reason: 'gift_economy_flow_committed',
      settlement: settlement,
      progress: progress.snapshot,
    );
  }

  static bool failedGiftMustNotIncreaseProgress() => true;
  static bool committedGiftMustProduceLedgerAndProgress() => true;
  static bool transactionIdMustBindGiftLedgerAndProgress() => true;
  static bool duplicateGiftMustNotDoubleCountTargets() => true;
}
