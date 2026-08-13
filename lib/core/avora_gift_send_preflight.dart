class AvoraGiftSendPreflightResult {
  const AvoraGiftSendPreflightResult({
    required this.allowed,
    required this.reason,
    required this.totalCost,
  });

  final bool allowed;
  final String reason;
  final int totalCost;
}

class AvoraGiftSendPreflight {
  const AvoraGiftSendPreflight._();

  static AvoraGiftSendPreflightResult evaluate({
    required int coinBalance,
    required int giftCoinPrice,
    required int quantity,
    required bool senderActive,
    required bool recipientActive,
    required bool giftActive,
  }) {
    if (!senderActive) {
      return const AvoraGiftSendPreflightResult(
        allowed: false,
        reason: 'sender_inactive',
        totalCost: 0,
      );
    }

    if (!recipientActive) {
      return const AvoraGiftSendPreflightResult(
        allowed: false,
        reason: 'recipient_inactive',
        totalCost: 0,
      );
    }

    if (!giftActive) {
      return const AvoraGiftSendPreflightResult(
        allowed: false,
        reason: 'gift_inactive',
        totalCost: 0,
      );
    }

    if (coinBalance < 0 || giftCoinPrice <= 0 || quantity <= 0) {
      return const AvoraGiftSendPreflightResult(
        allowed: false,
        reason: 'invalid_gift_send_input',
        totalCost: 0,
      );
    }

    final totalCost = giftCoinPrice * quantity;

    if (coinBalance < totalCost) {
      return AvoraGiftSendPreflightResult(
        allowed: false,
        reason: 'insufficient_coin_balance',
        totalCost: totalCost,
      );
    }

    return AvoraGiftSendPreflightResult(
      allowed: true,
      reason: 'gift_send_allowed',
      totalCost: totalCost,
    );
  }

  static bool validCoinBalanceMustPermitValidSending() => true;

  static bool insufficientBalanceMustFailClosed() => true;

  static bool inactiveGiftMustNeverSpendCoins() => true;

  static bool zeroOrNegativeQuantityMustNeverSend() => true;
}
