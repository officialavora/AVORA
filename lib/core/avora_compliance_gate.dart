enum AvoraComplianceFeature {
  directRecharge,
  sellerRecharge,
  merchantPayout,

  withdrawableGiftEarnings,
  creatorHostPayout,
  privateCallMonetization,

  luckyGiftCashConversion,
  luckyPocketCashConversion,
  gameCashConversion,

  cryptoUsdtFunding,
  externalPaymentMethods,
}

enum AvoraComplianceDecisionReason {
  allowed,
  countryDisabled,
  policyNotEffective,
  featureDisabled,
  providerUnavailable,
  verificationRequired,
  adultVerificationRequired,
  riskBlocked,
}

class AvoraCountryCompliancePolicy {
  final String id;

  final String countryCode;
  final String version;

  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;

  /// Explicit allow-list.
  /// Anything not listed stays disabled.
  final Set<AvoraComplianceFeature> enabledFeatures;

  const AvoraCountryCompliancePolicy({
    required this.id,
    required this.countryCode,
    required this.version,
    required this.effectiveFrom,
    required this.enabledFeatures,
    this.effectiveUntil,
  });

  bool isEffectiveAt(DateTime time) {
    if (time.isBefore(effectiveFrom)) {
      return false;
    }

    final until = effectiveUntil;

    if (until != null && time.isAfter(until)) {
      return false;
    }

    return true;
  }

  bool featureEnabled(
    AvoraComplianceFeature feature,
  ) {
    return enabledFeatures.contains(feature);
  }
}

class AvoraComplianceRequestContext {
  final String countryCode;

  final bool countryServiceEnabled;

  final bool providerAvailable;

  final bool identityVerified;
  final bool adultVerified;

  final bool riskBlocked;

  const AvoraComplianceRequestContext({
    required this.countryCode,
    required this.countryServiceEnabled,
    required this.providerAvailable,
    required this.identityVerified,
    required this.adultVerified,
    this.riskBlocked = false,
  });
}

class AvoraComplianceDecision {
  final bool allowed;

  final AvoraComplianceDecisionReason reason;

  final String policyId;
  final String policyVersion;

  const AvoraComplianceDecision({
    required this.allowed,
    required this.reason,
    required this.policyId,
    required this.policyVersion,
  });
}

class AvoraGlobalComplianceGate {
  const AvoraGlobalComplianceGate._();

  static AvoraComplianceDecision evaluate({
    required AvoraComplianceFeature feature,
    required AvoraCountryCompliancePolicy policy,
    required AvoraComplianceRequestContext context,
    required DateTime now,

    /// High-risk financial/monetized features normally
    /// require verified identity.
    bool requireIdentityVerification = true,

    /// Adult-first AVORA launch.
    bool requireAdultVerification = true,
  }) {
    AvoraComplianceDecision deny(
      AvoraComplianceDecisionReason reason,
    ) {
      return AvoraComplianceDecision(
        allowed: false,
        reason: reason,
        policyId: policy.id,
        policyVersion: policy.version,
      );
    }

    if (!context.countryServiceEnabled ||
        context.countryCode.toUpperCase() != policy.countryCode.toUpperCase()) {
      return deny(
        AvoraComplianceDecisionReason.countryDisabled,
      );
    }

    if (!policy.isEffectiveAt(now)) {
      return deny(
        AvoraComplianceDecisionReason.policyNotEffective,
      );
    }

    if (!policy.featureEnabled(feature)) {
      return deny(
        AvoraComplianceDecisionReason.featureDisabled,
      );
    }

    if (!context.providerAvailable) {
      return deny(
        AvoraComplianceDecisionReason.providerUnavailable,
      );
    }

    if (requireIdentityVerification && !context.identityVerified) {
      return deny(
        AvoraComplianceDecisionReason.verificationRequired,
      );
    }

    if (requireAdultVerification && !context.adultVerified) {
      return deny(
        AvoraComplianceDecisionReason.adultVerificationRequired,
      );
    }

    if (context.riskBlocked) {
      return deny(
        AvoraComplianceDecisionReason.riskBlocked,
      );
    }

    return AvoraComplianceDecision(
      allowed: true,
      reason: AvoraComplianceDecisionReason.allowed,
      policyId: policy.id,
      policyVersion: policy.version,
    );
  }
}
