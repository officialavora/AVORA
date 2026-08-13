enum AvoraSellerApplicationStatus {
  draft,
  pendingReview,
  changesRequested,
  approved,
  rejected,
  suspended,
  closed,
}

enum AvoraSellerReviewAction {
  requestChanges,
  approve,
  reject,
}

enum AvoraSellerOnboardingDenyReason {
  none,
  invalidApplicant,
  invalidSponsor,
  invalidCountry,
  sellerDisabledInCountry,
  merchantDisabledInCountry,
  reviewerUnauthorized,
  merchantCannotSelfApprove,
  invalidApplicationStatus,
}

enum AvoraMerchantSponsorBenefitKind {
  none,
  fixedCoinInventoryBonus,
  commissionBps,
  targetCredit,
  campaignReward,
}

class AvoraCountryCommerceGate {
  const AvoraCountryCommerceGate({
    required this.countryCode,
    required this.version,
    required this.sellerEnabled,
    required this.merchantEnabled,
    required this.effectiveFrom,
    this.effectiveUntil,
  });

  final String countryCode;
  final int version;
  final bool sellerEnabled;
  final bool merchantEnabled;
  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;

  bool effectiveAt(DateTime now) {
    if (now.isBefore(effectiveFrom)) return false;
    if (effectiveUntil != null && !now.isBefore(effectiveUntil!)) {
      return false;
    }
    return true;
  }
}

class AvoraMerchantSponsorBenefitPolicy {
  const AvoraMerchantSponsorBenefitPolicy({
    required this.policyId,
    required this.version,
    required this.kind,
    required this.value,
    required this.effectiveFrom,
    this.effectiveUntil,
    this.active = true,
  });

  final String policyId;
  final int version;
  final AvoraMerchantSponsorBenefitKind kind;

  /// Meaning depends on [kind]:
  /// fixed Coin units, basis points, target units, or campaign reward units.
  final int value;

  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;
  final bool active;

  bool effectiveAt(DateTime now) {
    if (!active || value < 0 || now.isBefore(effectiveFrom)) return false;
    if (effectiveUntil != null && !now.isBefore(effectiveUntil!)) {
      return false;
    }
    return true;
  }
}

class AvoraSellerApplication {
  const AvoraSellerApplication({
    required this.applicationId,
    required this.applicantSellerAvoraId,
    required this.sponsorMerchantAvoraId,
    required this.countryCode,
    required this.status,
    required this.submittedAt,
    required this.policyVersion,
    this.reviewedByAvoraId,
    this.reviewedAt,
    this.decisionReason,
  });

  final String applicationId;

  /// Existing immutable AVORA ID receiving Seller capability after approval.
  final String applicantSellerAvoraId;

  /// Merchant that recruited/sponsored this Seller.
  final String sponsorMerchantAvoraId;

  final String countryCode;
  final AvoraSellerApplicationStatus status;
  final DateTime submittedAt;
  final String policyVersion;

  final String? reviewedByAvoraId;
  final DateTime? reviewedAt;
  final String? decisionReason;
}

class AvoraSellerApplicationAuditEvent {
  const AvoraSellerApplicationAuditEvent({
    required this.auditId,
    required this.applicationId,
    required this.actorAvoraId,
    required this.fromStatus,
    required this.toStatus,
    required this.occurredAt,
    required this.reason,
  });

  final String auditId;
  final String applicationId;
  final String actorAvoraId;
  final AvoraSellerApplicationStatus fromStatus;
  final AvoraSellerApplicationStatus toStatus;
  final DateTime occurredAt;
  final String reason;
}

class AvoraSellerOnboardingDecision {
  const AvoraSellerOnboardingDecision({
    required this.allowed,
    required this.reason,
    this.application,
    this.auditEvent,
  });

  final bool allowed;
  final AvoraSellerOnboardingDenyReason reason;
  final AvoraSellerApplication? application;
  final AvoraSellerApplicationAuditEvent? auditEvent;
}

class AvoraSellerOnboardingEngine {
  const AvoraSellerOnboardingEngine._();

  static AvoraSellerOnboardingDecision submitMerchantSponsored({
    required String applicationId,
    required String applicantSellerAvoraId,
    required String sponsorMerchantAvoraId,
    required String countryCode,
    required AvoraCountryCommerceGate countryGate,
    required String policyVersion,
    required DateTime now,
  }) {
    final applicant = applicantSellerAvoraId.trim();
    final sponsor = sponsorMerchantAvoraId.trim();
    final country = countryCode.trim().toUpperCase();

    if (applicant.isEmpty) {
      return const AvoraSellerOnboardingDecision(
        allowed: false,
        reason: AvoraSellerOnboardingDenyReason.invalidApplicant,
      );
    }

    if (sponsor.isEmpty) {
      return const AvoraSellerOnboardingDecision(
        allowed: false,
        reason: AvoraSellerOnboardingDenyReason.invalidSponsor,
      );
    }

    if (country.isEmpty ||
        countryGate.countryCode.trim().toUpperCase() != country ||
        !countryGate.effectiveAt(now)) {
      return const AvoraSellerOnboardingDecision(
        allowed: false,
        reason: AvoraSellerOnboardingDenyReason.invalidCountry,
      );
    }

    if (!countryGate.merchantEnabled) {
      return const AvoraSellerOnboardingDecision(
        allowed: false,
        reason: AvoraSellerOnboardingDenyReason.merchantDisabledInCountry,
      );
    }

    if (!countryGate.sellerEnabled) {
      return const AvoraSellerOnboardingDecision(
        allowed: false,
        reason: AvoraSellerOnboardingDenyReason.sellerDisabledInCountry,
      );
    }

    return AvoraSellerOnboardingDecision(
      allowed: true,
      reason: AvoraSellerOnboardingDenyReason.none,
      application: AvoraSellerApplication(
        applicationId: applicationId,
        applicantSellerAvoraId: applicant,
        sponsorMerchantAvoraId: sponsor,
        countryCode: country,
        status: AvoraSellerApplicationStatus.pendingReview,
        submittedAt: now,
        policyVersion: policyVersion,
      ),
    );
  }

  static AvoraSellerOnboardingDecision review({
    required AvoraSellerApplication application,
    required String reviewerAvoraId,
    required bool reviewerHasSellerApprovalPower,
    required AvoraSellerReviewAction action,
    required String reasonText,
    required String auditId,
    required DateTime now,
  }) {
    final reviewer = reviewerAvoraId.trim();

    if (!reviewerHasSellerApprovalPower || reviewer.isEmpty) {
      return const AvoraSellerOnboardingDecision(
        allowed: false,
        reason: AvoraSellerOnboardingDenyReason.reviewerUnauthorized,
      );
    }

    /// Sponsoring Merchant can never approve/reject its own sponsored Seller.
    if (reviewer == application.sponsorMerchantAvoraId) {
      return const AvoraSellerOnboardingDecision(
        allowed: false,
        reason: AvoraSellerOnboardingDenyReason.merchantCannotSelfApprove,
      );
    }

    if (application.status != AvoraSellerApplicationStatus.pendingReview &&
        application.status != AvoraSellerApplicationStatus.changesRequested) {
      return const AvoraSellerOnboardingDecision(
        allowed: false,
        reason: AvoraSellerOnboardingDenyReason.invalidApplicationStatus,
      );
    }

    final nextStatus = switch (action) {
      AvoraSellerReviewAction.requestChanges =>
        AvoraSellerApplicationStatus.changesRequested,
      AvoraSellerReviewAction.approve => AvoraSellerApplicationStatus.approved,
      AvoraSellerReviewAction.reject => AvoraSellerApplicationStatus.rejected,
    };

    final updated = AvoraSellerApplication(
      applicationId: application.applicationId,
      applicantSellerAvoraId: application.applicantSellerAvoraId,
      sponsorMerchantAvoraId: application.sponsorMerchantAvoraId,
      countryCode: application.countryCode,
      status: nextStatus,
      submittedAt: application.submittedAt,
      policyVersion: application.policyVersion,
      reviewedByAvoraId: reviewer,
      reviewedAt: now,
      decisionReason: reasonText,
    );

    return AvoraSellerOnboardingDecision(
      allowed: true,
      reason: AvoraSellerOnboardingDenyReason.none,
      application: updated,
      auditEvent: AvoraSellerApplicationAuditEvent(
        auditId: auditId,
        applicationId: application.applicationId,
        actorAvoraId: reviewer,
        fromStatus: application.status,
        toStatus: nextStatus,
        occurredAt: now,
        reason: reasonText,
      ),
    );
  }

  static bool sellerCapabilityActivatesOnlyAfterApproval(
    AvoraSellerApplication application,
  ) =>
      application.status == AvoraSellerApplicationStatus.approved;

  static bool merchantCanSelfApproveSponsoredSeller() => false;

  static bool clientCanEnableSellerOrMerchantCountryGate() => false;

  static bool applicationAuditCanBeSilentlyDeleted() => false;

  /// Sponsorship alone never earns money.
  static bool sponsorBenefitRequiresQualifyingVerifiedActivity() => true;

  /// Fraud/refund/reversal may reverse applicable sponsor benefits.
  static bool sponsorBenefitMustSupportReversal() => true;

  /// Same immutable AVORA ID remains authoritative after Seller activation.
  static bool sellerUsesExistingImmutableAvoraId() => true;
}
