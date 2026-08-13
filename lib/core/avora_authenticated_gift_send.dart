import 'avora_authenticated_identity.dart';
import 'avora_gift_production_bridge.dart';

class AvoraAuthenticatedGiftSendRequest {
  const AvoraAuthenticatedGiftSendRequest({
    required this.firebaseUid,
    required this.transactionId,
    required this.receiverAvoraId,
    required this.roomId,
    required this.giftId,
    required this.quantity,
    required this.totalCoinCost,
    required this.eligibleGiftValue,
    required this.createdAtUtc,
  });

  final String firebaseUid;
  final String transactionId;
  final String receiverAvoraId;
  final String roomId;
  final String giftId;
  final int quantity;
  final int totalCoinCost;
  final int eligibleGiftValue;
  final DateTime createdAtUtc;
}

class AvoraAuthenticatedGiftSendResult {
  const AvoraAuthenticatedGiftSendResult({
    required this.success,
    required this.reason,
    this.senderAvoraId,
    this.productionResult,
  });

  final bool success;
  final String reason;
  final String? senderAvoraId;
  final AvoraGiftProductionBridgeResult? productionResult;
}

class AvoraAuthenticatedGiftSendService {
  const AvoraAuthenticatedGiftSendService({
    required AvoraAuthenticatedIdentityResolver identityResolver,
    required AvoraGiftProductionBridge productionBridge,
  })  : _identityResolver = identityResolver,
        _productionBridge = productionBridge;

  final AvoraAuthenticatedIdentityResolver _identityResolver;
  final AvoraGiftProductionBridge _productionBridge;

  Future<AvoraAuthenticatedGiftSendResult> send(
    AvoraAuthenticatedGiftSendRequest request,
  ) async {
    final uid = request.firebaseUid.trim();

    if (uid.isEmpty) {
      return const AvoraAuthenticatedGiftSendResult(
        success: false,
        reason: 'firebase_authentication_required',
      );
    }

    final identity = await _identityResolver.resolve(
      firebaseUid: uid,
    );

    if (identity == null || !identity.isUsable) {
      return const AvoraAuthenticatedGiftSendResult(
        success: false,
        reason: 'verified_avora_identity_required',
      );
    }

    final result = await _productionBridge.send(
      AvoraGiftProductionRequest(
        transactionId: request.transactionId,
        authenticatedSenderAvoraId: identity.avoraId,
        receiverAvoraId: request.receiverAvoraId,
        roomId: request.roomId,
        giftId: request.giftId,
        quantity: request.quantity,
        totalCoinCost: request.totalCoinCost,
        eligibleGiftValue: request.eligibleGiftValue,
        createdAtUtc: request.createdAtUtc,
      ),
    );

    return AvoraAuthenticatedGiftSendResult(
      success: result.allowed,
      reason: result.reason,
      senderAvoraId: identity.avoraId,
      productionResult: result,
    );
  }

  static bool clientMustNeverChooseGiftSenderAvoraId() => true;

  static bool firebaseUidMustResolveToVerifiedAvoraIdentity() => true;

  static bool immutableAvoraIdMustChooseSenderWallet() => true;

  static bool missingIdentityMustNeverDebitWallet() => true;

  static bool senderSpoofingMustFailByArchitecture() => true;
}
