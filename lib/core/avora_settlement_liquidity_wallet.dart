enum AvoraSettlementWalletOwnerKind {
  merchant,
  agencyOwner,
}

enum AvoraSettlementWalletStatus {
  active,
  suspended,
  closed,
}

enum AvoraSettlementWalletMode {
  providerHeld,
  collateralBacked,
  externalSettlementCapacity,
}

enum AvoraLiquidityPublicBand {
  unavailable,
  low,
  medium,
  high,
}

class AvoraSettlementLiquidityWallet {
  const AvoraSettlementLiquidityWallet({
    required this.walletId,
    required this.ownerAvoraId,
    required this.ownerKind,
    required this.currencyCode,
    required this.mode,
    required this.status,
    required this.confirmedMinor,
    required this.reservedMinor,
    required this.pendingIncomingMinor,
    required this.updatedAt,
  });

  final String walletId;

  /// Immutable AVORA ID of Merchant / Agency Owner.
  final String ownerAvoraId;

  final AvoraSettlementWalletOwnerKind ownerKind;
  final String currencyCode;

  /// Lets AVORA support different regulated settlement models later
  /// without redesigning the wallet.
  final AvoraSettlementWalletMode mode;

  final AvoraSettlementWalletStatus status;

  /// Trusted, confirmed settlement liquidity.
  final int confirmedMinor;

  /// Locked for accepted/pending withdrawal orders.
  final int reservedMinor;

  /// Incoming amount not yet confirmed; cannot be spent.
  final int pendingIncomingMinor;

  final DateTime updatedAt;

  int get availableMinor {
    final value = confirmedMinor - reservedMinor;
    return value < 0 ? 0 : value;
  }

  bool get canAcceptWithdrawals =>
      status == AvoraSettlementWalletStatus.active && availableMinor > 0;

  AvoraSettlementLiquidityWallet copyWith({
    int? confirmedMinor,
    int? reservedMinor,
    int? pendingIncomingMinor,
    AvoraSettlementWalletStatus? status,
    DateTime? updatedAt,
  }) {
    return AvoraSettlementLiquidityWallet(
      walletId: walletId,
      ownerAvoraId: ownerAvoraId,
      ownerKind: ownerKind,
      currencyCode: currencyCode,
      mode: mode,
      status: status ?? this.status,
      confirmedMinor: confirmedMinor ?? this.confirmedMinor,
      reservedMinor: reservedMinor ?? this.reservedMinor,
      pendingIncomingMinor: pendingIncomingMinor ?? this.pendingIncomingMinor,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AvoraSettlementLiquidityEngine {
  static bool isValidWallet(AvoraSettlementLiquidityWallet wallet) {
    return wallet.walletId.trim().isNotEmpty &&
        wallet.ownerAvoraId.trim().isNotEmpty &&
        wallet.currencyCode.trim().isNotEmpty &&
        wallet.confirmedMinor >= 0 &&
        wallet.reservedMinor >= 0 &&
        wallet.pendingIncomingMinor >= 0 &&
        wallet.reservedMinor <= wallet.confirmedMinor;
  }

  static bool canReserve({
    required AvoraSettlementLiquidityWallet wallet,
    required int amountMinor,
  }) {
    return isValidWallet(wallet) &&
        wallet.status == AvoraSettlementWalletStatus.active &&
        amountMinor > 0 &&
        wallet.availableMinor >= amountMinor;
  }

  static AvoraSettlementLiquidityWallet reserve({
    required AvoraSettlementLiquidityWallet wallet,
    required int amountMinor,
    required DateTime now,
  }) {
    if (!canReserve(wallet: wallet, amountMinor: amountMinor)) {
      return wallet;
    }

    return wallet.copyWith(
      reservedMinor: wallet.reservedMinor + amountMinor,
      updatedAt: now,
    );
  }

  static AvoraSettlementLiquidityWallet releaseReservation({
    required AvoraSettlementLiquidityWallet wallet,
    required int amountMinor,
    required DateTime now,
  }) {
    if (amountMinor <= 0 || amountMinor > wallet.reservedMinor) {
      return wallet;
    }

    return wallet.copyWith(
      reservedMinor: wallet.reservedMinor - amountMinor,
      updatedAt: now,
    );
  }

  static AvoraSettlementLiquidityWallet settleReservedWithdrawal({
    required AvoraSettlementLiquidityWallet wallet,
    required int amountMinor,
    required DateTime now,
  }) {
    if (amountMinor <= 0 ||
        amountMinor > wallet.reservedMinor ||
        amountMinor > wallet.confirmedMinor) {
      return wallet;
    }

    return wallet.copyWith(
      confirmedMinor: wallet.confirmedMinor - amountMinor,
      reservedMinor: wallet.reservedMinor - amountMinor,
      updatedAt: now,
    );
  }

  static AvoraSettlementLiquidityWallet addPendingIncoming({
    required AvoraSettlementLiquidityWallet wallet,
    required int amountMinor,
    required DateTime now,
  }) {
    if (amountMinor <= 0) return wallet;

    return wallet.copyWith(
      pendingIncomingMinor: wallet.pendingIncomingMinor + amountMinor,
      updatedAt: now,
    );
  }

  static AvoraSettlementLiquidityWallet confirmPendingIncoming({
    required AvoraSettlementLiquidityWallet wallet,
    required int amountMinor,
    required DateTime now,
  }) {
    if (amountMinor <= 0 || amountMinor > wallet.pendingIncomingMinor) {
      return wallet;
    }

    return wallet.copyWith(
      confirmedMinor: wallet.confirmedMinor + amountMinor,
      pendingIncomingMinor: wallet.pendingIncomingMinor - amountMinor,
      updatedAt: now,
    );
  }

  static AvoraLiquidityPublicBand publicBand({
    required AvoraSettlementLiquidityWallet wallet,
    required int mediumThresholdMinor,
    required int highThresholdMinor,
  }) {
    if (!wallet.canAcceptWithdrawals) {
      return AvoraLiquidityPublicBand.unavailable;
    }

    if (wallet.availableMinor >= highThresholdMinor) {
      return AvoraLiquidityPublicBand.high;
    }

    if (wallet.availableMinor >= mediumThresholdMinor) {
      return AvoraLiquidityPublicBand.medium;
    }

    return AvoraLiquidityPublicBand.low;
  }

  /// Public users should not see the agent's raw full wallet balance.
  static bool publicRawBalanceVisible() => false;

  /// Owner/authorized finance systems may access full operational balance.
  static bool ownerOperationalBalanceAccessSupported() => true;

  /// Coin Inventory and settlement liquidity are separate ledgers.
  static bool coinInventoryAndSettlementWalletAreSeparate() => true;

  /// Pending incoming funds cannot fund withdrawals until confirmed.
  static bool pendingIncomingIsSpendable() => false;

  /// Mobile client cannot directly mutate authoritative liquidity.
  static bool clientCanMutateLiquidityBalance() => false;

  /// Accepted withdrawal must reserve liquidity before settlement.
  static bool reserveBeforeWithdrawalSettlement() => true;
}
