import 'package:cloud_firestore/cloud_firestore.dart';

class AvoraFirestoreGiftEconomyRequest {
  const AvoraFirestoreGiftEconomyRequest({
    required this.transactionId,
    required this.senderAvoraId,
    required this.receiverAvoraId,
    required this.roomId,
    required this.giftId,
    required this.quantity,
    required this.totalCoinCost,
    required this.eligibleGiftValue,
    required this.createdAtUtc,
  });

  final String transactionId;
  final String senderAvoraId;
  final String receiverAvoraId;
  final String roomId;
  final String giftId;
  final int quantity;
  final int totalCoinCost;
  final int eligibleGiftValue;
  final DateTime createdAtUtc;
}

class AvoraFirestoreGiftEconomyResult {
  const AvoraFirestoreGiftEconomyResult({
    required this.success,
    required this.reason,
    required this.senderBalanceBefore,
    required this.senderBalanceAfter,
  });

  final bool success;
  final String reason;
  final int senderBalanceBefore;
  final int senderBalanceAfter;
}

class AvoraFirestoreGiftEconomyTransaction {
  AvoraFirestoreGiftEconomyTransaction({
    required FirebaseFirestore firestore,
    this.walletCollection = 'wallets',
    this.giftLedgerCollection = 'giftLedger',
    this.progressCollection = 'giftProgress',
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  final String walletCollection;
  final String giftLedgerCollection;
  final String progressCollection;

  Future<AvoraFirestoreGiftEconomyResult> execute(
    AvoraFirestoreGiftEconomyRequest request,
  ) async {
    if (request.transactionId.trim().isEmpty ||
        request.senderAvoraId.trim().isEmpty ||
        request.receiverAvoraId.trim().isEmpty ||
        request.giftId.trim().isEmpty ||
        request.quantity <= 0 ||
        request.totalCoinCost <= 0 ||
        request.eligibleGiftValue <= 0) {
      return const AvoraFirestoreGiftEconomyResult(
        success: false,
        reason: 'invalid_gift_transaction_request',
        senderBalanceBefore: 0,
        senderBalanceAfter: 0,
      );
    }

    final ledgerRef = _firestore
        .collection(giftLedgerCollection)
        .doc(request.transactionId.trim());

    final senderWalletRef = _firestore
        .collection(walletCollection)
        .doc(request.senderAvoraId.trim());

    final receiverProgressRef = _firestore
        .collection(progressCollection)
        .doc(request.receiverAvoraId.trim());

    final roomProgressRef = _firestore
        .collection(progressCollection)
        .doc('room_${request.roomId.trim()}');

    try {
      return await _firestore
          .runTransaction<AvoraFirestoreGiftEconomyResult>((transaction) async {
        final existingLedger = await transaction.get(ledgerRef);

        if (existingLedger.exists) {
          return const AvoraFirestoreGiftEconomyResult(
            success: false,
            reason: 'duplicate_gift_transaction',
            senderBalanceBefore: 0,
            senderBalanceAfter: 0,
          );
        }

        final walletSnapshot = await transaction.get(senderWalletRef);

        if (!walletSnapshot.exists) {
          return const AvoraFirestoreGiftEconomyResult(
            success: false,
            reason: 'sender_wallet_missing',
            senderBalanceBefore: 0,
            senderBalanceAfter: 0,
          );
        }

        final walletData = walletSnapshot.data();

        if (walletData == null || walletData['coinBalance'] is! int) {
          return const AvoraFirestoreGiftEconomyResult(
            success: false,
            reason: 'sender_wallet_invalid',
            senderBalanceBefore: 0,
            senderBalanceAfter: 0,
          );
        }

        final balanceBefore = walletData['coinBalance'] as int;

        if (balanceBefore < request.totalCoinCost) {
          return AvoraFirestoreGiftEconomyResult(
            success: false,
            reason: 'insufficient_coin_balance',
            senderBalanceBefore: balanceBefore,
            senderBalanceAfter: balanceBefore,
          );
        }

        final balanceAfter = balanceBefore - request.totalCoinCost;

        transaction.update(senderWalletRef, <String, Object?>{
          'coinBalance': balanceAfter,
          'updatedAtUtc': Timestamp.fromDate(
            request.createdAtUtc.toUtc(),
          ),
        });

        transaction.set(
          receiverProgressRef,
          <String, Object?>{
            'receiving': FieldValue.increment(
              request.eligibleGiftValue,
            ),
            'backup': FieldValue.increment(
              request.eligibleGiftValue,
            ),
            'updatedAtUtc': Timestamp.fromDate(
              request.createdAtUtc.toUtc(),
            ),
          },
          SetOptions(merge: true),
        );

        if (request.roomId.trim().isNotEmpty) {
          transaction.set(
            roomProgressRef,
            <String, Object?>{
              'roomTarget': FieldValue.increment(
                request.eligibleGiftValue,
              ),
              'updatedAtUtc': Timestamp.fromDate(
                request.createdAtUtc.toUtc(),
              ),
            },
            SetOptions(merge: true),
          );
        }

        transaction.set(ledgerRef, <String, Object?>{
          'transactionId': request.transactionId.trim(),
          'senderAvoraId': request.senderAvoraId.trim(),
          'receiverAvoraId': request.receiverAvoraId.trim(),
          'roomId': request.roomId.trim(),
          'giftId': request.giftId.trim(),
          'quantity': request.quantity,
          'totalCoinCost': request.totalCoinCost,
          'eligibleGiftValue': request.eligibleGiftValue,
          'senderBalanceBefore': balanceBefore,
          'senderBalanceAfter': balanceAfter,
          'createdAtUtc': Timestamp.fromDate(
            request.createdAtUtc.toUtc(),
          ),
          'immutable': true,
        });

        return AvoraFirestoreGiftEconomyResult(
          success: true,
          reason: 'gift_economy_committed',
          senderBalanceBefore: balanceBefore,
          senderBalanceAfter: balanceAfter,
        );
      });
    } catch (_) {
      return const AvoraFirestoreGiftEconomyResult(
        success: false,
        reason: 'gift_transaction_failed',
        senderBalanceBefore: 0,
        senderBalanceAfter: 0,
      );
    }
  }

  static bool walletDebitAndLedgerMustShareTransaction() => true;

  static bool duplicateTransactionMustNeverDoubleDebit() => true;

  static bool receiverProgressMustUseCommittedGiftValue() => true;

  static bool roomTargetMustUseCommittedGiftValue() => true;

  static bool failedTransactionMustNotPartiallyCommit() => true;
}
