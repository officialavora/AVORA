enum AvoraGenericGiftBroadcastScope {
  none,
  room,
  global,
}

class AvoraGiftBroadcastPolicy {
  const AvoraGiftBroadcastPolicy({
    this.enabled = true,
    this.defaultRoomMinimumTotalCoinValue,
    this.defaultGlobalMinimumTotalCoinValue,
    this.defaultRoomMinimumCombo,
    this.defaultGlobalMinimumCombo,
    this.roomMinimumTotalCoinValueByGiftId = const {},
    this.globalMinimumTotalCoinValueByGiftId = const {},
    this.roomMinimumComboByGiftId = const {},
    this.globalMinimumComboByGiftId = const {},
    this.broadcastDisabledGiftIds = const {},
    this.requireServerVerifiedGift = true,
    this.roomDurationSeconds = 5,
    this.globalDurationSeconds = 8,
  });

  final bool enabled;

  /// Owner-editable default threshold for ANY eligible gift.
  /// null = value-based room trigger disabled unless gift override exists.
  final int? defaultRoomMinimumTotalCoinValue;

  /// Owner-editable global threshold.
  /// null = value-based global trigger disabled unless override exists.
  final int? defaultGlobalMinimumTotalCoinValue;

  /// Optional combo-based triggers.
  final int? defaultRoomMinimumCombo;
  final int? defaultGlobalMinimumCombo;

  /// Per-gift Owner overrides.
  ///
  /// Example:
  /// gift-A -> 50000
  /// gift-B -> 500000
  ///
  /// These are policy values, not hardcoded business constants.
  final Map<String, int> roomMinimumTotalCoinValueByGiftId;
  final Map<String, int> globalMinimumTotalCoinValueByGiftId;

  final Map<String, int> roomMinimumComboByGiftId;
  final Map<String, int> globalMinimumComboByGiftId;

  /// Gifts that should never create a broadcast even if expensive.
  final Set<String> broadcastDisabledGiftIds;

  final bool requireServerVerifiedGift;

  final int roomDurationSeconds;
  final int globalDurationSeconds;
}

class AvoraGiftBroadcastInput {
  const AvoraGiftBroadcastInput({
    required this.eventId,
    required this.roomId,
    required this.giftId,
    required this.senderAvoraId,
    required this.receiverAvoraId,
    required this.resolvedUnitCoinValue,
    required this.quantity,
    required this.comboCount,
    required this.serverVerifiedGift,
    required this.createdAt,
  });

  final String eventId;
  final String roomId;
  final String giftId;

  final String senderAvoraId;
  final String receiverAvoraId;

  /// MUST come from the existing authoritative Gift Catalog /
  /// Gift Value Policy for this transaction.
  ///
  /// Never trust a price sent by the mobile client.
  final int resolvedUnitCoinValue;

  final int quantity;
  final int comboCount;

  final bool serverVerifiedGift;
  final DateTime createdAt;

  int get totalCoinValue {
    if (resolvedUnitCoinValue <= 0 || quantity <= 0) return 0;
    return resolvedUnitCoinValue * quantity;
  }
}

class AvoraGiftBroadcastDecision {
  const AvoraGiftBroadcastDecision({
    required this.scope,
    required this.eligible,
    required this.reason,
    required this.durationSeconds,
    required this.resolvedTotalCoinValue,
  });

  final AvoraGenericGiftBroadcastScope scope;
  final bool eligible;
  final String reason;
  final int durationSeconds;

  /// Value snapshot used for this broadcast decision.
  final int resolvedTotalCoinValue;
}

class AvoraGiftBroadcastPolicyEngine {
  static AvoraGiftBroadcastDecision evaluate({
    required AvoraGiftBroadcastPolicy policy,
    required AvoraGiftBroadcastInput input,
  }) {
    if (!policy.enabled) {
      return _deny('policyDisabled', input.totalCoinValue);
    }

    if (input.eventId.trim().isEmpty ||
        input.roomId.trim().isEmpty ||
        input.giftId.trim().isEmpty ||
        input.senderAvoraId.trim().isEmpty ||
        input.receiverAvoraId.trim().isEmpty) {
      return _deny('missingAuthoritativeIdentity', input.totalCoinValue);
    }

    if (policy.requireServerVerifiedGift && !input.serverVerifiedGift) {
      return _deny('giftNotServerVerified', input.totalCoinValue);
    }

    if (input.resolvedUnitCoinValue <= 0 || input.quantity <= 0) {
      return _deny('invalidResolvedGiftValue', input.totalCoinValue);
    }

    if (policy.broadcastDisabledGiftIds.contains(input.giftId)) {
      return _deny('giftBroadcastDisabled', input.totalCoinValue);
    }

    final globalValueThreshold =
        policy.globalMinimumTotalCoinValueByGiftId[input.giftId] ??
            policy.defaultGlobalMinimumTotalCoinValue;

    final globalComboThreshold =
        policy.globalMinimumComboByGiftId[input.giftId] ??
            policy.defaultGlobalMinimumCombo;

    final globalValueMet = globalValueThreshold != null &&
        input.totalCoinValue >= globalValueThreshold;

    final globalComboMet = globalComboThreshold != null &&
        input.comboCount >= globalComboThreshold;

    if (globalValueMet || globalComboMet) {
      return AvoraGiftBroadcastDecision(
        scope: AvoraGenericGiftBroadcastScope.global,
        eligible: true,
        reason: globalValueMet
            ? 'globalGiftValueThresholdMet'
            : 'globalGiftComboThresholdMet',
        durationSeconds: policy.globalDurationSeconds,
        resolvedTotalCoinValue: input.totalCoinValue,
      );
    }

    final roomValueThreshold =
        policy.roomMinimumTotalCoinValueByGiftId[input.giftId] ??
            policy.defaultRoomMinimumTotalCoinValue;

    final roomComboThreshold = policy.roomMinimumComboByGiftId[input.giftId] ??
        policy.defaultRoomMinimumCombo;

    final roomValueMet = roomValueThreshold != null &&
        input.totalCoinValue >= roomValueThreshold;

    final roomComboMet =
        roomComboThreshold != null && input.comboCount >= roomComboThreshold;

    if (roomValueMet || roomComboMet) {
      return AvoraGiftBroadcastDecision(
        scope: AvoraGenericGiftBroadcastScope.room,
        eligible: true,
        reason: roomValueMet
            ? 'roomGiftValueThresholdMet'
            : 'roomGiftComboThresholdMet',
        durationSeconds: policy.roomDurationSeconds,
        resolvedTotalCoinValue: input.totalCoinValue,
      );
    }

    return _deny(
      'giftBroadcastThresholdNotMet',
      input.totalCoinValue,
    );
  }

  static AvoraGiftBroadcastDecision _deny(
    String reason,
    int totalCoinValue,
  ) {
    return AvoraGiftBroadcastDecision(
      scope: AvoraGenericGiftBroadcastScope.none,
      eligible: false,
      reason: reason,
      durationSeconds: 0,
      resolvedTotalCoinValue: totalCoinValue,
    );
  }

  /// Gift price comes from the existing authoritative catalog/value policy.
  static bool requiresAuthoritativeResolvedGiftValue() => true;

  /// Mobile client can never change authoritative gift value.
  static bool clientCanChangeGiftValue() => false;

  /// Changing today's gift price must not rewrite old transaction history.
  static bool historicalGiftValueUsesTransactionSnapshot() => true;

  /// Thresholds belong to Owner-editable/versioned backend policy.
  static bool broadcastThresholdsAreOwnerConfigurable() => true;

  /// Room and global broadcast thresholds may be different.
  static bool roomAndGlobalThresholdsAreIndependent() => true;
}
