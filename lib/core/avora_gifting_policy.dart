import 'avora_gifting.dart';

enum AvoraGiftDenyReason {
  none,
  contextDisabled,
  blockedByRecipient,
  selfGiftDisabled,
  invalidContext,
}

enum AvoraGiftCreditType {
  sendingLevel,
  receivingLevel,
  wealthRanking,
  charmRanking,
  hostTarget,
  agencyTarget,
  roomTarget,
}

class AvoraGiftPolicyConfig {
  final bool allowRoomGift;
  final bool allowInboxGift;
  final bool allowFamilyGift;
  final bool allowGlobalGift;
  final bool allowEventGift;

  final bool allowSelfGift;

  const AvoraGiftPolicyConfig({
    this.allowRoomGift = true,
    this.allowInboxGift = true,
    this.allowFamilyGift = true,
    this.allowGlobalGift = true,
    this.allowEventGift = true,
    this.allowSelfGift = true,
  });
}

class AvoraGiftPolicyDecision {
  final bool allowed;
  final AvoraGiftDenyReason reason;

  const AvoraGiftPolicyDecision({
    required this.allowed,
    required this.reason,
  });

  const AvoraGiftPolicyDecision.allow()
      : allowed = true,
        reason = AvoraGiftDenyReason.none;

  const AvoraGiftPolicyDecision.deny(
    AvoraGiftDenyReason denyReason,
  )   : allowed = false,
        reason = denyReason;
}

class AvoraGiftPolicy {
  const AvoraGiftPolicy._();

  static AvoraGiftPolicyDecision canSend({
    required AvoraGiftSendRequest request,
    AvoraGiftPolicyConfig config = const AvoraGiftPolicyConfig(),

    /// True when recipient has blocked the sender.
    bool recipientBlocksSender = false,
  }) {
    if (request.contextId.trim().isEmpty) {
      return const AvoraGiftPolicyDecision.deny(
        AvoraGiftDenyReason.invalidContext,
      );
    }

    if (!_contextEnabled(request.context, config)) {
      return const AvoraGiftPolicyDecision.deny(
        AvoraGiftDenyReason.contextDisabled,
      );
    }

    if (recipientBlocksSender) {
      return const AvoraGiftPolicyDecision.deny(
        AvoraGiftDenyReason.blockedByRecipient,
      );
    }

    if (request.isSelfGift && !config.allowSelfGift) {
      return const AvoraGiftPolicyDecision.deny(
        AvoraGiftDenyReason.selfGiftDisabled,
      );
    }

    return const AvoraGiftPolicyDecision.allow();
  }

  static bool eligibleForCredit({
    required AvoraGiftTransaction transaction,
    required AvoraGiftCreditType creditType,
  }) {
    if (!transaction.isConfirmed) {
      return false;
    }

    if (transaction.isSelfGift) {
      /// Real coin spend may still advance sender progression,
      /// but self-gifting must not farm receiver/ranking/work targets.
      return creditType == AvoraGiftCreditType.sendingLevel;
    }

    switch (creditType) {
      case AvoraGiftCreditType.sendingLevel:
      case AvoraGiftCreditType.receivingLevel:
      case AvoraGiftCreditType.wealthRanking:
      case AvoraGiftCreditType.charmRanking:
        return true;

      case AvoraGiftCreditType.hostTarget:
      case AvoraGiftCreditType.agencyTarget:
      case AvoraGiftCreditType.roomTarget:

        /// Work/room targets count Room gifts by default.
        /// Inbox gifting remains personal gifting.
        return transaction.context == AvoraEconomyContext.room;
    }
  }

  static bool _contextEnabled(
    AvoraEconomyContext context,
    AvoraGiftPolicyConfig config,
  ) {
    switch (context) {
      case AvoraEconomyContext.room:
        return config.allowRoomGift;

      case AvoraEconomyContext.inbox:
        return config.allowInboxGift;

      case AvoraEconomyContext.family:
        return config.allowFamilyGift;

      case AvoraEconomyContext.global:
        return config.allowGlobalGift;

      case AvoraEconomyContext.event:
        return config.allowEventGift;
    }
  }
}
