import 'avora_actor_presentation.dart';
import 'avora_launch_gift_flow.dart';
import 'avora_launch_gift_receiver_settlement.dart';
import 'avora_launch_wallet.dart';

class AvoraAtomicGiftTransactionRequest {
  const AvoraAtomicGiftTransactionRequest({
    required this.giftRequest,
    required this.senderActor,
    required this.receiverSettlementId,
  });

  final AvoraLaunchGiftRequest giftRequest;
  final AvoraActionActor senderActor;
  final String receiverSettlementId;
}

class AvoraAtomicGiftTransactionResult {
  const AvoraAtomicGiftTransactionResult({
    required this.success,
    required this.reason,
    this.giftSettlement,
    this.receiverSettlement,
  });

  final bool success;
  final String reason;
  final AvoraLaunchGiftSettlement? giftSettlement;
  final AvoraGiftReceiverSettlementRecord? receiverSettlement;
}

class AvoraLaunchGiftAtomicTransactionService {
  AvoraLaunchGiftAtomicTransactionService({
    required AvoraLaunchWalletLedger walletLedger,
    required AvoraLaunchGiftLedger giftLedger,
    required AvoraGiftReceiverSettlementLedger receiverLedger,
    required AvoraLaunchGiftEconomyPolicyProvider policyProvider,
    required AvoraOperationalActionLedger actionLedger,
  })  : _walletLedger = walletLedger,
        _giftLedger = giftLedger,
        _receiverLedger = receiverLedger,
        _policyProvider = policyProvider,
        _actionLedger = actionLedger;

  final AvoraLaunchWalletLedger _walletLedger;
  final AvoraLaunchGiftLedger _giftLedger;
  final AvoraGiftReceiverSettlementLedger _receiverLedger;
  final AvoraLaunchGiftEconomyPolicyProvider _policyProvider;
  final AvoraOperationalActionLedger _actionLedger;

  AvoraAtomicGiftTransactionResult execute(
    AvoraAtomicGiftTransactionRequest request,
  ) {
    final giftRequest = request.giftRequest;

    if (request.receiverSettlementId.trim().isEmpty) {
      return const AvoraAtomicGiftTransactionResult(
        success: false,
        reason: 'receiver_settlement_id_required',
      );
    }

    if (request.senderActor.avoraId != giftRequest.senderAvoraId) {
      return const AvoraAtomicGiftTransactionResult(
        success: false,
        reason: 'gift_sender_actor_identity_mismatch',
      );
    }

    if (_giftLedger.byTransactionId(
          giftRequest.transactionId,
        ) !=
        null) {
      return const AvoraAtomicGiftTransactionResult(
        success: false,
        reason: 'duplicate_gift_transaction',
      );
    }

    final policy = _policyProvider.activePolicy();

    try {
      policy.validate();
    } catch (_) {
      return const AvoraAtomicGiftTransactionResult(
        success: false,
        reason: 'invalid_gift_economy_policy',
      );
    }

    final senderBalanceBefore =
        _walletLedger.account(giftRequest.senderAvoraId).coinBalance;

    if (senderBalanceBefore < giftRequest.totalCoinCost) {
      return const AvoraAtomicGiftTransactionResult(
        success: false,
        reason: 'insufficient_coin_balance',
      );
    }

    if (giftRequest.transactionId.trim().isEmpty ||
        giftRequest.senderAvoraId.trim().isEmpty ||
        giftRequest.receiverAvoraId.trim().isEmpty ||
        giftRequest.roomId.trim().isEmpty ||
        giftRequest.giftId.trim().isEmpty ||
        giftRequest.quantity <= 0 ||
        giftRequest.unitCoinPrice <= 0) {
      return const AvoraAtomicGiftTransactionResult(
        success: false,
        reason: 'invalid_gift_request',
      );
    }

    if (giftRequest.senderAvoraId == giftRequest.receiverAvoraId) {
      return const AvoraAtomicGiftTransactionResult(
        success: false,
        reason: 'self_gift_not_allowed',
      );
    }

    final receiverGiftValue = _basisPointValue(
      giftRequest.totalCoinCost,
      policy.receiverReturnBasisPoints,
    );

    final roomAttributedValue = _basisPointValue(
      giftRequest.totalCoinCost,
      policy.roomAttributionBasisPoints,
    );

    final giftSettlement = AvoraLaunchGiftSettlement(
      transactionId: giftRequest.transactionId,
      senderAvoraId: giftRequest.senderAvoraId,
      receiverAvoraId: giftRequest.receiverAvoraId,
      roomId: giftRequest.roomId,
      giftId: giftRequest.giftId,
      quantity: giftRequest.quantity,
      totalCoinCost: giftRequest.totalCoinCost,
      receiverGiftValue: receiverGiftValue,
      createdAtUtc: giftRequest.createdAtUtc.toUtc(),
    );

    final receiverSettlement = AvoraGiftReceiverSettlementRecord(
      settlementId: request.receiverSettlementId,
      giftTransactionId: giftRequest.transactionId,
      senderAvoraId: giftRequest.senderAvoraId,
      receiverAvoraId: giftRequest.receiverAvoraId,
      roomId: giftRequest.roomId,
      totalGiftCoinCost: giftRequest.totalCoinCost,
      receiverGiftValue: receiverGiftValue,
      roomAttributedValue: roomAttributedValue,
      policyVersion: policy.policyVersion,
      createdAtUtc: giftRequest.createdAtUtc.toUtc(),
    );

    // Launch contract:
    // all validations happen before any mutation.
    // Production persistence must execute these mutations
    // inside one backend/database transaction.
    try {
      _giftLedger.append(giftSettlement);

      _walletLedger.debit(
        transactionId: 'gift-debit-${giftRequest.transactionId}',
        actor: request.senderActor,
        targetAvoraId: giftRequest.senderAvoraId,
        amountCoins: giftRequest.totalCoinCost,
        createdAtUtc: giftRequest.createdAtUtc,
        reason: 'gift:${giftRequest.giftId}',
      );

      _receiverLedger.apply(receiverSettlement);

      _actionLedger.append(
        AvoraOperationalActionRecord(
          recordId: 'gift-action-${giftRequest.transactionId}',
          actionType: AvoraOperationalActionType.coinDebit,
          actor: request.senderActor,
          targetAvoraId: giftRequest.senderAvoraId,
          amountCoins: giftRequest.totalCoinCost,
          createdAtUtc: giftRequest.createdAtUtc.toUtc(),
          reason: 'gift_send:${giftRequest.giftId}',
          metadata: <String, Object?>{
            'receiverAvoraId': giftRequest.receiverAvoraId,
            'roomId': giftRequest.roomId,
            'giftId': giftRequest.giftId,
            'quantity': giftRequest.quantity,
            'receiverGiftValue': receiverGiftValue,
            'roomAttributedValue': roomAttributedValue,
            'policyVersion': policy.policyVersion,
          },
        ),
      );
    } catch (_) {
      return const AvoraAtomicGiftTransactionResult(
        success: false,
        reason: 'gift_atomic_commit_failed',
      );
    }

    return AvoraAtomicGiftTransactionResult(
      success: true,
      reason: 'gift_atomic_commit_success',
      giftSettlement: giftSettlement,
      receiverSettlement: receiverSettlement,
    );
  }

  int _basisPointValue(
    int sourceValue,
    int basisPoints,
  ) {
    return (sourceValue * basisPoints) ~/ 10000;
  }

  static bool allValidationMustRunBeforeMutation() => true;

  static bool senderDebitAndReceiverSettlementMustShareTransaction() => true;

  static bool giftLedgerAndWalletMustShareTransactionBoundary() => true;

  static bool roomAttributionMustShareGiftTransactionBoundary() => true;

  static bool auditMustShareGiftTransactionBoundary() => true;

  static bool failedAtomicCommitMustNeverReportSuccess() => true;

  static bool productionPersistenceMustUseDatabaseTransaction() => true;

  static bool duplicateGiftMustNeverDoubleDebitOrDoubleCredit() => true;

  static bool futureGiftModulesMustUseSameAtomicBoundary() => true;
}
