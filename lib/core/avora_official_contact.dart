enum AvoraOfficialCategory {
  manager,
  countryManager,
  superAdmin,
  admin,
  bd,
  csSupport,
  seller,
  merchant,
  agencySupport,
  eventManager,
  creatorSupport,
  other,
}

class AvoraOfficialPresentation {
  final bool officialTag;

  /// Catalog/asset references.
  final String? frameId;
  final String? entryEffectId;
  final String? nobleId;

  /// Public-facing title such as:
  /// India Manager, CS Support, Verified Seller.
  final String? publicTitle;

  const AvoraOfficialPresentation({
    this.officialTag = true,
    this.frameId,
    this.entryEffectId,
    this.nobleId,
    this.publicTitle,
  });
}

class AvoraOfficialContactProfile {
  final String userId;

  final AvoraOfficialCategory category;

  final bool approved;

  /// Some staff may remain internal-only.
  final bool listedForSupport;

  /// Allows users to contact this official without
  /// friendship/follow-back.
  final bool directContactEnabled;

  /// ISO country codes.
  /// Empty means global only when higher-level policy allows it.
  final Set<String> countryCodes;

  /// Language codes such as hi, en, ur, ar.
  final Set<String> languageCodes;

  final AvoraOfficialPresentation presentation;

  const AvoraOfficialContactProfile({
    required this.userId,
    required this.category,
    required this.approved,
    required this.listedForSupport,
    required this.directContactEnabled,
    required this.countryCodes,
    required this.languageCodes,
    required this.presentation,
  });

  bool supportsCountry(String countryCode) {
    final requested = countryCode.trim().toUpperCase();

    return countryCodes.any(
      (item) => item.trim().toUpperCase() == requested,
    );
  }

  bool supportsLanguage(String languageCode) {
    final requested = languageCode.trim().toLowerCase();

    return languageCodes.any(
      (item) => item.trim().toLowerCase() == requested,
    );
  }
}

enum AvoraDirectContactReason {
  allowedSocialRelationship,
  allowedOfficialSupport,
  requiresMessageRequest,
  officialUnavailable,
  blocked,
  requesterRiskBlocked,
  rateLimited,
}

class AvoraDirectContactContext {
  final bool friends;

  /// Both users follow each other.
  final bool mutualFollow;

  /// Existing Message Request was accepted.
  final bool messageRequestAccepted;

  final bool blockedEitherDirection;
  final bool requesterRiskBlocked;
  final bool rateLimited;

  const AvoraDirectContactContext({
    this.friends = false,
    this.mutualFollow = false,
    this.messageRequestAccepted = false,
    this.blockedEitherDirection = false,
    this.requesterRiskBlocked = false,
    this.rateLimited = false,
  });
}

class AvoraDirectContactDecision {
  final bool directChatAllowed;

  /// True means user can send a Message Request,
  /// but does not yet have unrestricted direct chat.
  final bool canSendMessageRequest;

  final bool friendshipRequired;
  final bool followBackRequired;

  final AvoraDirectContactReason reason;

  const AvoraDirectContactDecision({
    required this.directChatAllowed,
    required this.canSendMessageRequest,
    required this.friendshipRequired,
    required this.followBackRequired,
    required this.reason,
  });
}

class AvoraOfficialContactPolicy {
  const AvoraOfficialContactPolicy._();

  static AvoraDirectContactDecision evaluate({
    required AvoraDirectContactContext context,
    AvoraOfficialContactProfile? official,
  }) {
    if (context.blockedEitherDirection) {
      return const AvoraDirectContactDecision(
        directChatAllowed: false,
        canSendMessageRequest: false,
        friendshipRequired: false,
        followBackRequired: false,
        reason: AvoraDirectContactReason.blocked,
      );
    }

    if (context.requesterRiskBlocked) {
      return const AvoraDirectContactDecision(
        directChatAllowed: false,
        canSendMessageRequest: false,
        friendshipRequired: false,
        followBackRequired: false,
        reason: AvoraDirectContactReason.requesterRiskBlocked,
      );
    }

    if (context.rateLimited) {
      return const AvoraDirectContactDecision(
        directChatAllowed: false,
        canSendMessageRequest: false,
        friendshipRequired: false,
        followBackRequired: false,
        reason: AvoraDirectContactReason.rateLimited,
      );
    }

    if (official != null) {
      if (!official.approved ||
          !official.listedForSupport ||
          !official.directContactEnabled) {
        return const AvoraDirectContactDecision(
          directChatAllowed: false,
          canSendMessageRequest: false,
          friendshipRequired: false,
          followBackRequired: false,
          reason: AvoraDirectContactReason.officialUnavailable,
        );
      }

      return const AvoraDirectContactDecision(
        directChatAllowed: true,
        canSendMessageRequest: false,
        friendshipRequired: false,
        followBackRequired: false,
        reason: AvoraDirectContactReason.allowedOfficialSupport,
      );
    }

    if (context.friends ||
        context.mutualFollow ||
        context.messageRequestAccepted) {
      return const AvoraDirectContactDecision(
        directChatAllowed: true,
        canSendMessageRequest: false,
        friendshipRequired: false,
        followBackRequired: false,
        reason: AvoraDirectContactReason.allowedSocialRelationship,
      );
    }

    return const AvoraDirectContactDecision(
      directChatAllowed: false,
      canSendMessageRequest: true,
      friendshipRequired: true,
      followBackRequired: true,
      reason: AvoraDirectContactReason.requiresMessageRequest,
    );
  }

  static bool suitableForUser({
    required AvoraOfficialContactProfile official,
    required String countryCode,
    required String languageCode,
  }) {
    if (!official.approved ||
        !official.listedForSupport ||
        !official.directContactEnabled) {
      return false;
    }

    return official.supportsCountry(countryCode) &&
        official.supportsLanguage(languageCode);
  }
}
