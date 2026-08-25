enum AvoraReferralRevenueSource {
  recharge,
  game,
  targetPerformance,
  purchase,
  event,
  custom,
}

enum AvoraReferralRevenueDenyReason {
  none,
  policyInactive,
  invalidAttribution,
  selfReferral,
  circularReferralRisk,
  sourceNotEligible,
  inviterNotVerified,
  inviteeNotVerified,
  countryNotEligible,
  outsideReferralWindow,
  invalidEligibleAmount,
  fraudOrRiskHold,
  eventCapExhausted,
  periodCapExhausted,
}

class AvoraReferralRevenueAttribution {
  const AvoraReferralRevenueAttribution({
    required this.inviterAvoraId,
    required this.inviteeAvoraId,
    required this.attributedAt,
    this.campaignId,
  });

  final String inviterAvoraId;
  final String inviteeAvoraId;
  final DateTime attributedAt;
  final String? campaignId;
}

class AvoraReferralRevenuePolicy {
  const AvoraReferralRevenuePolicy({
    required this.policyId,
    required this.version,
    required this.shareBps,
    required this.eligibleSources,
    this.active = true,
    this.referralWindowDays,
    this.perEventCapMinor,
    this.periodCapMinor,
    this.periodDays,
    this.requireVerifiedInviter = true,
    this.requireVerifiedInvitee = true,
    this.allowedCountryCodes = const {},
    this.blockedCountryCodes = const {},
    this.effectiveFrom,
    this.effectiveUntil,
  });

  final String policyId;

  /// Historical earning records retain this version.
  final int version;

  /// 10000 bps = 100%.
  final int shareBps;

  final Set<AvoraReferralRevenueSource> eligibleSources;

  final bool active;

  /// null means no time expiry / permanent attribution where policy permits.
  final int? referralWindowDays;

  /// Optional maximum earning from one eligible activity.
  final int? perEventCapMinor;

  /// Optional earning ceiling in a configured rolling/accounting period.
  final int? periodCapMinor;
  final int? periodDays;

  final bool requireVerifiedInviter;
  final bool requireVerifiedInvitee;

  /// Empty allowed set means globally eligible unless explicitly blocked.
  final Set<String> allowedCountryCodes;
  final Set<String> blockedCountryCodes;

  final DateTime? effectiveFrom;
  final DateTime? effectiveUntil;

  bool isEffectiveAt(DateTime now) {
    if (!active) return false;
    if (effectiveFrom != null && now.isBefore(effectiveFrom!)) return false;
    if (effectiveUntil != null && now.isAfter(effectiveUntil!)) return false;
    return true;
  }
}

class AvoraReferralRevenueActivity {
  const AvoraReferralRevenueActivity({
    required this.activityId,
    required this.inviteeAvoraId,
    required this.source,
    required this.eligibleAmountMinor,
    required this.occurredAt,
    required this.countryCode,
    this.inviterVerified = false,
    this.inviteeVerified = false,
    this.fraudOrRiskHold = false,
    this.circularReferralRisk = false,
  });

  final String activityId;
  final String inviteeAvoraId;
  final AvoraReferralRevenueSource source;

  /// Eligible settled base amount only.
  /// This is not automatically the user's total spend or withdrawable value.
  final int eligibleAmountMinor;

  final DateTime occurredAt;
  final String countryCode;

  final bool inviterVerified;
  final bool inviteeVerified;

  /// Server-side risk engine may suppress earning.
  final bool fraudOrRiskHold;

  /// Supplied by authoritative referral-graph validation.
  final bool circularReferralRisk;
}

class AvoraReferralRevenueShareDecision {
  const AvoraReferralRevenueShareDecision({
    required this.allowed,
    required this.reason,
    required this.shareMinor,
    this.policyId,
    this.policyVersion,
    this.activityId,
    this.inviterAvoraId,
    this.inviteeAvoraId,
  });

  final bool allowed;
  final AvoraReferralRevenueDenyReason reason;

  /// Positive for new earning, negative for an authoritative reversal.
  final int shareMinor;

  final String? policyId;
  final int? policyVersion;
  final String? activityId;
  final String? inviterAvoraId;
  final String? inviteeAvoraId;
}

class AvoraReferralRevenueShareEngine {
  const AvoraReferralRevenueShareEngine._();

  static AvoraReferralRevenueShareDecision evaluate({
    required AvoraReferralRevenuePolicy policy,
    required AvoraReferralRevenueAttribution attribution,
    required AvoraReferralRevenueActivity activity,
    required DateTime now,
    int alreadyEarnedInPeriodMinor = 0,
  }) {
    if (!policy.isEffectiveAt(now)) {
      return _deny(AvoraReferralRevenueDenyReason.policyInactive);
    }

    final inviter = attribution.inviterAvoraId.trim();
    final invitee = attribution.inviteeAvoraId.trim();

    if (inviter.isEmpty ||
        invitee.isEmpty ||
        activity.inviteeAvoraId.trim() != invitee) {
      return _deny(AvoraReferralRevenueDenyReason.invalidAttribution);
    }

    if (inviter == invitee) {
      return _deny(AvoraReferralRevenueDenyReason.selfReferral);
    }

    if (activity.circularReferralRisk) {
      return _deny(AvoraReferralRevenueDenyReason.circularReferralRisk);
    }

    if (!policy.eligibleSources.contains(activity.source)) {
      return _deny(AvoraReferralRevenueDenyReason.sourceNotEligible);
    }

    if (policy.requireVerifiedInviter && !activity.inviterVerified) {
      return _deny(AvoraReferralRevenueDenyReason.inviterNotVerified);
    }

    if (policy.requireVerifiedInvitee && !activity.inviteeVerified) {
      return _deny(AvoraReferralRevenueDenyReason.inviteeNotVerified);
    }

    final country = activity.countryCode.trim().toUpperCase();

    if (policy.blockedCountryCodes
        .map((e) => e.toUpperCase())
        .contains(country)) {
      return _deny(AvoraReferralRevenueDenyReason.countryNotEligible);
    }

    if (policy.allowedCountryCodes.isNotEmpty &&
        !policy.allowedCountryCodes
            .map((e) => e.toUpperCase())
            .contains(country)) {
      return _deny(AvoraReferralRevenueDenyReason.countryNotEligible);
    }

    if (policy.referralWindowDays != null) {
      final expiry = attribution.attributedAt.add(
        Duration(days: policy.referralWindowDays!),
      );

      if (activity.occurredAt.isAfter(expiry)) {
        return _deny(
          AvoraReferralRevenueDenyReason.outsideReferralWindow,
        );
      }
    }

    if (activity.eligibleAmountMinor <= 0 ||
        policy.shareBps <= 0 ||
        policy.shareBps > 10000) {
      return _deny(
        AvoraReferralRevenueDenyReason.invalidEligibleAmount,
      );
    }

    if (activity.fraudOrRiskHold) {
      return _deny(AvoraReferralRevenueDenyReason.fraudOrRiskHold);
    }

    var share = (activity.eligibleAmountMinor * policy.shareBps) ~/ 10000;

    if (policy.perEventCapMinor != null) {
      if (policy.perEventCapMinor! <= 0) {
        return _deny(AvoraReferralRevenueDenyReason.eventCapExhausted);
      }

      if (share > policy.perEventCapMinor!) {
        share = policy.perEventCapMinor!;
      }
    }

    if (policy.periodCapMinor != null) {
      final remaining = policy.periodCapMinor! - alreadyEarnedInPeriodMinor;

      if (remaining <= 0) {
        return _deny(AvoraReferralRevenueDenyReason.periodCapExhausted);
      }

      if (share > remaining) {
        share = remaining;
      }
    }

    if (share <= 0) {
      return _deny(AvoraReferralRevenueDenyReason.eventCapExhausted);
    }

    return AvoraReferralRevenueShareDecision(
      allowed: true,
      reason: AvoraReferralRevenueDenyReason.none,
      shareMinor: share,
      policyId: policy.policyId,
      policyVersion: policy.version,
      activityId: activity.activityId,
      inviterAvoraId: inviter,
      inviteeAvoraId: invitee,
    );
  }

  /// Refunds/chargebacks/reversals create an auditable negative adjustment
  /// against the exact previously credited referral earning.
  static AvoraReferralRevenueShareDecision reversal({
    required String activityId,
    required String inviterAvoraId,
    required String inviteeAvoraId,
    required String policyId,
    required int policyVersion,
    required int originallyCreditedShareMinor,
  }) {
    if (originallyCreditedShareMinor <= 0) {
      return _deny(
        AvoraReferralRevenueDenyReason.invalidEligibleAmount,
      );
    }

    return AvoraReferralRevenueShareDecision(
      allowed: true,
      reason: AvoraReferralRevenueDenyReason.none,
      shareMinor: -originallyCreditedShareMinor,
      policyId: policyId,
      policyVersion: policyVersion,
      activityId: activityId,
      inviterAvoraId: inviterAvoraId,
      inviteeAvoraId: inviteeAvoraId,
    );
  }

  static AvoraReferralRevenueShareDecision _deny(
    AvoraReferralRevenueDenyReason reason,
  ) {
    return AvoraReferralRevenueShareDecision(
      allowed: false,
      reason: reason,
      shareMinor: 0,
    );
  }

  /// Policy/value changes come from trusted Owner/backend configuration.
  static bool clientCanChangeSharePolicy() => false;

  /// Mobile client cannot directly credit referral earnings.
  static bool clientCanSelfCreditReferralRevenue() => false;

  /// Referral earnings remain a separate ledger component until the
  /// applicable settlement/withdrawal policy declares them withdrawable.
  static bool automaticallyWithdrawable() => false;

  /// Attribution is bound to immutable AVORA IDs.
  static bool immutableAvoraIdsRequired() => true;

  /// Refund/chargeback must reverse prior referral credit.
  static bool reversalsMustClawBackPriorCredit() => true;
}
