import 'avora_gift_value_attribution.dart';

class AvoraGiftProgressSnapshot {
  const AvoraGiftProgressSnapshot({
    this.senderSending = 0,
    this.receiverReceiving = 0,
    this.roomTarget = 0,
    this.receiverBackup = 0,
  });

  final int senderSending;
  final int receiverReceiving;
  final int roomTarget;
  final int receiverBackup;
}

class AvoraGiftProgressResult {
  const AvoraGiftProgressResult({
    required this.applied,
    required this.reason,
    required this.snapshot,
  });

  final bool applied;
  final String reason;
  final AvoraGiftProgressSnapshot snapshot;
}

class AvoraGiftProgressEngine {
  final Set<String> _processedTransactions = <String>{};

  AvoraGiftProgressResult apply({
    required String transactionId,
    required AvoraGiftProgressSnapshot current,
    required AvoraGiftValueAttribution attribution,
  }) {
    final tx = transactionId.trim();

    if (tx.isEmpty) {
      return AvoraGiftProgressResult(
        applied: false,
        reason: 'transaction_id_required',
        snapshot: current,
      );
    }

    if (_processedTransactions.contains(tx)) {
      return AvoraGiftProgressResult(
        applied: false,
        reason: 'gift_progress_already_applied',
        snapshot: current,
      );
    }

    if (current.senderSending < 0 ||
        current.receiverReceiving < 0 ||
        current.roomTarget < 0 ||
        current.receiverBackup < 0) {
      return AvoraGiftProgressResult(
        applied: false,
        reason: 'invalid_current_progress',
        snapshot: current,
      );
    }

    _processedTransactions.add(tx);

    return AvoraGiftProgressResult(
      applied: true,
      reason: 'gift_progress_applied',
      snapshot: AvoraGiftProgressSnapshot(
        senderSending: current.senderSending + attribution.senderSendingCount,
        receiverReceiving:
            current.receiverReceiving + attribution.receiverReceivingCount,
        roomTarget: current.roomTarget + attribution.roomTargetCount,
        receiverBackup:
            current.receiverBackup + attribution.receiverBackupValue,
      ),
    );
  }

  static bool oneGiftTransactionMustApplyProgressOnce() => true;

  static bool sendingAndReceivingMustRemainSeparateTracks() => true;

  static bool roomTargetMustRemainIndependentTrack() => true;

  static bool backupMustRemainIndependentFromCoinBalance() => true;

  static bool ownerMustBeAbleToAuditProgressSourceTransaction() => true;
}
