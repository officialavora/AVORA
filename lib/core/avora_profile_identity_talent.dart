enum AvoraProfileGender {
  male,
  female,
  nonBinary,
  selfDescribed,
  preferNotToSay,
}

enum AvoraProfileIdentityVisibility {
  private,
  friendsOnly,
  public,
}

enum AvoraTalentVerificationState {
  unverified,
  pendingReview,
  verified,
  suspended,
}

class AvoraProfileIdentity {
  const AvoraProfileIdentity({
    required this.immutableAvoraId,
    required this.gender,
    required this.visibility,
    this.selfDescription,
  });

  final String immutableAvoraId;

  /// Optional user-controlled profile identity.
  /// This never creates role, authority, salary, or reward eligibility.
  final AvoraProfileGender? gender;

  final AvoraProfileIdentityVisibility visibility;

  /// Used only when gender == selfDescribed.
  /// Kept separate from backend role/capability logic.
  final String? selfDescription;

  bool get valid {
    if (immutableAvoraId.trim().isEmpty) return false;

    if (gender == AvoraProfileGender.selfDescribed) {
      return selfDescription != null && selfDescription!.trim().isNotEmpty;
    }

    return true;
  }
}

class AvoraRelationshipPreferenceProfile {
  const AvoraRelationshipPreferenceProfile({
    required this.enabled,
    required this.explicitConsentGranted,
    required this.visibleToMatchingSystemOnly,
    this.preferenceKeys = const {},
  });

  /// Matching/relationship preferences are optional.
  final bool enabled;

  /// User must deliberately opt in.
  final bool explicitConsentGranted;

  /// Preferences are not public-profile authority data.
  final bool visibleToMatchingSystemOnly;

  /// Opaque future-configurable preference keys.
  /// Core logic does not infer sexual orientation from them.
  final Set<String> preferenceKeys;

  bool get usable =>
      enabled && explicitConsentGranted && visibleToMatchingSystemOnly;
}

class AvoraTalentPresentationProfile {
  const AvoraTalentPresentationProfile({
    required this.immutableAvoraId,
    required this.talentCategoryKey,
    required this.verificationState,
    required this.creatorProofVerified,
    required this.discoveryEnabled,
    required this.eventEligible,
    required this.leaderboardOptIn,
    this.displayTitle,
  });

  final String immutableAvoraId;

  /// Reuses existing data-driven Talent/Creator category infrastructure.
  /// Example keys may represent singer/dancer/musician/etc.
  final String talentCategoryKey;

  final AvoraTalentVerificationState verificationState;

  /// Must come from existing creator/talent proof/authenticity pipeline.
  final bool creatorProofVerified;

  final bool discoveryEnabled;
  final bool eventEligible;
  final bool leaderboardOptIn;

  final String? displayTitle;

  bool get verifiedTalent =>
      verificationState == AvoraTalentVerificationState.verified &&
      creatorProofVerified;

  bool get discoverable =>
      verifiedTalent && discoveryEnabled && talentCategoryKey.trim().isNotEmpty;

  bool get eligibleForTalentLeaderboardPresentation =>
      verifiedTalent && leaderboardOptIn;
}

class AvoraTalentBadgeDecision {
  const AvoraTalentBadgeDecision({
    required this.showVerifiedTalentBadge,
    required this.showTalentCategory,
    required this.discoveryEligible,
    required this.leaderboardPresentationEligible,
  });

  final bool showVerifiedTalentBadge;
  final bool showTalentCategory;
  final bool discoveryEligible;
  final bool leaderboardPresentationEligible;
}

class AvoraTalentPresentationEngine {
  const AvoraTalentPresentationEngine._();

  static AvoraTalentBadgeDecision resolve(
    AvoraTalentPresentationProfile profile,
  ) {
    final verified = profile.verifiedTalent;

    return AvoraTalentBadgeDecision(
      showVerifiedTalentBadge: verified,
      showTalentCategory: profile.talentCategoryKey.trim().isNotEmpty,
      discoveryEligible: profile.discoverable,
      leaderboardPresentationEligible:
          profile.eligibleForTalentLeaderboardPresentation,
    );
  }

  /// Existing creator/talent category engine remains authoritative.
  static bool existingTalentCategoryModelRemainsAuthoritative() => true;

  /// Existing creator proof/authenticity pipeline decides verification.
  static bool selfClaimCanGrantVerifiedTalentBadge() => false;

  /// Existing leaderboard engine calculates ranking.
  static bool thisLayerCalculatesLeaderboardRank() => false;

  /// Existing event infrastructure decides actual event participation.
  static bool thisLayerCreatesEventAuthority() => false;

  /// Talent presentation alone never creates backend authority.
  static bool talentBadgeGrantsBackendAuthority() => false;

  /// Talent title/category alone never creates salary/reward entitlement.
  static bool talentPresentationCreatesEarnings() => false;
}

class AvoraIdentityRoleSeparationPolicy {
  const AvoraIdentityRoleSeparationPolicy._();

  static bool genderCreatesRole() => false;

  static bool genderCreatesAuthority() => false;

  static bool genderAffectsSalaryEligibility() => false;

  static bool genderAffectsModerationProtection() => false;

  static bool sexualOrientationIsAuthorityRole() => false;

  static bool sexualOrientationCollectedByDefault() => false;

  static bool relationshipPreferencesAreOptional() => true;

  static bool relationshipPreferencesRequireConsent() => true;

  static bool relationshipPreferencesArePublicByDefault() => false;

  static bool profileIdentityCanModifyImmutableAvoraId() => false;

  static bool creatorTalentCapabilityRemainsSeparateFromGender() => true;
}
