class AvoraProtectedIdentityProfile {
  const AvoraProtectedIdentityProfile({
    required this.avoraId,
    required this.authorizedTitles,
    required this.normalizedDisplayName,
    required this.profileMediaFingerprint,
  });

  final String avoraId;
  final Set<String> authorizedTitles;
  final String normalizedDisplayName;
  final String profileMediaFingerprint;
}

class AvoraIdentityImpersonationDecision {
  const AvoraIdentityImpersonationDecision({
    required this.allowed,
    required this.reason,
    required this.reviewRequired,
  });

  final bool allowed;
  final String reason;
  final bool reviewRequired;
}

class AvoraIdentityImpersonationGuard {
  AvoraIdentityImpersonationGuard({
    Set<String>? reservedTitles,
  }) : _reservedTitles = {
          'official',
          'manager',
          'super admin',
          'admin',
          'bd',
          'seller',
          'merchant',
          'agency',
          'host',
          'support',
          ...?reservedTitles,
        };

  final Set<String> _reservedTitles;

  String normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-.]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  Set<String> protectedTitlesIn(String value) {
    final normalized = normalize(value);
    final found = <String>{};

    for (final title in _reservedTitles) {
      final pattern = RegExp(
        r'(^|\s)' + RegExp.escape(title) + r'($|\s)',
        caseSensitive: false,
      );

      if (pattern.hasMatch(normalized)) {
        found.add(title);
      }
    }

    return found;
  }

  AvoraIdentityImpersonationDecision validateTitleUse({
    required String requestedIdentityText,
    required Set<String> authorizedTitles,
    required bool actorIsVerifiedOwner,
  }) {
    if (actorIsVerifiedOwner) {
      return const AvoraIdentityImpersonationDecision(
        allowed: true,
        reason: 'owner_identity_override',
        reviewRequired: false,
      );
    }

    final requestedTitles = protectedTitlesIn(requestedIdentityText);

    if (requestedTitles.isEmpty) {
      return const AvoraIdentityImpersonationDecision(
        allowed: true,
        reason: 'no_protected_title_used',
        reviewRequired: false,
      );
    }

    final normalizedAuthorized = authorizedTitles.map(normalize).toSet();

    final unauthorized = requestedTitles.where(
      (title) => !normalizedAuthorized.contains(title),
    );

    if (unauthorized.isNotEmpty) {
      return const AvoraIdentityImpersonationDecision(
        allowed: false,
        reason: 'unauthorized_official_title',
        reviewRequired: true,
      );
    }

    return const AvoraIdentityImpersonationDecision(
      allowed: true,
      reason: 'authorized_official_title',
      reviewRequired: false,
    );
  }

  AvoraIdentityImpersonationDecision validateProtectedName({
    required String actorAvoraId,
    required String requestedDisplayName,
    required Iterable<AvoraProtectedIdentityProfile> protectedProfiles,
    required bool actorIsVerifiedOwner,
  }) {
    if (actorIsVerifiedOwner) {
      return const AvoraIdentityImpersonationDecision(
        allowed: true,
        reason: 'owner_identity_override',
        reviewRequired: false,
      );
    }

    final requested = normalize(requestedDisplayName);

    for (final profile in protectedProfiles) {
      if (profile.avoraId == actorAvoraId) continue;

      if (requested.isNotEmpty && requested == profile.normalizedDisplayName) {
        return const AvoraIdentityImpersonationDecision(
          allowed: false,
          reason: 'protected_official_name_collision',
          reviewRequired: true,
        );
      }
    }

    return const AvoraIdentityImpersonationDecision(
      allowed: true,
      reason: 'display_name_available',
      reviewRequired: false,
    );
  }

  AvoraIdentityImpersonationDecision validateProfileMedia({
    required String actorAvoraId,
    required String requestedFingerprint,
    required Iterable<AvoraProtectedIdentityProfile> protectedProfiles,
    required bool actorIsVerifiedOwner,
  }) {
    if (actorIsVerifiedOwner) {
      return const AvoraIdentityImpersonationDecision(
        allowed: true,
        reason: 'owner_identity_override',
        reviewRequired: false,
      );
    }

    final fingerprint = requestedFingerprint.trim();

    if (fingerprint.isEmpty) {
      return const AvoraIdentityImpersonationDecision(
        allowed: true,
        reason: 'no_profile_media_fingerprint',
        reviewRequired: false,
      );
    }

    for (final profile in protectedProfiles) {
      if (profile.avoraId == actorAvoraId) continue;

      if (profile.profileMediaFingerprint == fingerprint) {
        return const AvoraIdentityImpersonationDecision(
          allowed: false,
          reason: 'protected_profile_media_clone',
          reviewRequired: true,
        );
      }
    }

    return const AvoraIdentityImpersonationDecision(
      allowed: true,
      reason: 'profile_media_available',
      reviewRequired: false,
    );
  }

  static bool officialTitlesMustBeServerAuthorized() => true;
  static bool sellerTitleMustBeProtected() => true;
  static bool usersMustNotSelfClaimOfficialAuthority() => true;
  static bool protectedOfficialNamesMustResistCloning() => true;
  static bool protectedOfficialDpMustResistCloning() => true;
  static bool ownerMayManuallyOverrideIdentityPresentation() => true;
  static bool falsePositiveCasesMustSupportHumanReview() => true;
  static bool futureOfficialTitlesMustUseSameGuard() => true;
}
