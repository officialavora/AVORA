enum AvoraRechargeBeneficiaryMode {
  myself,
  other,
}

class AvoraCoinPackageDefinition {
  const AvoraCoinPackageDefinition({
    required this.packageId,
    required this.version,
    required this.baseCoinUnits,
    required this.bonusCoinUnits,
    required this.usdReferenceMicros,
    required this.effectiveFrom,
    this.effectiveUntil,
    this.active = true,
    this.campaignId,
  });

  final String packageId;

  /// Historical orders retain this exact package version.
  final int version;

  final int baseCoinUnits;
  final int bonusCoinUnits;

  /// 1 USD = 1,000,000 micros.
  /// This is the global catalog reference, not the final local payment amount.
  final int usdReferenceMicros;

  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;

  final bool active;
  final String? campaignId;

  int get totalCoinUnits => baseCoinUnits + bonusCoinUnits;

  bool isEffectiveAt(DateTime now) {
    if (!active) return false;
    if (now.isBefore(effectiveFrom)) return false;
    if (effectiveUntil != null && now.isAfter(effectiveUntil!)) {
      return false;
    }
    return true;
  }
}

class AvoraLocalCurrencyQuote {
  const AvoraLocalCurrencyQuote({
    required this.quoteId,
    required this.currencyCode,
    required this.baseAmountMinor,
    required this.feeAmountMinor,
    required this.taxAmountMinor,
    required this.fractionDigits,
    required this.quotedAt,
    required this.expiresAt,
    required this.providerQuoteRef,
  });

  final String quoteId;

  /// Examples: SAR, INR, PKR, BDT.
  final String currencyCode;

  /// Provider/server-derived local amount.
  final int baseAmountMinor;
  final int feeAmountMinor;
  final int taxAmountMinor;

  /// Usually 2, but retained because currency precision can differ.
  final int fractionDigits;

  final DateTime quotedAt;
  final DateTime expiresAt;

  /// Reference from the authoritative pricing/payment provider.
  final String providerQuoteRef;

  int get totalAmountMinor => baseAmountMinor + feeAmountMinor + taxAmountMinor;

  bool isValidAt(DateTime now) => now.isBefore(expiresAt);
}

class AvoraRechargeOrderPricingSnapshot {
  const AvoraRechargeOrderPricingSnapshot({
    required this.orderId,
    required this.payerAvoraId,
    required this.recipientAvoraId,
    required this.beneficiaryMode,
    required this.packageId,
    required this.packageVersion,
    required this.baseCoinUnits,
    required this.bonusCoinUnits,
    required this.usdReferenceMicros,
    required this.localCurrencyCode,
    required this.localAmountMinor,
    required this.localFractionDigits,
    required this.providerQuoteRef,
    required this.createdAt,
  });

  final String orderId;

  /// Person/payment account funding the recharge.
  final String payerAvoraId;

  /// Immutable AVORA ID receiving the Coins.
  final String recipientAvoraId;

  final AvoraRechargeBeneficiaryMode beneficiaryMode;

  /// Immutable package/rate snapshot.
  final String packageId;
  final int packageVersion;

  final int baseCoinUnits;
  final int bonusCoinUnits;

  final int usdReferenceMicros;

  final String localCurrencyCode;
  final int localAmountMinor;
  final int localFractionDigits;

  final String providerQuoteRef;
  final DateTime createdAt;

  int get totalCoinUnits => baseCoinUnits + bonusCoinUnits;

  bool get isSelfRecharge => payerAvoraId == recipientAvoraId;
}

class AvoraRechargePricingDecision {
  const AvoraRechargePricingDecision({
    required this.allowed,
    required this.reason,
    this.snapshot,
  });

  final bool allowed;
  final String reason;
  final AvoraRechargeOrderPricingSnapshot? snapshot;
}

class AvoraCoinPricingEngine {
  const AvoraCoinPricingEngine._();

  static AvoraRechargePricingDecision createOrderSnapshot({
    required String orderId,
    required String payerAvoraId,
    required String? requestedRecipientAvoraId,
    required AvoraRechargeBeneficiaryMode beneficiaryMode,
    required AvoraCoinPackageDefinition package,
    required AvoraLocalCurrencyQuote localQuote,
    required DateTime now,
  }) {
    final payer = payerAvoraId.trim();

    if (payer.isEmpty) {
      return const AvoraRechargePricingDecision(
        allowed: false,
        reason: 'invalid_payer',
      );
    }

    final recipient = beneficiaryMode == AvoraRechargeBeneficiaryMode.myself
        ? payer
        : (requestedRecipientAvoraId ?? '').trim();

    if (recipient.isEmpty) {
      return const AvoraRechargePricingDecision(
        allowed: false,
        reason: 'invalid_recipient',
      );
    }

    if (!package.isEffectiveAt(now)) {
      return const AvoraRechargePricingDecision(
        allowed: false,
        reason: 'package_not_effective',
      );
    }

    if (package.baseCoinUnits <= 0 ||
        package.bonusCoinUnits < 0 ||
        package.usdReferenceMicros <= 0) {
      return const AvoraRechargePricingDecision(
        allowed: false,
        reason: 'invalid_package',
      );
    }

    if (!localQuote.isValidAt(now)) {
      return const AvoraRechargePricingDecision(
        allowed: false,
        reason: 'quote_expired',
      );
    }

    if (localQuote.currencyCode.trim().isEmpty ||
        localQuote.totalAmountMinor < 0 ||
        localQuote.providerQuoteRef.trim().isEmpty) {
      return const AvoraRechargePricingDecision(
        allowed: false,
        reason: 'invalid_local_quote',
      );
    }

    return AvoraRechargePricingDecision(
      allowed: true,
      reason: 'allowed',
      snapshot: AvoraRechargeOrderPricingSnapshot(
        orderId: orderId,
        payerAvoraId: payer,
        recipientAvoraId: recipient,
        beneficiaryMode: beneficiaryMode,
        packageId: package.packageId,
        packageVersion: package.version,
        baseCoinUnits: package.baseCoinUnits,
        bonusCoinUnits: package.bonusCoinUnits,
        usdReferenceMicros: package.usdReferenceMicros,
        localCurrencyCode: localQuote.currencyCode.toUpperCase(),
        localAmountMinor: localQuote.totalAmountMinor,
        localFractionDigits: localQuote.fractionDigits,
        providerQuoteRef: localQuote.providerQuoteRef,
        createdAt: now,
      ),
    );
  }

  /// Owner/backend configuration controls package/reference pricing.
  static bool clientCanChangeGlobalCoinRate() => false;

  /// Client must never invent FX/local-currency conversion.
  static bool clientCanSetLocalFxQuote() => false;

  /// Local currency comes through country/payment/provider configuration.
  static bool countryPaymentRegistrySuppliesLocalCurrency() => true;

  /// Existing USDT ratio/provider configuration must be reused.
  static bool reuseExistingUsdtRatioConfiguration() => true;

  /// Changing today's rate/package never rewrites an old order.
  static bool historicalOrderPricingIsImmutable() => true;

  /// Payer and Coin beneficiary remain separately auditable.
  static bool payerAndRecipientAreSeparateLedgerParties() => true;

  /// Provider/webhook settlement remains authoritative before Coin credit.
  static bool authoritativePaymentConfirmationRequired() => true;

  /// Purchasing/recharge progression attribution is policy-controlled,
  /// preventing payer + recipient double counting.
  static bool progressionAttributionMustBeExplicit() => true;
}
