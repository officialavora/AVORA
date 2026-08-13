enum AvoraEconomyContext {
  room,
  inbox,
  family,
  global,
  event,
}

enum AvoraGiftKind {
  standard,
  lucky,
}

enum AvoraGiftTransactionStatus {
  pending,
  confirmed,
  failed,
  reversed,
}

class AvoraGiftTransaction {
  final String id;

  final String senderUserId;
  final String receiverUserId;

  final String giftId;

  final AvoraGiftKind kind;

  /// Room ID, inbox conversation ID, family ID, event ID, etc.
  final String contextId;

  final AvoraEconomyContext context;

  /// Price of one gift in coins.
  final int unitPrice;

  /// Combo / hit quantity.
  final int quantity;

  /// Immutable funded/spent total for this transaction.
  final int totalAmount;

  final AvoraGiftTransactionStatus status;

  final DateTime createdAt;
  final DateTime? confirmedAt;

  /// Server ledger entry/reference.
  final String? ledgerRef;

  const AvoraGiftTransaction({
    required this.id,
    required this.senderUserId,
    required this.receiverUserId,
    required this.giftId,
    this.kind = AvoraGiftKind.standard,
    required this.contextId,
    required this.context,
    required this.unitPrice,
    required this.quantity,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.confirmedAt,
    this.ledgerRef,
  })  : assert(unitPrice > 0),
        assert(quantity > 0),
        assert(totalAmount > 0),
        assert(
          totalAmount == unitPrice * quantity,
          'totalAmount must equal unitPrice * quantity',
        );

  bool get isSelfGift => senderUserId == receiverUserId;

  bool get isRoomGift => context == AvoraEconomyContext.room;

  bool get isInboxGift => context == AvoraEconomyContext.inbox;

  bool get isConfirmed => status == AvoraGiftTransactionStatus.confirmed;

  /// Self-gifts stay valid economy transactions,
  /// but reward/host/ranking systems can exclude them.
  bool get eligibleForStandardRewardCredit => isConfirmed && !isSelfGift;
}

class AvoraGiftSendRequest {
  final String senderUserId;
  final String receiverUserId;

  final String giftId;

  final AvoraGiftKind kind;
  final String contextId;

  final AvoraEconomyContext context;

  final int unitPrice;
  final int quantity;

  const AvoraGiftSendRequest({
    required this.senderUserId,
    required this.receiverUserId,
    required this.giftId,
    this.kind = AvoraGiftKind.standard,
    required this.contextId,
    required this.context,
    required this.unitPrice,
    this.quantity = 1,
  })  : assert(unitPrice > 0),
        assert(quantity > 0);

  int get totalAmount => unitPrice * quantity;

  bool get isSelfGift => senderUserId == receiverUserId;
}
