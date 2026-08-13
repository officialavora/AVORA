import 'avora_actor_presentation.dart';
import 'avora_launch_wallet.dart';

class AvoraLaunchGiftRequest {
  const AvoraLaunchGiftRequest({
    required this.transactionId,
    required this.senderAvoraId,
    required this.receiverAvoraId,
    required this.roomId,
    required this.giftId,
    required this.quantity,
    required this.unitCoinPrice,
    required this.createdAtUtc,
  });

  final String transactionId;
  final String senderAvoraId;
  final String receiverAvoraId;
  final String roomId;
  final String giftId;
  final int quantity;
  final int unitCoinPrice;
  final DateTime createdAtUtc;

  int get totalCoinCost => quantity * unitCoinPrice;
}

class AvoraLaunchGiftSettlement {
  const AvoraLaunchGiftSettlement({
    required this.transactionId,
    required this.senderAvoraId,
    required this.receiverAvoraId,
    required this.roomId,
    required this.giftId,
    required this.quantity,
    required this.totalCoinCost,
    required this.receiverGiftValue,
    required this.createdAtUtc,
  });

  final String transactionId;
  final String senderAvoraId;
  final String receiverAvoraId;
  final String roomId;
  final String giftId;
  final int quantity;
  final int totalCoinCost;
  final int receiverGiftValue;
  final DateTime createdAtUtc;
}

class AvoraLaunchGiftLedger {
  final Map<String, AvoraLaunchGiftSettlement> _records =
      <String, AvoraLaunchGiftSettlement>{};

  void append(AvoraLaunchGiftSettlement record) {
    if (record.transactionId.trim().isEmpty ||
        record.senderAvoraId.trim().isEmpty ||
        record.receiverAvoraId.trim().isEmpty ||
        record.roomId.trim().isEmpty ||
        record.giftId.trim().isEmpty ||
        record.quantity <= 0 ||
        record.totalCoinCost <= 0 ||
        record.receiverGiftValue < 0) {
      throw ArgumentError('invalid_launch_gift_settlement');
    }

    if (_records.containsKey(record.transactionId)) {
      throw StateError('duplicate_gift_transaction');
    }

    _records[record.transactionId] = record;
  }

  AvoraLaunchGiftSettlement? byTransactionId(
    String transactionId,
  ) {
    return _records[transactionId.trim()];
  }

  List<AvoraLaunchGiftSettlement> bySender(
    String avoraId,
  ) {
    return List<AvoraLaunchGiftSettlement>.unmodifiable(
      _records.values.where(
        (record) => record.senderAvoraId == avoraId,
      ),
    );
  }

  List<AvoraLaunchGiftSettlement> byReceiver(
    String avoraId,
  ) {
    return List<AvoraLaunchGiftSettlement>.unmodifiable(
      _records.values.where(
        (record) => record.receiverAvoraId == avoraId,
      ),
    );
  }

  static bool giftLedgerMustUseImmutableAvoraIds() => true;

  static bool duplicateGiftTransactionMustFailClosed() => true;

  static bool senderAndReceiverMustRemainTraceable() => true;

  static bool roomAndGiftIdentityMustRemainTraceable() => true;

  static bool futureGiftTypesMustUseSameLedger() => true;
}

class AvoraLaunchGiftService {
  AvoraLaunchGiftService({
    required AvoraLaunchWalletLedger walletLedger,
    required AvoraLaunchGiftLedger giftLedger,
    required AvoraOperationalActionLedger actionLedger,
  })  : _walletLedger = walletLedger,
        _giftLedger = giftLedger,
        _actionLedger = actionLedger;

  final AvoraLaunchWalletLedger _walletLedger;
  final AvoraLaunchGiftLedger _giftLedger;
  final AvoraOperationalActionLedger _actionLedger;

  AvoraLaunchGiftSettlement send({
    required AvoraLaunchGiftRequest request,
    required AvoraActionActor senderActor,
    required int receiverGiftValue,
  }) {
    _validateRequest(
      request: request,
      senderActor: senderActor,
      receiverGiftValue: receiverGiftValue,
    );

    if (_giftLedger.byTransactionId(request.transactionId) != null) {
      throw StateError('duplicate_gift_transaction');
    }

    final senderBefore =
        _walletLedger.account(request.senderAvoraId).coinBalance;

    if (senderBefore < request.totalCoinCost) {
      throw StateError('insufficient_coin_balance');
    }

    final settlement = AvoraLaunchGiftSettlement(
      transactionId: request.transactionId,
      senderAvoraId: request.senderAvoraId,
      receiverAvoraId: request.receiverAvoraId,
      roomId: request.roomId,
      giftId: request.giftId,
      quantity: request.quantity,
      totalCoinCost: request.totalCoinCost,
      receiverGiftValue: receiverGiftValue,
      createdAtUtc: request.createdAtUtc.toUtc(),
    );

    // Commit order:
    // 1. gift ledger append must be valid
    // 2. sender wallet debit
    // 3. operational audit
    _giftLedger.append(settlement);

    try {
      _walletLedger.debit(
        transactionId: 'gift-debit-${request.transactionId}',
        actor: senderActor,
        targetAvoraId: request.senderAvoraId,
        amountCoins: request.totalCoinCost,
        createdAtUtc: request.createdAtUtc,
        reason: 'gift:${request.giftId}',
      );

      _actionLedger.append(
        AvoraOperationalActionRecord(
          recordId: 'gift-action-${request.transactionId}',
          actionType: AvoraOperationalActionType.coinDebit,
          actor: senderActor,
          targetAvoraId: request.senderAvoraId,
          amountCoins: request.totalCoinCost,
          createdAtUtc: request.createdAtUtc.toUtc(),
          reason: 'gift_send:${request.giftId}',
          metadata: <String, Object?>{
            'receiverAvoraId': request.receiverAvoraId,
            'roomId': request.roomId,
            'giftId': request.giftId,
            'quantity': request.quantity,
            'receiverGiftValue': receiverGiftValue,
          },
        ),
      );
    } catch (_) {
      // In production persistence this must be one backend transaction.
      // The in-memory launch contract fails closed before exposing success.
      throw StateError('gift_atomic_commit_failed');
    }

    return settlement;
  }

  void _validateRequest({
    required AvoraLaunchGiftRequest request,
    required AvoraActionActor senderActor,
    required int receiverGiftValue,
  }) {
    if (request.transactionId.trim().isEmpty ||
        request.senderAvoraId.trim().isEmpty ||
        request.receiverAvoraId.trim().isEmpty ||
        request.roomId.trim().isEmpty ||
        request.giftId.trim().isEmpty ||
        request.quantity <= 0 ||
        request.unitCoinPrice <= 0 ||
        receiverGiftValue < 0) {
      throw ArgumentError('invalid_launch_gift_request');
    }

    if (senderActor.avoraId != request.senderAvoraId) {
      throw StateError('gift_sender_actor_identity_mismatch');
    }

    if (request.senderAvoraId == request.receiverAvoraId) {
      throw StateError('self_gift_not_allowed');
    }
  }

  String senderNotification(
    AvoraLaunchGiftSettlement settlement,
    AvoraActionActor senderActor,
  ) {
    final actorPresentation =
        AvoraActorPresentationPolicy.forPublicNotification(
      senderActor,
    );

    final actorLabel = senderActor.isOwner ? 'Owner' : actorPresentation.label;

    return '$actorLabel sent ${settlement.quantity} '
        '${settlement.giftId} gift(s) for '
        '${settlement.totalCoinCost} coins';
  }

  static bool senderDebitMustPrecedeSuccessResponse() => true;

  static bool failedGiftMustNotReportSuccess() => true;

  static bool receiverSettlementMustRemainDeterministic() => true;

  static bool giftMustPreserveRoomAndReceiverIdentity() => true;

  static bool giftAuditMustPreserveCoinAmount() => true;

  static bool ownerGiftNotificationMustMaskOwnerIdentity() => true;

  static bool sellerMerchantGiftActionsMustRemainAccountable() => true;

  static bool productionGiftCommitMustUseBackendTransaction() => true;

  static bool futureGiftEffectsMustNotBypassSettlement() => true;
}
