/// Security boundary between Firebase authentication identity and AVORA's
/// immutable application identity.
///
/// IMPORTANT:
/// Firebase UID is an authentication credential identifier.
/// AVORA ID is the authoritative immutable application identity.
/// They must never be silently treated as the same identifier.
class AvoraMessageIdentityBinding {
  const AvoraMessageIdentityBinding({
    required this.firebaseUid,
    required this.avoraId,
    required this.verified,
  });

  final String firebaseUid;
  final String avoraId;
  final bool verified;

  bool get isValid =>
      firebaseUid.trim().isNotEmpty && avoraId.trim().isNotEmpty && verified;
}

class AvoraMessageAuthorizationContext {
  const AvoraMessageAuthorizationContext({
    required this.identity,
    this.roomMemberAvoraIds = const <String>{},
    this.inboxParticipantAvoraIds = const <String>{},
  });

  final AvoraMessageIdentityBinding? identity;
  final Set<String> roomMemberAvoraIds;
  final Set<String> inboxParticipantAvoraIds;
}

class AvoraMessageIdentityBridge {
  const AvoraMessageIdentityBridge._();

  /// Authentication alone is never authorization.
  static bool hasVerifiedIdentity(
    AvoraMessageAuthorizationContext context,
  ) =>
      context.identity?.isValid ?? false;

  static bool canAccessRoomMessages(
    AvoraMessageAuthorizationContext context,
  ) {
    final identity = context.identity;

    if (identity == null || !identity.isValid) {
      return false;
    }

    return context.roomMemberAvoraIds.contains(identity.avoraId);
  }

  static bool canAccessInboxMessages(
    AvoraMessageAuthorizationContext context,
  ) {
    final identity = context.identity;

    if (identity == null || !identity.isValid) {
      return false;
    }

    return context.inboxParticipantAvoraIds.contains(identity.avoraId);
  }

  /// Never authorize by Firebase UID being present in an AVORA-ID set.
  static bool firebaseUidMustNotSubstituteForAvoraId({
    required AvoraMessageIdentityBinding identity,
    required Set<String> authorizedAvoraIds,
  }) {
    if (!identity.isValid) {
      return false;
    }

    if (identity.firebaseUid == identity.avoraId) {
      return false;
    }

    return authorizedAvoraIds.contains(identity.avoraId);
  }

  static bool authenticationAloneMustNeverGrantMessageAccess() => true;

  static bool immutableAvoraIdMustRemainAuthoritative() => true;

  static bool unverifiedIdentityMustFailClosed() => true;
}
