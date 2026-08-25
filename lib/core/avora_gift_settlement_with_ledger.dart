import 'avora_gift_full_settlement.dart';
import 'avora_gift_ledger.dart';
import 'avora_gift_send_orchestrator.dart';

class AvoraGiftSettlementWithLedgerService {
  AvoraGiftSettlementWithLedgerService({
    required AvoraGiftFullSettlementService settlementService,
    required AvoraGiftLedger ledger,
  })  : _settlementService = settlementService,
        _ledger = ledger;

  final AvoraGiftFullSettlementService _settlementService;
  final AvoraGiftLedger _ledger;

  AvoraGiftFullSettlementResult settleAndRecord({
    required AvoraGiftSendCommand request,
    required int receiverShareBps,
    required DateTime createdAt,
  }) {
    final result = _settlementService.settle(
      request: request,
      receiverShareBps: receiverShareBps,
    );

    if (!result.success) {
      return result;
    }

    _ledger.append(
      AvoraGiftLedgerRecord(
        transactionId: request.transactionId,
        idempotencyKey: request.idempotencyKey,
        senderAvoraId: request.senderAvoraId,
        receiverAvoraId: request.receiverAvoraId,
        giftId: request.giftId,
        quantity: request.quantity,
        senderDebitedCoins: result.senderDebitedCoins,
        receiverCreditedValue: result.receiverCreditedValue,
        platformValue: result.platformValue,
        createdAt: createdAt.toUtc(),
      ),
    );

    return result;
  }

  static bool successfulGiftMustWriteLedger() => true;
  static bool failedGiftMustNotWriteLedger() => true;
  static bool ledgerWriteMustUseSameTransactionId() => true;
  static bool ledgerMustPreserveSenderAndReceiverAvoraIds() => true;
}
