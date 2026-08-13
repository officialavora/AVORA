enum AvoraPremiumMembershipKind {
  none,
  vip,
  svip,
}

enum AvoraPremiumContentKind {
  gift,
  reaction,
  entryEffect,
  effectPack,
  frame,
  profileEffect,
  roomEffect,
  pkEffect,
  custom,
}

enum AvoraLockedContentVisibility {
  hidden,
  lockedPreview,
}

enum AvoraPremiumAccessState {
  hidden,
  lockedPreview,
  usable,
}

enum AvoraPremiumAccessDenyReason {
  none,
  contentDisabled,
  policyNotEffective,
  countryNotAllowed,
  membershipExpired,
  vipTierTooLow,
  svipTierTooLow,
  membershipNotEligible,
  identityLevelTooLow,
  missingEntitlement,
  eventNotEligible,
}

class AvoraPremiumUserAccess {
  final String avoraId;

  final AvoraPremiumMembershipKind membershipKind;

  /// 0 means no active premium tier.
  final int membershipTier;

  final DateTime? membershipExpiresAt;

  final int identityLevel;

  final Set<String> entitlementRefs;

  const AvoraPremiumUserAccess({
    required this.avoraId,
    required this.membershipKind,
    required this.membershipTier,
    required this.identityLevel,
    this.membershipExpiresAt,
    this.entitlementRefs = const {},
  })  : assert(membershipTier >= 0),
        assert(identityLevel >= 0);

  bool membershipActiveAt(DateTime now) {
    if (membershipKind == AvoraPremiumMembershipKind.none ||
        membershipTier <= 0) {
      return false;
    }

    final expiry = membershipExpiresAt;

    if (expiry != null && !now.isBefore(expiry)) {
      return false;
    }

    return true;
  }
}

class AvoraPremiumContentPolicy {
  final String policyId;

  final AvoraPremiumContentKind contentKind;

  final String contentRef;

  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;

  final bool enabled;

  /// If locked, should the user see a premium preview or nothing?
  final AvoraLockedContentVisibility lockedVisibility;

  /// Null means VIP is not an eligible route.
  final int? minimumVipTier;

  /// Null means SVIP is not an eligible route.
  final int? minimumSvipTier;

  /// Optional ID-level gate in addition to premium membership.
  final int minimumIdentityLevel;

  /// Optional purchase/achievement/subscription entitlement.
  final Set<String> requiredEntitlementRefs;

  /// Empty means global.
  final Set<String> allowedCountryCodes;

  /// Empty means no event restriction.
  final Set<String> allowedEventIds;

  const AvoraPremiumContentPolicy({
    required this.policyId,
    required this.contentKind,
    required this.contentRef,
    required this.effectiveFrom,
    required this.enabled,
    this.effectiveUntil,
    this.lockedVisibility = AvoraLockedContentVisibility.lockedPreview,
    this.minimumVipTier,
    this.minimumSvipTier,
    this.minimumIdentityLevel = 0,
    this.requiredEntitlementRefs = const {},
    this.allowedCountryCodes = const {},
    this.allowedEventIds = const {},
  })  : assert(
          minimumVipTier == null || minimumVipTier >= 1,
        ),
        assert(
          minimumSvipTier == null || minimumSvipTier >= 1,
        ),
        assert(minimumIdentityLevel >= 0);

  bool effectiveAt(DateTime now) {
    if (!enabled || now.isBefore(effectiveFrom)) {
      return false;
    }

    final until = effectiveUntil;

    if (until != null && !now.isBefore(until)) {
      return false;
    }

    return true;
  }

  bool countryAllowed(String countryCode) {
    if (allowedCountryCodes.isEmpty) {
      return true;
    }

    final normalized = countryCode.trim().toUpperCase();

    return allowedCountryCodes
        .map((code) => code.trim().toUpperCase())
        .contains(normalized);
  }

  bool eventAllowed(String? eventId) {
    if (allowedEventIds.isEmpty) {
      return true;
    }

    return eventId != null && allowedEventIds.contains(eventId);
  }
}

class AvoraPremiumContentDecision {
  final AvoraPremiumAccessState state;

  final AvoraPremiumAccessDenyReason reason;

  final bool canView;
  final bool canUse;

  final String policyId;
  final String contentRef;

  const AvoraPremiumContentDecision({
    required this.state,
    required this.reason,
    required this.canView,
    required this.canUse,
    required this.policyId,
    required this.contentRef,
  });
}

class AvoraPremiumContentGate {
  const AvoraPremiumContentGate._();

  static AvoraPremiumContentDecision evaluate({
    required AvoraPremiumUserAccess user,
    required AvoraPremiumContentPolicy policy,
    required String countryCode,
    required String? eventId,
    required DateTime now,
  }) {
    if (!policy.enabled) {
      return _deny(
        policy: policy,
        reason: AvoraPremiumAccessDenyReason.contentDisabled,
      );
    }

    if (!policy.effectiveAt(now)) {
      return _deny(
        policy: policy,
        reason: AvoraPremiumAccessDenyReason.policyNotEffective,
      );
    }

    if (!policy.countryAllowed(countryCode)) {
      return _deny(
        policy: policy,
        reason: AvoraPremiumAccessDenyReason.countryNotAllowed,
      );
    }

    if (!policy.eventAllowed(eventId)) {
      return _deny(
        policy: policy,
        reason: AvoraPremiumAccessDenyReason.eventNotEligible,
      );
    }

    final requiresPremium =
        policy.minimumVipTier != null || policy.minimumSvipTier != null;

    if (requiresPremium && !user.membershipActiveAt(now)) {
      return _deny(
        policy: policy,
        reason: user.membershipKind == AvoraPremiumMembershipKind.none
            ? AvoraPremiumAccessDenyReason.membershipNotEligible
            : AvoraPremiumAccessDenyReason.membershipExpired,
      );
    }

    if (requiresPremium) {
      final membershipPass = switch (user.membershipKind) {
        AvoraPremiumMembershipKind.vip => policy.minimumVipTier != null &&
            user.membershipTier >= policy.minimumVipTier!,
        AvoraPremiumMembershipKind.svip => policy.minimumSvipTier != null &&
            user.membershipTier >= policy.minimumSvipTier!,
        AvoraPremiumMembershipKind.none => false,
      };

      if (!membershipPass) {
        final reason = switch (user.membershipKind) {
          AvoraPremiumMembershipKind.vip =>
            AvoraPremiumAccessDenyReason.vipTierTooLow,
          AvoraPremiumMembershipKind.svip =>
            AvoraPremiumAccessDenyReason.svipTierTooLow,
          AvoraPremiumMembershipKind.none =>
            AvoraPremiumAccessDenyReason.membershipNotEligible,
        };

        return _deny(
          policy: policy,
          reason: reason,
        );
      }
    }

    if (user.identityLevel < policy.minimumIdentityLevel) {
      return _deny(
        policy: policy,
        reason: AvoraPremiumAccessDenyReason.identityLevelTooLow,
      );
    }

    if (!user.entitlementRefs.containsAll(
      policy.requiredEntitlementRefs,
    )) {
      return _deny(
        policy: policy,
        reason: AvoraPremiumAccessDenyReason.missingEntitlement,
      );
    }

    return AvoraPremiumContentDecision(
      state: AvoraPremiumAccessState.usable,
      reason: AvoraPremiumAccessDenyReason.none,
      canView: true,
      canUse: true,
      policyId: policy.policyId,
      contentRef: policy.contentRef,
    );
  }

  static AvoraPremiumContentDecision _deny({
    required AvoraPremiumContentPolicy policy,
    required AvoraPremiumAccessDenyReason reason,
  }) {
    final preview =
        policy.lockedVisibility == AvoraLockedContentVisibility.lockedPreview;

    return AvoraPremiumContentDecision(
      state: preview
          ? AvoraPremiumAccessState.lockedPreview
          : AvoraPremiumAccessState.hidden,
      reason: reason,
      canView: preview,
      canUse: false,
      policyId: policy.policyId,
      contentRef: policy.contentRef,
    );
  }

  /// Locked preview may attract users to upgrade,
  /// but it never gives send/use permission.
  static bool lockedPreviewCanUsePremiumContent() {
    return false;
  }

  /// VIP/SVIP is a commercial entitlement, not staff authority.
  static bool premiumMembershipGrantsModerationAuthority() {
    return false;
  }

  /// Premium status never bypasses safety/moderation.
  static bool premiumMembershipBypassesSafety() {
    return false;
  }

  /// Gift settlement/counting stays in the economy engines.
  static bool premiumGateChangesGiftSettlement() {
    return false;
  }

  /// Gift, emoji, entry and future content can share this gate.
  static bool supportsMultiplePremiumContentKinds() {
    return true;
  }

  /// Tier requirements are data/configuration, not hardcoded per asset.
  static bool everyPremiumAssetRequiresCoreCodeChange() {
    return false;
  }
}
