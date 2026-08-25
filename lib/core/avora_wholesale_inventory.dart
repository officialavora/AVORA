import 'avora_coin_treasury.dart';

enum AvoraWholesaleAuthority {
  owner,
  merchant,
  manager,
  other,
}

enum AvoraCoinCreditDestination {
  userWallet,
  sellerInventory,
  merchantInventory,
}

enum AvoraWholesaleDenyReason {
  none,
  invalidAmount,
  invalidRate,
  invalidBonus,
  invalidSource,
  invalidDestination,
  insufficientInventory,
  ownerAuthorityRequired,
  merchantAuthorityRequired,
  merchantOwnershipMismatch,
  managerFinancialAuthorityDenied,
  userWalletRequiresRechargeFlow,
}

class AvoraWholesaleBonusTier {
  const AvoraWholesaleBonusTier({
    required this.tierId,
    required this.version,
    required this.minimumUsdMicros,
    required this.bonusBps,
    required this.effectiveFrom,
    this.maximumUsdMicros,
    this.effectiveUntil,
    this.active = true,
  });

  final String tierId;
  final int version;

  final int minimumUsdMicros;
  final int? maximumUsdMicros;

  /// 500 = 5%, 1000 = 10%, 2000 = 20%.
  final int bonusBps;

  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;
  final bool active;

  bool matches({
    required int usdMicros,
    required DateTime now,
  }) {
    if (!active || now.isBefore(effectiveFrom)) return false;
    if (effectiveUntil != null && now.isAfter(effectiveUntil!)) return false;
    if (usdMicros < minimumUsdMicros) return false;
    if (maximumUsdMicros != null && usdMicros > maximumUsdMicros!) {
      return false;
    }
    return true;
  }
}

class AvoraWholesaleCalculation {
  const AvoraWholesaleCalculation({
    required this.referenceUsdMicros,
    required this.coinsPerUsd,
    required this.rateVersion,
    required this.baseCoinUnits,
    required this.bonusCoinUnits,
    required this.totalCoinUnits,
    required this.bonusBps,
    this.bonusTierId,
    this.bonusTierVersion,
  });

  final int referenceUsdMicros;
  final int coinsPerUsd;
  final String rateVersion;

  final int baseCoinUnits;
  final int bonusCoinUnits;
  final int totalCoinUnits;

  final int bonusBps;
  final String? bonusTierId;
  final int? bonusTierVersion;
}

class AvoraWholesaleRecipientSnapshot {
  const AvoraWholesaleRecipientSnapshot({
    required this.avoraId,
    required this.displayName,
    required this.avatarRef,
  });

  final String avoraId;
  final String displayName;
  final String? avatarRef;
}

class AvoraWholesaleReceipt {
  const AvoraWholesaleReceipt({
    required this.receiptId,
    required this.referenceId,
    required this.actorAvoraId,
    required this.recipient,
    required this.destination,
    required this.destinationAccountId,
    required this.referenceUsdMicros,
    required this.rateVersion,
    required this.baseCoinUnits,
    required this.bonusBps,
    required this.bonusCoinUnits,
    required this.totalCoinUnits,
    required this.policyVersion,
    required this.createdAt,
  });

  final String receiptId;
  final String referenceId;

  final String actorAvoraId;
  final AvoraWholesaleRecipientSnapshot recipient;

  final AvoraCoinCreditDestination destination;
  final String destinationAccountId;

  final int referenceUsdMicros;
  final String rateVersion;

  final int baseCoinUnits;
  final int bonusBps;
  final int bonusCoinUnits;
  final int totalCoinUnits;

  final String policyVersion;
  final DateTime createdAt;
}

class AvoraWholesaleDecision {
  const AvoraWholesaleDecision({
    required this.allowed,
    required this.reason,
    this.ledgerEntry,
    this.receipt,
    this.routeToUserRecharge = false,
  });

  final bool allowed;
  final AvoraWholesaleDenyReason reason;

  final AvoraTreasuryLedgerEntry? ledgerEntry;
  final AvoraWholesaleReceipt? receipt;

  /// User Wallet is intentionally handled by normal Recharge,
  /// never silently mixed with Seller/Merchant inventory allocation.
  final bool routeToUserRecharge;
}

class AvoraWholesaleEngine {
  const AvoraWholesaleEngine._();

  static AvoraWholesaleCalculation? calculate({
    required int referenceUsdMicros,
    required int coinsPerUsd,
    required String rateVersion,
    required DateTime now,
    required Iterable<AvoraWholesaleBonusTier> bonusTiers,
  }) {
    if (referenceUsdMicros <= 0 || coinsPerUsd <= 0) return null;

    final matches = bonusTiers
        .where((tier) => tier.matches(usdMicros: referenceUsdMicros, now: now))
        .where((tier) => tier.bonusBps >= 0)
        .toList()
      ..sort((a, b) {
        final minimumCompare = b.minimumUsdMicros.compareTo(a.minimumUsdMicros);
        if (minimumCompare != 0) return minimumCompare;
        return b.version.compareTo(a.version);
      });

    final tier = matches.isEmpty ? null : matches.first;
    final bonusBps = tier?.bonusBps ?? 0;

    final baseCoins = (referenceUsdMicros * coinsPerUsd) ~/ 1000000;

    final bonusCoins = (baseCoins * bonusBps) ~/ 10000;

    return AvoraWholesaleCalculation(
      referenceUsdMicros: referenceUsdMicros,
      coinsPerUsd: coinsPerUsd,
      rateVersion: rateVersion,
      baseCoinUnits: baseCoins,
      bonusCoinUnits: bonusCoins,
      totalCoinUnits: baseCoins + bonusCoins,
      bonusBps: bonusBps,
      bonusTierId: tier?.tierId,
      bonusTierVersion: tier?.version,
    );
  }

  static AvoraWholesaleDecision prepareOwnerAllocation({
    required AvoraWholesaleAuthority authority,
    required String actorAvoraId,
    required AvoraCoinCreditDestination destination,
    required AvoraCoinAccountSnapshot sourceTreasury,
    required AvoraCoinAccountSnapshot destinationAccount,
    required AvoraWholesaleRecipientSnapshot recipient,
    required AvoraWholesaleCalculation calculation,
    required String entryId,
    required String receiptId,
    required String referenceId,
    required String policyVersion,
    required String idempotencyKey,
    required DateTime createdAt,
  }) {
    if (authority == AvoraWholesaleAuthority.manager) {
      return const AvoraWholesaleDecision(
        allowed: false,
        reason: AvoraWholesaleDenyReason.managerFinancialAuthorityDenied,
      );
    }

    if (authority != AvoraWholesaleAuthority.owner) {
      return const AvoraWholesaleDecision(
        allowed: false,
        reason: AvoraWholesaleDenyReason.ownerAuthorityRequired,
      );
    }

    if (destination == AvoraCoinCreditDestination.userWallet) {
      return const AvoraWholesaleDecision(
        allowed: false,
        reason: AvoraWholesaleDenyReason.userWalletRequiresRechargeFlow,
        routeToUserRecharge: true,
      );
    }

    if (sourceTreasury.kind != AvoraCoinAccountKind.companyTreasury ||
        !sourceTreasury.active) {
      return const AvoraWholesaleDecision(
        allowed: false,
        reason: AvoraWholesaleDenyReason.invalidSource,
      );
    }

    final expectedKind =
        destination == AvoraCoinCreditDestination.merchantInventory
            ? AvoraCoinAccountKind.merchantInventory
            : AvoraCoinAccountKind.sellerInventory;

    if (destinationAccount.kind != expectedKind || !destinationAccount.active) {
      return const AvoraWholesaleDecision(
        allowed: false,
        reason: AvoraWholesaleDenyReason.invalidDestination,
      );
    }

    if (calculation.totalCoinUnits <= 0) {
      return const AvoraWholesaleDecision(
        allowed: false,
        reason: AvoraWholesaleDenyReason.invalidAmount,
      );
    }

    if (sourceTreasury.availableBalance < calculation.totalCoinUnits) {
      return const AvoraWholesaleDecision(
        allowed: false,
        reason: AvoraWholesaleDenyReason.insufficientInventory,
      );
    }

    final ledgerEntry = AvoraTreasuryLedgerEntry(
      entryId: entryId,
      type: AvoraCoinMovementType.allocate,
      sourceAccountId: sourceTreasury.accountId,
      destinationAccountId: destinationAccount.accountId,
      amount: calculation.totalCoinUnits,
      actorAvoraId: actorAvoraId,
      serverAuthorized: true,
      createdAt: createdAt,
      reason: 'wholesale_inventory_allocation',
      referenceId: referenceId,
      policyVersion: policyVersion,
      idempotencyKey: idempotencyKey,
    );

    final receipt = AvoraWholesaleReceipt(
      receiptId: receiptId,
      referenceId: referenceId,
      actorAvoraId: actorAvoraId,
      recipient: recipient,
      destination: destination,
      destinationAccountId: destinationAccount.accountId,
      referenceUsdMicros: calculation.referenceUsdMicros,
      rateVersion: calculation.rateVersion,
      baseCoinUnits: calculation.baseCoinUnits,
      bonusBps: calculation.bonusBps,
      bonusCoinUnits: calculation.bonusCoinUnits,
      totalCoinUnits: calculation.totalCoinUnits,
      policyVersion: policyVersion,
      createdAt: createdAt,
    );

    return AvoraWholesaleDecision(
      allowed: true,
      reason: AvoraWholesaleDenyReason.none,
      ledgerEntry: ledgerEntry,
      receipt: receipt,
    );
  }

  static AvoraWholesaleDecision prepareMerchantToSellerTransfer({
    required AvoraWholesaleAuthority authority,
    required String merchantAvoraId,
    required AvoraCoinAccountSnapshot merchantInventory,
    required AvoraCoinAccountSnapshot sellerInventory,
    required AvoraWholesaleRecipientSnapshot seller,
    required int coinUnits,
    required String entryId,
    required String receiptId,
    required String referenceId,
    required String policyVersion,
    required String idempotencyKey,
    required DateTime createdAt,
  }) {
    if (authority == AvoraWholesaleAuthority.manager) {
      return const AvoraWholesaleDecision(
        allowed: false,
        reason: AvoraWholesaleDenyReason.managerFinancialAuthorityDenied,
      );
    }

    if (authority != AvoraWholesaleAuthority.merchant) {
      return const AvoraWholesaleDecision(
        allowed: false,
        reason: AvoraWholesaleDenyReason.merchantAuthorityRequired,
      );
    }

    if (merchantInventory.kind != AvoraCoinAccountKind.merchantInventory ||
        !merchantInventory.active) {
      return const AvoraWholesaleDecision(
        allowed: false,
        reason: AvoraWholesaleDenyReason.invalidSource,
      );
    }

    if (merchantInventory.ownerAvoraId != merchantAvoraId) {
      return const AvoraWholesaleDecision(
        allowed: false,
        reason: AvoraWholesaleDenyReason.merchantOwnershipMismatch,
      );
    }

    if (sellerInventory.kind != AvoraCoinAccountKind.sellerInventory ||
        !sellerInventory.active) {
      return const AvoraWholesaleDecision(
        allowed: false,
        reason: AvoraWholesaleDenyReason.invalidDestination,
      );
    }

    if (coinUnits <= 0) {
      return const AvoraWholesaleDecision(
        allowed: false,
        reason: AvoraWholesaleDenyReason.invalidAmount,
      );
    }

    if (merchantInventory.availableBalance < coinUnits) {
      return const AvoraWholesaleDecision(
        allowed: false,
        reason: AvoraWholesaleDenyReason.insufficientInventory,
      );
    }

    final ledgerEntry = AvoraTreasuryLedgerEntry(
      entryId: entryId,
      type: AvoraCoinMovementType.transfer,
      sourceAccountId: merchantInventory.accountId,
      destinationAccountId: sellerInventory.accountId,
      amount: coinUnits,
      actorAvoraId: merchantAvoraId,
      serverAuthorized: true,
      createdAt: createdAt,
      reason: 'merchant_to_seller_inventory_transfer',
      referenceId: referenceId,
      policyVersion: policyVersion,
      idempotencyKey: idempotencyKey,
    );

    final receipt = AvoraWholesaleReceipt(
      receiptId: receiptId,
      referenceId: referenceId,
      actorAvoraId: merchantAvoraId,
      recipient: seller,
      destination: AvoraCoinCreditDestination.sellerInventory,
      destinationAccountId: sellerInventory.accountId,
      referenceUsdMicros: 0,
      rateVersion: 'inventory-transfer',
      baseCoinUnits: coinUnits,
      bonusBps: 0,
      bonusCoinUnits: 0,
      totalCoinUnits: coinUnits,
      policyVersion: policyVersion,
      createdAt: createdAt,
    );

    return AvoraWholesaleDecision(
      allowed: true,
      reason: AvoraWholesaleDenyReason.none,
      ledgerEntry: ledgerEntry,
      receipt: receipt,
    );
  }

  static bool merchantCanMintCoins() => false;

  static bool managerCanTransferCoins() => false;

  static bool clientCanDirectlyCreditInventory() => false;

  static bool userWalletMustUseRechargeFlow() => true;

  static bool sellerMerchantInventoryIsSeparateFromSettlementLiquidity() =>
      true;
}
