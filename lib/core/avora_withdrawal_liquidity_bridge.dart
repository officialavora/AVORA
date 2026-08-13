import 'avora_settlement_liquidity_wallet.dart';

enum AvoraWithdrawalLiquidityDenyReason {
  none,
  walletMissing,
  walletOwnerMismatch,
  walletInactive,
  currencyMismatch,
  invalidAmount,
  insufficientLiquidity,
}

class AvoraWithdrawalLiquidityDecision {
  const AvoraWithdrawalLiquidityDecision({
    required this.allowed,
    required this.reason,
    this.reservedWallet,
  });

  final bool allowed;
  final AvoraWithdrawalLiquidityDenyReason reason;
  final AvoraSettlementLiquidityWallet? reservedWallet;
}

class AvoraWithdrawalLiquidityBridge {
  static AvoraWithdrawalLiquidityDecision reserveForAcceptedOrder({
    required String acceptingAgentAvoraId,
    required String currencyCode,
    required int amountMinor,
    required DateTime now,
    required AvoraSettlementLiquidityWallet? wallet,
  }) {
    if (wallet == null) {
      return const AvoraWithdrawalLiquidityDecision(
        allowed: false,
        reason: AvoraWithdrawalLiquidityDenyReason.walletMissing,
      );
    }

    if (wallet.ownerAvoraId != acceptingAgentAvoraId) {
      return const AvoraWithdrawalLiquidityDecision(
        allowed: false,
        reason: AvoraWithdrawalLiquidityDenyReason.walletOwnerMismatch,
      );
    }

    if (wallet.status != AvoraSettlementWalletStatus.active) {
      return const AvoraWithdrawalLiquidityDecision(
        allowed: false,
        reason: AvoraWithdrawalLiquidityDenyReason.walletInactive,
      );
    }

    if (wallet.currencyCode.toUpperCase() != currencyCode.toUpperCase()) {
      return const AvoraWithdrawalLiquidityDecision(
        allowed: false,
        reason: AvoraWithdrawalLiquidityDenyReason.currencyMismatch,
      );
    }

    if (amountMinor <= 0) {
      return const AvoraWithdrawalLiquidityDecision(
        allowed: false,
        reason: AvoraWithdrawalLiquidityDenyReason.invalidAmount,
      );
    }

    if (!AvoraSettlementLiquidityEngine.canReserve(
      wallet: wallet,
      amountMinor: amountMinor,
    )) {
      return const AvoraWithdrawalLiquidityDecision(
        allowed: false,
        reason: AvoraWithdrawalLiquidityDenyReason.insufficientLiquidity,
      );
    }

    final reserved = AvoraSettlementLiquidityEngine.reserve(
      wallet: wallet,
      amountMinor: amountMinor,
      now: now,
    );

    return AvoraWithdrawalLiquidityDecision(
      allowed: true,
      reason: AvoraWithdrawalLiquidityDenyReason.none,
      reservedWallet: reserved,
    );
  }

  /// Must happen in one authoritative backend transaction in production.
  static bool atomicReservationRequired() => true;

  /// Mobile client may request acceptance but cannot reserve balance itself.
  static bool clientCanReserveLiquidityDirectly() => false;

  /// One wallet balance cannot back two simultaneous accepted orders.
  static bool doubleSpendProtectionRequired() => true;

  /// Coin inventory remains unrelated to withdrawal settlement liquidity.
  static bool coinInventoryCanSubstituteSettlementLiquidity() => false;
}
