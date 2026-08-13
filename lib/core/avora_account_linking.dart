enum AvoraAuthProvider {
  google,
  facebook,
  apple,
  email,
  phone,
  custom,
}

enum AvoraLinkedIdentityStatus {
  active,
  revoked,
  disabled,
}

enum AvoraAuthDecisionType {
  existingAccount,
  newAccountEligible,
  linkAllowed,
  unlinkAllowed,
  denied,
}

enum AvoraAuthDenyReason {
  none,
  providerDisabled,
  providerAssertionInvalid,
  accountRestricted,
  recentAuthenticationRequired,
  linkedToAnotherAvoraAccount,
  providerAlreadyLinkedDifferentIdentity,
  identityNotLinked,
  lastUsableSignInMethod,
  accountCreationDisabled,
}

enum AvoraAuthAuditAction {
  signIn,
  accountCreated,
  providerLinked,
  providerUnlinked,
  providerRevoked,
  recoveryStarted,
  recoveryCompleted,
}

class AvoraProviderAssertion {
  final AvoraAuthProvider provider;

  /// Stable provider-side subject/user identifier.
  final String providerSubjectId;

  final bool providerVerified;

  final String? email;
  final bool emailVerified;

  final DateTime authenticatedAt;

  const AvoraProviderAssertion({
    required this.provider,
    required this.providerSubjectId,
    required this.providerVerified,
    required this.authenticatedAt,
    this.email,
    this.emailVerified = false,
  });
}

class AvoraLinkedIdentity {
  /// Immutable authoritative AVORA ID.
  final String avoraId;

  final AvoraAuthProvider provider;
  final String providerSubjectId;

  final AvoraLinkedIdentityStatus status;

  final DateTime linkedAt;
  final DateTime? lastAuthenticatedAt;
  final DateTime? revokedAt;

  const AvoraLinkedIdentity({
    required this.avoraId,
    required this.provider,
    required this.providerSubjectId,
    required this.status,
    required this.linkedAt,
    this.lastAuthenticatedAt,
    this.revokedAt,
  });

  bool get active => status == AvoraLinkedIdentityStatus.active;

  bool matches({
    required AvoraAuthProvider provider,
    required String providerSubjectId,
  }) {
    return this.provider == provider &&
        this.providerSubjectId == providerSubjectId;
  }
}

class AvoraAuthPolicy {
  final String policyVersionId;

  final Set<AvoraAuthProvider> enabledProviders;

  final bool allowNewAccountCreation;

  /// Sensitive link/unlink operations require recent
  /// successful authentication.
  final bool requireRecentAuthenticationForLinking;

  final bool requireRecentAuthenticationForUnlinking;

  final Duration recentAuthenticationWindow;

  /// Prevent one AVORA account from silently linking
  /// several different identities from the same provider.
  final bool allowMultipleIdentitiesPerProvider;

  const AvoraAuthPolicy({
    required this.policyVersionId,
    required this.enabledProviders,
    required this.allowNewAccountCreation,
    this.requireRecentAuthenticationForLinking = true,
    this.requireRecentAuthenticationForUnlinking = true,
    this.recentAuthenticationWindow = const Duration(minutes: 10),
    this.allowMultipleIdentitiesPerProvider = false,
  });
}

class AvoraAuthDecision {
  final bool allowed;

  final AvoraAuthDecisionType type;
  final AvoraAuthDenyReason reason;

  /// Existing authoritative account when resolved.
  final String? avoraId;

  const AvoraAuthDecision({
    required this.allowed,
    required this.type,
    required this.reason,
    this.avoraId,
  });
}

class AvoraAuthAuditEvent {
  final String auditEventId;

  final String avoraId;

  final AvoraAuthAuditAction action;

  final AvoraAuthProvider? provider;

  /// Store an internal safe reference/fingerprint,
  /// not raw OAuth/access tokens.
  final String? providerIdentityRef;

  final String policyVersionId;

  final DateTime occurredAt;

  final bool successful;

  const AvoraAuthAuditEvent({
    required this.auditEventId,
    required this.avoraId,
    required this.action,
    required this.policyVersionId,
    required this.occurredAt,
    required this.successful,
    this.provider,
    this.providerIdentityRef,
  });
}

class AvoraAccountLinkingEngine {
  const AvoraAccountLinkingEngine._();

  static bool _recentEnough({
    required DateTime now,
    required DateTime? lastAuthenticatedAt,
    required Duration window,
  }) {
    if (lastAuthenticatedAt == null) {
      return false;
    }

    if (lastAuthenticatedAt.isAfter(now)) {
      return false;
    }

    return now.difference(lastAuthenticatedAt) <= window;
  }

  static AvoraAuthDecision resolveSocialSignIn({
    required AvoraAuthPolicy policy,
    required AvoraProviderAssertion assertion,

    /// Account currently owning this exact provider subject.
    required String? linkedOwnerAvoraId,
    required bool accountRestricted,
  }) {
    if (!policy.enabledProviders.contains(assertion.provider)) {
      return const AvoraAuthDecision(
        allowed: false,
        type: AvoraAuthDecisionType.denied,
        reason: AvoraAuthDenyReason.providerDisabled,
      );
    }

    if (!assertion.providerVerified ||
        assertion.providerSubjectId.trim().isEmpty) {
      return const AvoraAuthDecision(
        allowed: false,
        type: AvoraAuthDecisionType.denied,
        reason: AvoraAuthDenyReason.providerAssertionInvalid,
      );
    }

    if (accountRestricted) {
      return const AvoraAuthDecision(
        allowed: false,
        type: AvoraAuthDecisionType.denied,
        reason: AvoraAuthDenyReason.accountRestricted,
      );
    }

    if (linkedOwnerAvoraId != null) {
      return AvoraAuthDecision(
        allowed: true,
        type: AvoraAuthDecisionType.existingAccount,
        reason: AvoraAuthDenyReason.none,
        avoraId: linkedOwnerAvoraId,
      );
    }

    if (!policy.allowNewAccountCreation) {
      return const AvoraAuthDecision(
        allowed: false,
        type: AvoraAuthDecisionType.denied,
        reason: AvoraAuthDenyReason.accountCreationDisabled,
      );
    }

    return const AvoraAuthDecision(
      allowed: true,
      type: AvoraAuthDecisionType.newAccountEligible,
      reason: AvoraAuthDenyReason.none,
    );
  }

  static AvoraAuthDecision canLinkProvider({
    required AvoraAuthPolicy policy,
    required String currentAvoraId,
    required AvoraProviderAssertion assertion,
    required List<AvoraLinkedIdentity> currentLinks,

    /// If another AVORA account already owns this
    /// exact provider identity, linking must fail.
    required String? existingOwnerAvoraId,
    required DateTime now,
    required DateTime? lastAuthenticatedAt,
    required bool accountRestricted,
  }) {
    if (!policy.enabledProviders.contains(assertion.provider)) {
      return const AvoraAuthDecision(
        allowed: false,
        type: AvoraAuthDecisionType.denied,
        reason: AvoraAuthDenyReason.providerDisabled,
      );
    }

    if (!assertion.providerVerified ||
        assertion.providerSubjectId.trim().isEmpty) {
      return const AvoraAuthDecision(
        allowed: false,
        type: AvoraAuthDecisionType.denied,
        reason: AvoraAuthDenyReason.providerAssertionInvalid,
      );
    }

    if (accountRestricted) {
      return const AvoraAuthDecision(
        allowed: false,
        type: AvoraAuthDecisionType.denied,
        reason: AvoraAuthDenyReason.accountRestricted,
      );
    }

    if (policy.requireRecentAuthenticationForLinking &&
        !_recentEnough(
          now: now,
          lastAuthenticatedAt: lastAuthenticatedAt,
          window: policy.recentAuthenticationWindow,
        )) {
      return const AvoraAuthDecision(
        allowed: false,
        type: AvoraAuthDecisionType.denied,
        reason: AvoraAuthDenyReason.recentAuthenticationRequired,
      );
    }

    if (existingOwnerAvoraId != null &&
        existingOwnerAvoraId != currentAvoraId) {
      return const AvoraAuthDecision(
        allowed: false,
        type: AvoraAuthDecisionType.denied,
        reason: AvoraAuthDenyReason.linkedToAnotherAvoraAccount,
      );
    }

    final exactAlreadyLinked = currentLinks.any(
      (link) =>
          link.active &&
          link.avoraId == currentAvoraId &&
          link.matches(
            provider: assertion.provider,
            providerSubjectId: assertion.providerSubjectId,
          ),
    );

    if (exactAlreadyLinked) {
      return AvoraAuthDecision(
        allowed: true,
        type: AvoraAuthDecisionType.linkAllowed,
        reason: AvoraAuthDenyReason.none,
        avoraId: currentAvoraId,
      );
    }

    if (!policy.allowMultipleIdentitiesPerProvider) {
      final sameProviderDifferentIdentity = currentLinks.any(
        (link) =>
            link.active &&
            link.avoraId == currentAvoraId &&
            link.provider == assertion.provider &&
            link.providerSubjectId != assertion.providerSubjectId,
      );

      if (sameProviderDifferentIdentity) {
        return const AvoraAuthDecision(
          allowed: false,
          type: AvoraAuthDecisionType.denied,
          reason: AvoraAuthDenyReason.providerAlreadyLinkedDifferentIdentity,
        );
      }
    }

    return AvoraAuthDecision(
      allowed: true,
      type: AvoraAuthDecisionType.linkAllowed,
      reason: AvoraAuthDenyReason.none,
      avoraId: currentAvoraId,
    );
  }

  static AvoraAuthDecision canUnlinkProvider({
    required AvoraAuthPolicy policy,
    required String currentAvoraId,
    required AvoraAuthProvider provider,
    required String providerSubjectId,
    required List<AvoraLinkedIdentity> currentLinks,
    required DateTime now,
    required DateTime? lastAuthenticatedAt,

    /// Password/verified phone/recovery key or another
    /// valid recovery route outside this provider link.
    required bool alternativeRecoveryMethodAvailable,
    required bool accountRestricted,
  }) {
    if (accountRestricted) {
      return const AvoraAuthDecision(
        allowed: false,
        type: AvoraAuthDecisionType.denied,
        reason: AvoraAuthDenyReason.accountRestricted,
      );
    }

    if (policy.requireRecentAuthenticationForUnlinking &&
        !_recentEnough(
          now: now,
          lastAuthenticatedAt: lastAuthenticatedAt,
          window: policy.recentAuthenticationWindow,
        )) {
      return const AvoraAuthDecision(
        allowed: false,
        type: AvoraAuthDecisionType.denied,
        reason: AvoraAuthDenyReason.recentAuthenticationRequired,
      );
    }

    final activeLinks = currentLinks
        .where(
          (link) => link.active && link.avoraId == currentAvoraId,
        )
        .toList(growable: false);

    final targetExists = activeLinks.any(
      (link) => link.matches(
        provider: provider,
        providerSubjectId: providerSubjectId,
      ),
    );

    if (!targetExists) {
      return const AvoraAuthDecision(
        allowed: false,
        type: AvoraAuthDecisionType.denied,
        reason: AvoraAuthDenyReason.identityNotLinked,
      );
    }

    if (activeLinks.length <= 1 && !alternativeRecoveryMethodAvailable) {
      return const AvoraAuthDecision(
        allowed: false,
        type: AvoraAuthDecisionType.denied,
        reason: AvoraAuthDenyReason.lastUsableSignInMethod,
      );
    }

    return AvoraAuthDecision(
      allowed: true,
      type: AvoraAuthDecisionType.unlinkAllowed,
      reason: AvoraAuthDenyReason.none,
      avoraId: currentAvoraId,
    );
  }

  /// Social-provider linking never replaces AVORA identity.
  static bool socialProviderCanChangeImmutableAvoraId() {
    return false;
  }

  /// Linking Google/Facebook/Apple to an existing account
  /// never creates another AVORA ID.
  static bool linkingProviderCreatesNewAvoraId() {
    return false;
  }

  /// Matching email text alone is insufficient to merge accounts.
  static bool matchingEmailAutomaticallyMergesAccounts() {
    return false;
  }

  /// Raw OAuth/access/refresh tokens do not belong in
  /// this core account-link record.
  static bool storesRawProviderTokensInAccountModel() {
    return false;
  }

  /// Existing invite/referral attribution remains its own engine.
  static bool socialLoginReplacesReferralAttributionEngine() {
    return false;
  }

  /// A signup reached through an invite/deep link can continue
  /// carrying the already-captured attribution context.
  static bool socialSignupCanPreserveReferralAttribution() {
    return true;
  }

  /// Provider display name/photo never overrides AVORA profile
  /// without an explicit profile policy/action.
  static bool providerProfileAutomaticallyOverridesAvoraProfile() {
    return false;
  }

  /// Auth provider identity never grants staff/moderation authority.
  static bool socialLoginProviderGrantsPlatformAuthority() {
    return false;
  }
}
