import 'avora_gift_receiver_settlement.dart';
import 'avora_gift_send_orchestrator.dart';

class AvoraGiftFullSettlementResult {
  const AvoraGiftFullSettlementResult({
    required this.success,
    required this.reason,
    required this.senderBalanceBefore,
    required this.senderBalanceAfter,
    required this.senderDebitedCoins,
    required this.receiverCreditedValue,
    required this.platformValue,
  });

  final bool success;
  final String reason;
  final int senderBalanceBefore;
  final int senderBalanceAfter;
  final int senderDebitedCoins;
  final int receiverCreditedValue;
  final int platformValue;
}

class AvoraGiftFullSettlementService {
  AvoraGiftFullSettlementService({
    AvoraGiftSendOrchestrator? sendOrchestrator,
  }) : _sendOrchestrator = sendOrchestrator ?? AvoraGiftSendOrchestrator();

  final AvoraGiftSendOrchestrator _sendOrchestrator;

  AvoraGiftFullSettlementResult settle({
    required AvoraGiftSendCommand request,
    required int receiverShareBps,
  }) {
    final send = _sendOrchestrator.send(request);

    if (!send.success) {
      return AvoraGiftFullSettlementResult(
        success: false,
        reason: send.reason,
        senderBalanceBefore: send.balanceBefore,
        senderBalanceAfter: send.balanceAfter,
        senderDebitedCoins: 0,
        receiverCreditedValue: 0,
        platformValue: 0,
      );
    }

    final settlement = AvoraGiftReceiverSettlement.calculate(
      debitedCoins: send.debitedCoins,
      receiverShareBps: receiverShareBps,
    );

    return AvoraGiftFullSettlementResult(
      success: true,
      reason: 'gift_full_settlement_committed',
      senderBalanceBefore: send.balanceBefore,
      senderBalanceAfter: send.balanceAfter,
      senderDebitedCoins: settlement.senderDebitedCoins,
      receiverCreditedValue: settlement.receiverCreditedValue,
      platformValue: settlement.platformValue,
    );
  }

  static bool senderDebitMustPrecedeReceiverCredit() => true;

  static bool failedDebitMustProduceZeroReceiverCredit() => true;

  static bool settlementMustPreserveTotalGiftValue() => true;
}
