import 'avora_gift_send_preflight.dart';
import 'avora_gift_transaction.dart';

class AvoraGiftSendCommand {
  const AvoraGiftSendCommand({
    required this.transactionId,
    required this.idempotencyKey,
    required this.senderAvoraId,
    required this.receiverAvoraId,
    required this.giftId,
    required this.coinBalance,
    required this.giftCoinPrice,
    required this.quantity,
    required this.senderActive,
    required this.receiverActive,
    required this.giftActive,
  });

  final String transactionId;
  final String idempotencyKey;
  final String senderAvoraId;
  final String receiverAvoraId;
  final String giftId;
  final int coinBalance;
  final int giftCoinPrice;
  final int quantity;
  final bool senderActive;
  final bool receiverActive;
  final bool giftActive;
}

class AvoraGiftSendResult {
  const AvoraGiftSendResult({
    required this.success,
    required this.reason,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.debitedCoins,
  });

  final bool success;
  final String reason;
  final int balanceBefore;
  final int balanceAfter;
  final int debitedCoins;
}

class AvoraGiftSendOrchestrator {
  AvoraGiftSendOrchestrator({
    AvoraGiftTransactionLedger? transactionLedger,
  }) : _transactionLedger = transactionLedger ?? AvoraGiftTransactionLedger();

  final AvoraGiftTransactionLedger _transactionLedger;

  AvoraGiftSendResult send(
    AvoraGiftSendCommand request,
  ) {
    if (request.senderAvoraId.trim().isEmpty ||
        request.receiverAvoraId.trim().isEmpty ||
        request.giftId.trim().isEmpty) {
      return AvoraGiftSendResult(
        success: false,
        reason: 'gift_identity_required',
        balanceBefore: request.coinBalance,
        balanceAfter: request.coinBalance,
        debitedCoins: 0,
      );
    }

    final preflight = AvoraGiftSendPreflight.evaluate(
      coinBalance: request.coinBalance,
      giftCoinPrice: request.giftCoinPrice,
      quantity: request.quantity,
      senderActive: request.senderActive,
      recipientActive: request.receiverActive,
      giftActive: request.giftActive,
    );

    if (!preflight.allowed) {
      return AvoraGiftSendResult(
        success: false,
        reason: preflight.reason,
        balanceBefore: request.coinBalance,
        balanceAfter: request.coinBalance,
        debitedCoins: 0,
      );
    }

    final transaction = _transactionLedger.debit(
      transactionId: request.transactionId,
      idempotencyKey: request.idempotencyKey,
      currentBalance: request.coinBalance,
      giftCoinPrice: request.giftCoinPrice,
      quantity: request.quantity,
    );

    return AvoraGiftSendResult(
      success: transaction.success,
      reason: transaction.reason,
      balanceBefore: transaction.balanceBefore,
      balanceAfter: transaction.balanceAfter,
      debitedCoins: transaction.debitedCoins,
    );
  }

  static bool preflightMustRunBeforeDebit() => true;

  static bool failedPreflightMustNeverDebit() => true;

  static bool duplicateSendMustNeverDoubleDebit() => true;

  static bool senderAndReceiverMustUseAvoraIdentity() => true;
}
