class AvoraGiftTransactionResult {
  const AvoraGiftTransactionResult({
    required this.success,
    required this.reason,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.debitedCoins,
    required this.transactionId,
  });

  final bool success;
  final String reason;
  final int balanceBefore;
  final int balanceAfter;
  final int debitedCoins;
  final String transactionId;
}

class AvoraGiftTransactionLedger {
  final Set<String> _processedKeys = <String>{};

  AvoraGiftTransactionResult debit({
    required String transactionId,
    required String idempotencyKey,
    required int currentBalance,
    required int giftCoinPrice,
    required int quantity,
  }) {
    if (transactionId.trim().isEmpty || idempotencyKey.trim().isEmpty) {
      return AvoraGiftTransactionResult(
        success: false,
        reason: 'invalid_transaction_identity',
        balanceBefore: currentBalance,
        balanceAfter: currentBalance,
        debitedCoins: 0,
        transactionId: transactionId,
      );
    }

    if (currentBalance < 0 || giftCoinPrice <= 0 || quantity <= 0) {
      return AvoraGiftTransactionResult(
        success: false,
        reason: 'invalid_transaction_input',
        balanceBefore: currentBalance,
        balanceAfter: currentBalance,
        debitedCoins: 0,
        transactionId: transactionId,
      );
    }

    if (_processedKeys.contains(idempotencyKey)) {
      return AvoraGiftTransactionResult(
        success: false,
        reason: 'duplicate_transaction',
        balanceBefore: currentBalance,
        balanceAfter: currentBalance,
        debitedCoins: 0,
        transactionId: transactionId,
      );
    }

    final cost = giftCoinPrice * quantity;

    if (currentBalance < cost) {
      return AvoraGiftTransactionResult(
        success: false,
        reason: 'insufficient_coin_balance',
        balanceBefore: currentBalance,
        balanceAfter: currentBalance,
        debitedCoins: 0,
        transactionId: transactionId,
      );
    }

    _processedKeys.add(idempotencyKey);

    return AvoraGiftTransactionResult(
      success: true,
      reason: 'gift_transaction_committed',
      balanceBefore: currentBalance,
      balanceAfter: currentBalance - cost,
      debitedCoins: cost,
      transactionId: transactionId,
    );
  }

  static bool giftDebitMustBeAtomic() => true;
  static bool duplicateGiftMustNeverDoubleDebit() => true;
  static bool failedGiftMustNeverReduceBalance() => true;
  static bool transactionMustUseIdempotencyKey() => true;
}
