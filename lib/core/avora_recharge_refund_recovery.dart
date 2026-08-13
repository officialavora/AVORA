enum AvoraRechargeLotStatus {
  unused,
  partiallyConsumed,
  fullyConsumed,
  refundRequested,
  providerRefunded,
  chargeback,
  recoveryPending,
  recovered,
  closed,
}

enum AvoraCoinConsumptionKind {
  giftSelfTarget,
  giftOtherTarget,
  gameEntry,
  gameSpend,
  gameLoss,
  roomSpend,
  transfer,
  otherEligibleSpend,
}

enum AvoraProviderRecoveryEventType {
  refund,
  partialRefund,
  chargeback,
  providerReversal,
}

enum AvoraRefundRecoveryStatus {
  pending,
  noRecoveryNeeded,
  balanceRecoveryRequired,
  liabilityPending,
  recovered,
  closed,
}

class AvoraRechargePurchaseLot {
  const AvoraRechargePurchaseLot({
    required this.lotId,
    required this.payerAvoraId,
    required this.beneficiaryAvoraId,
    required this.provider,
    required this.providerTransactionId,
    required this.purchasedCoinUnits,
    required this.bonusCoinUnits,
    required this.consumedCoinUnits,
    required this.policyVersion,
    required this.pricingSnapshotId,
    required this.createdAt,
    required this.status,
  });

  final String lotId;

  final String payerAvoraId;
  final String beneficiaryAvoraId;

  final String provider;
  final String providerTransactionId;

  /// Paid Coin units from the verified recharge.
  final int purchasedCoinUnits;

  /// Bonus Coins tied to this purchase, kept separately auditable.
  final int bonusCoinUnits;

  /// Historical consumption attributed to this lot.
  final int consumedCoinUnits;

  final String policyVersion;
  final String pricingSnapshotId;
  final DateTime createdAt;

  final AvoraRechargeLotStatus status;

  int get totalCreditedCoinUnits => purchasedCoinUnits + bonusCoinUnits;

  int get remainingAttributedCoinUnits {
    final remaining = totalCreditedCoinUnits - consumedCoinUnits;
    return remaining > 0 ? remaining : 0;
  }
}

class AvoraCoinConsumptionAttribution {
  const AvoraCoinConsumptionAttribution({
    required this.attributionId,
    required this.consumptionId,
    required this.purchaseLotId,
    required this.kind,
    required this.coinUnits,
    required this.subjectReferenceId,
    required this.policyVersion,
    required this.occurredAt,
  });

  final String attributionId;

  /// Immutable gift/game/spend transaction reference.
  final String consumptionId;

  final String purchaseLotId;
  final AvoraCoinConsumptionKind kind;
  final int coinUnits;

  /// Gift ID, game round ID, room spend ID, etc.
  final String subjectReferenceId;

  final String policyVersion;
  final DateTime occurredAt;
}

class AvoraConsumptionAllocationResult {
  const AvoraConsumptionAllocationResult({
    required this.attributions,
    required this.requestedCoinUnits,
    required this.attributedCoinUnits,
    required this.unattributedCoinUnits,
  });

  final List<AvoraCoinConsumptionAttribution> attributions;

  final int requestedCoinUnits;
  final int attributedCoinUnits;

  /// May belong to promo/non-purchase sources and must be resolved by
  /// the wider Coin ledger instead of being guessed by this engine.
  final int unattributedCoinUnits;
}

class AvoraProviderRefundEvent {
  const AvoraProviderRefundEvent({
    required this.eventId,
    required this.type,
    required this.provider,
    required this.providerTransactionId,
    required this.purchaseLotId,
    required this.currencyCode,
    required this.providerAmountMinor,
    required this.coinUnitsToRecover,
    required this.serverVerified,
    required this.policyVersion,
    required this.idempotencyKey,
    required this.occurredAt,
  });

  final String eventId;
  final AvoraProviderRecoveryEventType type;

  final String provider;
  final String providerTransactionId;
  final String purchaseLotId;

  /// Original provider-reported monetary reversal/refund amount.
  final String currencyCode;
  final int providerAmountMinor;

  /// Server-normalized Coin equivalent using the immutable purchase/rate
  /// snapshot. May include purchase-linked bonus recovery if policy requires.
  final int coinUnitsToRecover;

  /// Client/screenshot can never make this true.
  final bool serverVerified;

  final String policyVersion;
  final String idempotencyKey;
  final DateTime occurredAt;
}

class AvoraRefundRecoveryLiability {
  const AvoraRefundRecoveryLiability({
    required this.liabilityId,
    required this.purchaseLotId,
    required this.beneficiaryAvoraId,
    required this.providerEventId,
    required this.coinUnitsToRecover,
    required this.recoverFromRemainingBalanceCoinUnits,
    required this.unrecoveredConsumedCoinUnits,
    required this.financialHoldRequired,
    required this.status,
    required this.policyVersion,
    required this.createdAt,
  });

  final String liabilityId;
  final String purchaseLotId;

  final String beneficiaryAvoraId;
  final String providerEventId;

  final int coinUnitsToRecover;

  /// Recover from the still-unconsumed attributed balance first.
  final int recoverFromRemainingBalanceCoinUnits;

  /// Consumed value that can no longer simply be removed from current balance.
  final int unrecoveredConsumedCoinUnits;

  /// Existing risk/freeze engine may apply the appropriate scoped hold.
  final bool financialHoldRequired;

  final AvoraRefundRecoveryStatus status;
  final String policyVersion;
  final DateTime createdAt;
}

class AvoraRefundRecoveryAuditEvent {
  const AvoraRefundRecoveryAuditEvent({
    required this.auditId,
    required this.purchaseLotId,
    required this.providerEventId,
    required this.beneficiaryAvoraId,
    required this.coinUnitsToRecover,
    required this.recoveredBalanceCoinUnits,
    required this.liabilityCoinUnits,
    required this.reason,
    required this.occurredAt,
  });

  final String auditId;
  final String purchaseLotId;
  final String providerEventId;
  final String beneficiaryAvoraId;

  final int coinUnitsToRecover;
  final int recoveredBalanceCoinUnits;
  final int liabilityCoinUnits;

  final String reason;
  final DateTime occurredAt;
}

class AvoraRefundRecoveryDecision {
  const AvoraRefundRecoveryDecision({
    required this.allowed,
    required this.reason,
    this.liability,
    this.auditEvent,
  });

  final bool allowed;
  final String reason;

  final AvoraRefundRecoveryLiability? liability;
  final AvoraRefundRecoveryAuditEvent? auditEvent;
}

class AvoraRechargeRefundRecoveryEngine {
  const AvoraRechargeRefundRecoveryEngine._();

  /// Deterministic FIFO attribution allows the backend to know which
  /// verified recharge lots funded a later Coin spend.
  static AvoraConsumptionAllocationResult attributeConsumptionFifo({
    required String consumptionId,
    required AvoraCoinConsumptionKind kind,
    required int coinUnits,
    required String subjectReferenceId,
    required String policyVersion,
    required DateTime occurredAt,
    required Iterable<AvoraRechargePurchaseLot> purchaseLots,
  }) {
    if (coinUnits <= 0) {
      return const AvoraConsumptionAllocationResult(
        attributions: [],
        requestedCoinUnits: 0,
        attributedCoinUnits: 0,
        unattributedCoinUnits: 0,
      );
    }

    final lots = purchaseLots
        .where((lot) => lot.remainingAttributedCoinUnits > 0)
        .toList()
      ..sort((a, b) {
        final timeCompare = a.createdAt.compareTo(b.createdAt);
        if (timeCompare != 0) return timeCompare;
        return a.lotId.compareTo(b.lotId);
      });

    var remaining = coinUnits;
    final attributions = <AvoraCoinConsumptionAttribution>[];

    for (final lot in lots) {
      if (remaining <= 0) break;

      final available = lot.remainingAttributedCoinUnits;
      final take = remaining < available ? remaining : available;

      if (take <= 0) continue;

      attributions.add(
        AvoraCoinConsumptionAttribution(
          attributionId: '$consumptionId:${lot.lotId}',
          consumptionId: consumptionId,
          purchaseLotId: lot.lotId,
          kind: kind,
          coinUnits: take,
          subjectReferenceId: subjectReferenceId,
          policyVersion: policyVersion,
          occurredAt: occurredAt,
        ),
      );

      remaining -= take;
    }

    return AvoraConsumptionAllocationResult(
      attributions: List.unmodifiable(attributions),
      requestedCoinUnits: coinUnits,
      attributedCoinUnits: coinUnits - remaining,
      unattributedCoinUnits: remaining,
    );
  }

  static AvoraRefundRecoveryDecision prepareProviderRecovery({
    required AvoraProviderRefundEvent event,
    required AvoraRechargePurchaseLot lot,
    required String liabilityId,
    required String auditId,
    required DateTime serverNow,
  }) {
    if (!event.serverVerified) {
      return const AvoraRefundRecoveryDecision(
        allowed: false,
        reason: 'provider_event_not_server_verified',
      );
    }

    if (event.purchaseLotId != lot.lotId ||
        event.providerTransactionId != lot.providerTransactionId) {
      return const AvoraRefundRecoveryDecision(
        allowed: false,
        reason: 'purchase_reference_mismatch',
      );
    }

    if (event.coinUnitsToRecover <= 0) {
      return const AvoraRefundRecoveryDecision(
        allowed: false,
        reason: 'invalid_recovery_amount',
      );
    }

    final available = lot.remainingAttributedCoinUnits;

    final recoverFromBalance = event.coinUnitsToRecover < available
        ? event.coinUnitsToRecover
        : available;

    final liabilityUnits = event.coinUnitsToRecover - recoverFromBalance;

    final status = liabilityUnits > 0
        ? AvoraRefundRecoveryStatus.liabilityPending
        : AvoraRefundRecoveryStatus.balanceRecoveryRequired;

    final liability = AvoraRefundRecoveryLiability(
      liabilityId: liabilityId,
      purchaseLotId: lot.lotId,
      beneficiaryAvoraId: lot.beneficiaryAvoraId,
      providerEventId: event.eventId,
      coinUnitsToRecover: event.coinUnitsToRecover,
      recoverFromRemainingBalanceCoinUnits: recoverFromBalance,
      unrecoveredConsumedCoinUnits: liabilityUnits,
      financialHoldRequired: liabilityUnits > 0,
      status: status,
      policyVersion: event.policyVersion,
      createdAt: serverNow,
    );

    final audit = AvoraRefundRecoveryAuditEvent(
      auditId: auditId,
      purchaseLotId: lot.lotId,
      providerEventId: event.eventId,
      beneficiaryAvoraId: lot.beneficiaryAvoraId,
      coinUnitsToRecover: event.coinUnitsToRecover,
      recoveredBalanceCoinUnits: recoverFromBalance,
      liabilityCoinUnits: liabilityUnits,
      reason: liabilityUnits > 0
          ? 'consumed_value_requires_recovery'
          : 'remaining_balance_recovery',
      occurredAt: serverNow,
    );

    return AvoraRefundRecoveryDecision(
      allowed: true,
      reason: 'recovery_prepared',
      liability: liability,
      auditEvent: audit,
    );
  }

  /// Normal AVORA voluntary refund policy evaluates the unconsumed eligible
  /// portion. Provider/store/statutory decisions can still override this.
  static bool voluntaryRefundUsesUnconsumedValueOnly() => true;

  static bool selfTargetGiftCountsAsConsumption() => true;

  static bool otherTargetGiftCountsAsConsumption() => true;

  static bool gameEntryCountsAsConsumption() => true;

  static bool gameSpendOrLossCountsAsConsumption() => true;

  /// Screenshots/client requests are never authoritative payment state.
  static bool clientCanMarkPurchaseRefunded() => false;

  static bool providerServerNotificationRequired() => true;

  /// Historical gift/game/receiver records are preserved rather than erased.
  static bool historicalSpendCanBeSilentlyRewritten() => false;

  /// Do not automatically steal unrelated third-party earned balances.
  static bool unrelatedThirdPartyBalanceCanBeAutoClawedBack() => false;

  /// Existing scoped risk/freeze engine handles unresolved liability.
  static bool unresolvedLiabilityMayRequireFinancialHold() => true;

  /// Existing Treasury reversal/ledger engine remains authoritative for
  /// actual balance mutation.
  static bool treasuryReversalRemainsAuthoritative() => true;

  /// Provider/store/law remains authoritative where it requires a refund.
  static bool providerOrLegalRefundDecisionCanOverrideInternalPolicy() => true;
}
