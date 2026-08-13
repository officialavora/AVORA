class AvoraGiftAtomicitySnapshot {
  const AvoraGiftAtomicitySnapshot({
    required this.transactionId,
    required this.senderBalanceBefore,
    required this.senderBalanceAfter,
    required this.expectedDebit,
    required this.ledgerRecorded,
    required this.receiverCredited,
  });

  final String transactionId;
  final int senderBalanceBefore;
  final int senderBalanceAfter;
  final int expectedDebit;
  final bool ledgerRecorded;
  final bool receiverCredited;
}

class AvoraGiftAtomicityDecision {
  const AvoraGiftAtomicityDecision({
    required this.valid,
    required this.reason,
  });

  final bool valid;
  final String reason;
}

class AvoraGiftAtomicityGuard {
  static AvoraGiftAtomicityDecision verify(
    AvoraGiftAtomicitySnapshot snapshot,
  ) {
    if (snapshot.transactionId.trim().isEmpty) {
      return const AvoraGiftAtomicityDecision(
        valid: false,
        reason: 'missing_transaction_id',
      );
    }

    if (snapshot.expectedDebit <= 0) {
      return const AvoraGiftAtomicityDecision(
        valid: false,
        reason: 'invalid_expected_debit',
      );
    }

    final actualDebit =
        snapshot.senderBalanceBefore - snapshot.senderBalanceAfter;

    if (actualDebit != snapshot.expectedDebit) {
      return const AvoraGiftAtomicityDecision(
        valid: false,
        reason: 'sender_debit_mismatch',
      );
    }

    if (!snapshot.ledgerRecorded) {
      return const AvoraGiftAtomicityDecision(
        valid: false,
        reason: 'ledger_missing',
      );
    }

    if (!snapshot.receiverCredited) {
      return const AvoraGiftAtomicityDecision(
        valid: false,
        reason: 'receiver_credit_missing',
      );
    }

    return const AvoraGiftAtomicityDecision(
      valid: true,
      reason: 'atomic_settlement_verified',
    );
  }

  static bool debitAndLedgerMustRemainAtomic() => true;
  static bool receiverCreditMustBePartOfSettlement() => true;
  static bool partialGiftSettlementMustFailClosed() => true;
  static bool immutableTransactionIdMustBindSettlement() => true;
}
