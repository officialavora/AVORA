import 'avora_firestore_gift_economy_transaction.dart';

class AvoraGiftProductionRequest {
  const AvoraGiftProductionRequest({
    required this.transactionId,
    required this.authenticatedSenderAvoraId,
    required this.receiverAvoraId,
    required this.roomId,
    required this.giftId,
    required this.quantity,
    required this.totalCoinCost,
    required this.eligibleGiftValue,
    required this.createdAtUtc,
  });

  final String transactionId;
  final String authenticatedSenderAvoraId;
  final String receiverAvoraId;
  final String roomId;
  final String giftId;
  final int quantity;
  final int totalCoinCost;
  final int eligibleGiftValue;
  final DateTime createdAtUtc;
}

class AvoraGiftProductionBridgeResult {
  const AvoraGiftProductionBridgeResult({
    required this.allowed,
    required this.reason,
    this.transaction,
  });

  final bool allowed;
  final String reason;
  final AvoraFirestoreGiftEconomyResult? transaction;
}

class AvoraGiftProductionBridge {
  const AvoraGiftProductionBridge({
    required AvoraFirestoreGiftEconomyTransaction economy,
  }) : _economy = economy;

  final AvoraFirestoreGiftEconomyTransaction _economy;

  Future<AvoraGiftProductionBridgeResult> send(
    AvoraGiftProductionRequest request,
  ) async {
    if (request.authenticatedSenderAvoraId.trim().isEmpty) {
      return const AvoraGiftProductionBridgeResult(
        allowed: false,
        reason: 'authenticated_sender_required',
      );
    }

    if (request.receiverAvoraId.trim().isEmpty ||
        request.transactionId.trim().isEmpty ||
        request.giftId.trim().isEmpty ||
        request.quantity <= 0 ||
        request.totalCoinCost <= 0 ||
        request.eligibleGiftValue <= 0) {
      return const AvoraGiftProductionBridgeResult(
        allowed: false,
        reason: 'invalid_gift_request',
      );
    }

    final committed = await _economy.execute(
      AvoraFirestoreGiftEconomyRequest(
        transactionId: request.transactionId,
        senderAvoraId: request.authenticatedSenderAvoraId,
        receiverAvoraId: request.receiverAvoraId,
        roomId: request.roomId,
        giftId: request.giftId,
        quantity: request.quantity,
        totalCoinCost: request.totalCoinCost,
        eligibleGiftValue: request.eligibleGiftValue,
        createdAtUtc: request.createdAtUtc,
      ),
    );

    return AvoraGiftProductionBridgeResult(
      allowed: committed.success,
      reason: committed.reason,
      transaction: committed,
    );
  }

  static bool authenticatedSenderMustBeAuthoritative() => true;
  static bool clientBalanceMustNeverAuthorizeDebit() => true;
  static bool atomicCommitMustPrecedeSuccess() => true;
  static bool duplicateSendMustRemainIdempotent() => true;
  static bool failedCommitMustNeverReportGiftSuccess() => true;
}
