class AvoraGiftValueAttribution {
  const AvoraGiftValueAttribution({
    required this.eligibleGiftValue,
    required this.senderSendingCount,
    required this.receiverReceivingCount,
    required this.roomTargetCount,
    required this.receiverBackupValue,
  });

  final int eligibleGiftValue;

  /// Full eligible value counted toward sender's sending progress.
  final int senderSendingCount;

  /// Full eligible value counted toward receiver's receiving progress.
  final int receiverReceivingCount;

  /// Full eligible value counted toward eligible room target.
  final int roomTargetCount;

  /// Full eligible value stored as receiver backup/diamond representation base.
  ///
  /// IMPORTANT:
  /// This is NOT the Diamond -> Coin exchange payout.
  /// Exchange percentage is a separate policy.
  final int receiverBackupValue;

  static AvoraGiftValueAttribution fromEligibleGift({
    required int eligibleGiftValue,
    required bool countForSending,
    required bool countForReceiving,
    required bool countForRoomTarget,
    required bool countForReceiverBackup,
  }) {
    if (eligibleGiftValue <= 0) {
      throw ArgumentError('eligible_gift_value_must_be_positive');
    }

    return AvoraGiftValueAttribution(
      eligibleGiftValue: eligibleGiftValue,
      senderSendingCount: countForSending ? eligibleGiftValue : 0,
      receiverReceivingCount: countForReceiving ? eligibleGiftValue : 0,
      roomTargetCount: countForRoomTarget ? eligibleGiftValue : 0,
      receiverBackupValue: countForReceiverBackup ? eligibleGiftValue : 0,
    );
  }

  static bool eligibleGiftMayCountAtFullFaceValue() => true;

  static bool backupValueMustRemainSeparateFromExchangePayout() => true;

  static bool roomRewardMustRemainSeparateFromBackupValue() => true;

  static bool salaryMustRemainSeparateFromGiftValue() => true;

  static bool attributionPolicyMustRemainOwnerConfigurable() => true;
}
