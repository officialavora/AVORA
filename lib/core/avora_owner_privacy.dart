enum AvoraOwnerViewerKind {
  publicUser,
  staff,
  ownerSelf,
  trustedSecuritySystem,
}

enum AvoraOwnerPrivateField {
  personalName,
  personalAvatar,
  personalAvoraId,
  email,
  phone,
  linkedAuthProviders,
  recoveryIdentifiers,
  country,
  region,
  city,
  preciseLocation,
  currentLocation,
  homeAddress,
  deviceInformation,
  ipInformation,
}

class AvoraOwnerPrivacyDecision {
  const AvoraOwnerPrivacyDecision({
    required this.profileDiscoverable,
    required this.personalFieldsVisible,
    required this.locationVisible,
    required this.contactVisible,
    required this.recoveryVisible,
    required this.reason,
  });

  final bool profileDiscoverable;
  final bool personalFieldsVisible;
  final bool locationVisible;
  final bool contactVisible;
  final bool recoveryVisible;
  final String reason;
}

class AvoraOwnerPrivacyShield {
  static AvoraOwnerPrivacyDecision evaluate({
    required bool subjectIsOwner,
    required AvoraOwnerViewerKind viewer,
  }) {
    if (!subjectIsOwner) {
      return const AvoraOwnerPrivacyDecision(
        profileDiscoverable: true,
        personalFieldsVisible: true,
        locationVisible: false,
        contactVisible: false,
        recoveryVisible: false,
        reason: 'normalAccountUsesRegularPrivacyPolicy',
      );
    }

    switch (viewer) {
      case AvoraOwnerViewerKind.ownerSelf:
        return const AvoraOwnerPrivacyDecision(
          profileDiscoverable: true,
          personalFieldsVisible: true,
          locationVisible: true,
          contactVisible: true,
          recoveryVisible: true,
          reason: 'ownerViewingOwnPrivateAccount',
        );

      case AvoraOwnerViewerKind.trustedSecuritySystem:
        return const AvoraOwnerPrivacyDecision(
          profileDiscoverable: true,
          personalFieldsVisible: true,
          locationVisible: true,
          contactVisible: true,
          recoveryVisible: true,
          reason: 'trustedSecurityAuditContext',
        );

      case AvoraOwnerViewerKind.publicUser:
      case AvoraOwnerViewerKind.staff:
        return const AvoraOwnerPrivacyDecision(
          profileDiscoverable: false,
          personalFieldsVisible: false,
          locationVisible: false,
          contactVisible: false,
          recoveryVisible: false,
          reason: 'ownerPrivacyShield',
        );
    }
  }

  static bool canRevealField({
    required bool subjectIsOwner,
    required AvoraOwnerViewerKind viewer,
    required AvoraOwnerPrivateField field,
  }) {
    if (!subjectIsOwner) {
      return false;
    }

    return viewer == AvoraOwnerViewerKind.ownerSelf ||
        viewer == AvoraOwnerViewerKind.trustedSecuritySystem;
  }

  /// Staff-facing audit/history should not expose Owner's
  /// personal identity.
  static String safeActorLabel({
    required bool actorIsOwner,
    required String normalDisplayName,
  }) {
    if (actorIsOwner) return 'OWNER';
    return normalDisplayName;
  }

  /// Owner's private account should not appear in normal
  /// people search, nearby search, agency search, room-member
  /// discovery, suggested users, or public rankings merely
  /// because the account exists.
  static bool ownerAppearsInNormalDiscovery() => false;

  /// An Official Support account should be a separate public
  /// operational identity, not the Owner's private account.
  static bool ownerPrivateAccountDoublesAsPublicSupportAccount() => false;

  /// Privacy shielding does not reduce Owner's backend
  /// operational authority.
  static bool privacyShieldRemovesOwnerAuthority() => false;

  /// Raw passwords, OAuth/access/refresh tokens and signing
  /// secrets are never displayable, even to Owner.
  static bool rawSecretsEverDisplayable() => false;
}
