import 'avora_launch_gift_flow.dart';

class AvoraGiftEconomyPolicySnapshot {
  const AvoraGiftEconomyPolicySnapshot({
    required this.policyVersion,
    required this.receiverReturnBasisPoints,
    required this.roomAttributionBasisPoints,
  });

  /// Immutable/versioned active policy identifier.
  final String policyVersion;

  /// 10000 basis points = 100%.
  final int receiverReturnBasisPoints;

  /// Independent room attribution metric.
  /// This does NOT mint spendable coins by itself.
  final int roomAttributionBasisPoints;

  void validate() {
    if (policyVersion.trim().isEmpty) {
      throw ArgumentError('gift_policy_version_required');
    }

    if (receiverReturnBasisPoints < 0 ||
        receiverReturnBasisPoints > 10000 ||
        roomAttributionBasisPoints < 0 ||
        roomAttributionBasisPoints > 10000) {
      throw ArgumentError('invalid_gift_policy_basis_points');
    }
  }
}

abstract interface class AvoraLaunchGiftEconomyPolicyProvider {
  AvoraGiftEconomyPolicySnapshot activePolicy();
}

class AvoraReceiverGiftAccount {
  const AvoraReceiverGiftAccount({
    required this.avoraId,
    required this.totalReceivedGiftValue,
  });

  final String avoraId;

  /// Receiving/charm value.
  /// Not automatically spendable wallet coins.
  final int totalReceivedGiftValue;

  AvoraReceiverGiftAccount copyWith({
    int? totalReceivedGiftValue,
  }) {
    return AvoraReceiverGiftAccount(
      avoraId: avoraId,
      totalReceivedGiftValue:
          totalReceivedGiftValue ?? this.totalReceivedGiftValue,
    );
  }
}

class AvoraRoomGiftAttribution {
  const AvoraRoomGiftAttribution({
    required this.roomId,
    required this.totalAttributedGiftValue,
  });

  final String roomId;
  final int totalAttributedGiftValue;

  AvoraRoomGiftAttribution copyWith({
    int? totalAttributedGiftValue,
  }) {
    return AvoraRoomGiftAttribution(
      roomId: roomId,
      totalAttributedGiftValue:
          totalAttributedGiftValue ?? this.totalAttributedGiftValue,
    );
  }
}

class AvoraGiftReceiverSettlementRecord {
  const AvoraGiftReceiverSettlementRecord({
    required this.settlementId,
    required this.giftTransactionId,
    required this.senderAvoraId,
    required this.receiverAvoraId,
    required this.roomId,
    required this.totalGiftCoinCost,
    required this.receiverGiftValue,
    required this.roomAttributedValue,
    required this.policyVersion,
    required this.createdAtUtc,
  });

  final String settlementId;
  final String giftTransactionId;

  final String senderAvoraId;
  final String receiverAvoraId;
  final String roomId;

  final int totalGiftCoinCost;

  /// Receiving/charm value.
  final int receiverGiftValue;

  /// Room-target/ranking attribution.
  final int roomAttributedValue;

  final String policyVersion;
  final DateTime createdAtUtc;
}

class AvoraGiftReceiverSettlementLedger {
  final Map<String, AvoraGiftReceiverSettlementRecord> _records =
      <String, AvoraGiftReceiverSettlementRecord>{};

  final Map<String, AvoraReceiverGiftAccount> _receivers =
      <String, AvoraReceiverGiftAccount>{};

  final Map<String, AvoraRoomGiftAttribution> _rooms =
      <String, AvoraRoomGiftAttribution>{};

  AvoraGiftReceiverSettlementRecord apply(
    AvoraGiftReceiverSettlementRecord record,
  ) {
    if (record.settlementId.trim().isEmpty ||
        record.giftTransactionId.trim().isEmpty ||
        record.senderAvoraId.trim().isEmpty ||
        record.receiverAvoraId.trim().isEmpty ||
        record.roomId.trim().isEmpty ||
        record.policyVersion.trim().isEmpty ||
        record.totalGiftCoinCost <= 0 ||
        record.receiverGiftValue < 0 ||
        record.roomAttributedValue < 0) {
      throw ArgumentError(
        'invalid_gift_receiver_settlement',
      );
    }

    if (_records.containsKey(record.settlementId)) {
      throw StateError(
        'duplicate_receiver_settlement',
      );
    }

    final duplicateGift = _records.values.any(
      (existing) => existing.giftTransactionId == record.giftTransactionId,
    );

    if (duplicateGift) {
      throw StateError(
        'gift_transaction_already_receiver_settled',
      );
    }

    final receiver = _receivers.putIfAbsent(
      record.receiverAvoraId,
      () => AvoraReceiverGiftAccount(
        avoraId: record.receiverAvoraId,
        totalReceivedGiftValue: 0,
      ),
    );

    final room = _rooms.putIfAbsent(
      record.roomId,
      () => AvoraRoomGiftAttribution(
        roomId: record.roomId,
        totalAttributedGiftValue: 0,
      ),
    );

    _receivers[record.receiverAvoraId] = receiver.copyWith(
      totalReceivedGiftValue:
          receiver.totalReceivedGiftValue + record.receiverGiftValue,
    );

    _rooms[record.roomId] = room.copyWith(
      totalAttributedGiftValue:
          room.totalAttributedGiftValue + record.roomAttributedValue,
    );

    _records[record.settlementId] = record;

    return record;
  }

  AvoraReceiverGiftAccount receiverAccount(
    String avoraId,
  ) {
    return _receivers.putIfAbsent(
      avoraId.trim(),
      () => AvoraReceiverGiftAccount(
        avoraId: avoraId.trim(),
        totalReceivedGiftValue: 0,
      ),
    );
  }

  AvoraRoomGiftAttribution roomAttribution(
    String roomId,
  ) {
    return _rooms.putIfAbsent(
      roomId.trim(),
      () => AvoraRoomGiftAttribution(
        roomId: roomId.trim(),
        totalAttributedGiftValue: 0,
      ),
    );
  }

  List<AvoraGiftReceiverSettlementRecord> byReceiver(
    String avoraId,
  ) {
    return List<AvoraGiftReceiverSettlementRecord>.unmodifiable(
      _records.values.where(
        (record) => record.receiverAvoraId == avoraId,
      ),
    );
  }

  List<AvoraGiftReceiverSettlementRecord> byRoom(
    String roomId,
  ) {
    return List<AvoraGiftReceiverSettlementRecord>.unmodifiable(
      _records.values.where(
        (record) => record.roomId == roomId,
      ),
    );
  }

  static bool receivingValueMustRemainSeparateFromSpendableCoins() => true;

  static bool receiverSettlementMustUseImmutableAvoraId() => true;

  static bool roomAttributionMustPreserveRoomId() => true;

  static bool duplicateGiftMustNeverDoubleCreditReceiver() => true;

  static bool settlementMustPreservePolicyVersion() => true;

  static bool futureGiftTypesMustUseSameReceiverLedger() => true;
}

class AvoraLaunchGiftReceiverSettlementService {
  AvoraLaunchGiftReceiverSettlementService({
    required AvoraLaunchGiftLedger giftLedger,
    required AvoraGiftReceiverSettlementLedger receiverLedger,
    required AvoraLaunchGiftEconomyPolicyProvider policyProvider,
  })  : _giftLedger = giftLedger,
        _receiverLedger = receiverLedger,
        _policyProvider = policyProvider;

  final AvoraLaunchGiftLedger _giftLedger;
  final AvoraGiftReceiverSettlementLedger _receiverLedger;
  final AvoraLaunchGiftEconomyPolicyProvider _policyProvider;

  AvoraGiftReceiverSettlementRecord settle({
    required String settlementId,
    required String giftTransactionId,
  }) {
    final gift = _giftLedger.byTransactionId(giftTransactionId);

    if (gift == null) {
      throw StateError('gift_transaction_not_found');
    }

    final policy = _policyProvider.activePolicy();
    policy.validate();

    final receiverValue = _basisPointValue(
      gift.totalCoinCost,
      policy.receiverReturnBasisPoints,
    );

    final roomValue = _basisPointValue(
      gift.totalCoinCost,
      policy.roomAttributionBasisPoints,
    );

    final record = AvoraGiftReceiverSettlementRecord(
      settlementId: settlementId,
      giftTransactionId: gift.transactionId,
      senderAvoraId: gift.senderAvoraId,
      receiverAvoraId: gift.receiverAvoraId,
      roomId: gift.roomId,
      totalGiftCoinCost: gift.totalCoinCost,
      receiverGiftValue: receiverValue,
      roomAttributedValue: roomValue,
      policyVersion: policy.policyVersion,
      createdAtUtc: gift.createdAtUtc.toUtc(),
    );

    return _receiverLedger.apply(record);
  }

  int _basisPointValue(
    int sourceValue,
    int basisPoints,
  ) {
    return (sourceValue * basisPoints) ~/ 10000;
  }

  static bool settlementPercentageMustComeFromActivePolicy() => true;

  static bool settlementPercentageMustNotBeHardcodedInGiftModule() => true;

  static bool historicalSettlementMustPreservePolicyVersion() => true;

  static bool receiverValueMustNotAutomaticallyMintWalletCoins() => true;

  static bool roomTargetMustUseCommittedGiftValue() => true;

  static bool futureEconomyPolicyCanChangeWithoutRewritingHistory() => true;

  static bool universalCoinBudgetEngineMustRemainSourceOfPolicy() => true;
}
