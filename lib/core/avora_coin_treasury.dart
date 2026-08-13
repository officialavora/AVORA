enum AvoraCoinAccountKind {
  companyTreasury,
  sellerInventory,
  merchantInventory,
  userWallet,
  promoPool,
  gamePool,
  eventPool,
  refundReserve,
}

enum AvoraCoinMovementType {
  issue,
  allocate,
  recharge,
  transfer,
  spend,
  refund,
  reversal,
  burn,
}

class AvoraCoinAccountSnapshot {
  const AvoraCoinAccountSnapshot({
    required this.accountId,
    required this.kind,
    this.ownerAvoraId,
    required this.balance,
    this.reserved = 0,
    this.active = true,
  });

  final String accountId;
  final AvoraCoinAccountKind kind;

  /// Immutable AVORA ID when this account belongs to a user/seller.
  final String? ownerAvoraId;

  final int balance;
  final int reserved;
  final bool active;

  int get availableBalance {
    final value = balance - reserved;
    return value < 0 ? 0 : value;
  }
}

class AvoraCoinLedgerEntry {
  const AvoraCoinLedgerEntry({
    required this.entryId,
    required this.type,
    this.sourceAccountId,
    this.destinationAccountId,
    required this.amount,
    required this.actorAvoraId,
    required this.serverAuthorized,
    required this.createdAt,
    required this.reason,
    required this.referenceId,
    required this.policyVersion,
    required this.idempotencyKey,
  });

  final String entryId;
  final AvoraCoinMovementType type;

  /// null source is allowed only for controlled coin issuance.
  final String? sourceAccountId;

  /// null destination is allowed only for burn.
  final String? destinationAccountId;

  /// Integer coin units only.
  final int amount;

  /// Immutable AVORA ID of the accountable actor.
  final String actorAvoraId;

  /// Must come from trusted backend execution.
  final bool serverAuthorized;

  final DateTime createdAt;
  final String reason;
  final String referenceId;
  final String policyVersion;

  /// Prevents accidental/double processing of the same operation.
  final String idempotencyKey;
}

class AvoraCoinTreasuryDecision {
  const AvoraCoinTreasuryDecision({
    required this.allowed,
    required this.reason,
  });

  final bool allowed;
  final String reason;
}

class AvoraCoinTreasuryEngine {
  static AvoraCoinTreasuryDecision validate({
    required AvoraCoinLedgerEntry entry,
    required Iterable<AvoraCoinAccountSnapshot> accounts,
    required bool actorHasTreasuryPower,
  }) {
    if (entry.amount <= 0) {
      return const AvoraCoinTreasuryDecision(
        allowed: false,
        reason: 'invalidAmount',
      );
    }

    if (!entry.serverAuthorized) {
      return const AvoraCoinTreasuryDecision(
        allowed: false,
        reason: 'serverAuthorizationRequired',
      );
    }

    if (entry.idempotencyKey.trim().isEmpty ||
        entry.referenceId.trim().isEmpty ||
        entry.reason.trim().isEmpty ||
        entry.policyVersion.trim().isEmpty) {
      return const AvoraCoinTreasuryDecision(
        allowed: false,
        reason: 'missingAuditMetadata',
      );
    }

    if (entry.type == AvoraCoinMovementType.issue) {
      if (!actorHasTreasuryPower) {
        return const AvoraCoinTreasuryDecision(
          allowed: false,
          reason: 'treasuryPowerRequired',
        );
      }

      if (entry.sourceAccountId != null) {
        return const AvoraCoinTreasuryDecision(
          allowed: false,
          reason: 'issuanceCannotHaveSourceAccount',
        );
      }

      final destination = _findAccount(
        accounts,
        entry.destinationAccountId,
      );

      if (destination == null ||
          destination.kind != AvoraCoinAccountKind.companyTreasury) {
        return const AvoraCoinTreasuryDecision(
          allowed: false,
          reason: 'issuanceMustEnterCompanyTreasury',
        );
      }

      return const AvoraCoinTreasuryDecision(
        allowed: true,
        reason: 'authorizedTreasuryIssuance',
      );
    }

    if (entry.type == AvoraCoinMovementType.burn) {
      final source = _findAccount(accounts, entry.sourceAccountId);

      if (source == null) {
        return const AvoraCoinTreasuryDecision(
          allowed: false,
          reason: 'burnSourceMissing',
        );
      }

      if (entry.destinationAccountId != null) {
        return const AvoraCoinTreasuryDecision(
          allowed: false,
          reason: 'burnCannotHaveDestinationAccount',
        );
      }

      if (!source.active || source.availableBalance < entry.amount) {
        return const AvoraCoinTreasuryDecision(
          allowed: false,
          reason: 'insufficientAvailableBalance',
        );
      }

      return const AvoraCoinTreasuryDecision(
        allowed: true,
        reason: 'validCoinBurn',
      );
    }

    final source = _findAccount(accounts, entry.sourceAccountId);
    final destination = _findAccount(
      accounts,
      entry.destinationAccountId,
    );

    if (source == null || destination == null) {
      return const AvoraCoinTreasuryDecision(
        allowed: false,
        reason: 'sourceOrDestinationMissing',
      );
    }

    if (!source.active || !destination.active) {
      return const AvoraCoinTreasuryDecision(
        allowed: false,
        reason: 'inactiveCoinAccount',
      );
    }

    if (source.accountId == destination.accountId) {
      return const AvoraCoinTreasuryDecision(
        allowed: false,
        reason: 'sameAccountMovementNotAllowed',
      );
    }

    if (source.availableBalance < entry.amount) {
      return const AvoraCoinTreasuryDecision(
        allowed: false,
        reason: 'insufficientAvailableBalance',
      );
    }

    if (entry.type == AvoraCoinMovementType.recharge) {
      if (source.kind != AvoraCoinAccountKind.sellerInventory ||
          destination.kind != AvoraCoinAccountKind.userWallet) {
        return const AvoraCoinTreasuryDecision(
          allowed: false,
          reason: 'invalidSellerRechargeAccounts',
        );
      }
    }

    if (entry.type == AvoraCoinMovementType.allocate) {
      if (source.kind != AvoraCoinAccountKind.companyTreasury) {
        return const AvoraCoinTreasuryDecision(
          allowed: false,
          reason: 'allocationMustStartFromCompanyTreasury',
        );
      }
    }

    return const AvoraCoinTreasuryDecision(
      allowed: true,
      reason: 'validCoinMovement',
    );
  }

  static int totalIssued(
    Iterable<AvoraCoinLedgerEntry> ledger,
  ) {
    var total = 0;

    for (final entry in ledger) {
      if (entry.type == AvoraCoinMovementType.issue) {
        total += entry.amount;
      }
    }

    return total;
  }

  static int totalBurned(
    Iterable<AvoraCoinLedgerEntry> ledger,
  ) {
    var total = 0;

    for (final entry in ledger) {
      if (entry.type == AvoraCoinMovementType.burn) {
        total += entry.amount;
      }
    }

    return total;
  }

  static int netIssuedSupply(
    Iterable<AvoraCoinLedgerEntry> ledger,
  ) {
    return totalIssued(ledger) - totalBurned(ledger);
  }

  static AvoraCoinAccountSnapshot? _findAccount(
    Iterable<AvoraCoinAccountSnapshot> accounts,
    String? accountId,
  ) {
    if (accountId == null || accountId.trim().isEmpty) {
      return null;
    }

    for (final account in accounts) {
      if (account.accountId == accountId) {
        return account;
      }
    }

    return null;
  }

  /// No Flutter/mobile client can create authoritative coins.
  static bool clientCanMintCoins() => false;

  /// Balance numbers must be derived through trusted ledger operations.
  static bool directClientBalanceMutationAllowed() => false;

  /// Seller recharge must first verify the exact immutable AVORA ID.
  static bool sellerRechargeRequiresRecipientVerification() => true;

  /// Screenshot/manual image alone cannot prove a financial settlement.
  static bool screenshotAloneConfirmsCoinSettlement() => false;
}
