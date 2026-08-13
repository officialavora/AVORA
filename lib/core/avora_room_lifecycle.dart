enum AvoraRoomOperationalStatus {
  active,
  pausedByAuthorizedStaff,
  suspendedBySafety,
  archived,
}

enum AvoraRoomVisibility {
  public,
  unlisted,
  private,
}

enum AvoraRoomJoinDenyReason {
  none,
  roomNotActive,
  roomPrivate,
  passwordRequired,
  userRoomBanned,
  capacityReached,
  userRestricted,
}

enum AvoraRoomAdminPermission {
  manageSeats,
  muteUsers,
  kickUsers,
  blockUsers,
  clearChat,
  manageMusic,
  manageTheme,
  manageRoomProfile,
  managePassword,
  manageAnnouncements,
  managePk,
  manageEvents,
}

class AvoraPersistentRoom {
  /// Immutable backend room identity.
  /// Never replaced by vanity/public room number.
  final String internalRoomId;

  /// Immutable authoritative AVORA ID of current owner.
  final String ownerAvoraId;

  /// Public-facing room number/alias.
  /// May intentionally mirror owner's visible AVORA/Vanity UID.
  final String publicRoomNumber;

  final AvoraRoomOperationalStatus status;
  final AvoraRoomVisibility visibility;

  final bool passwordProtected;

  /// Backend-enforced safe capacity.
  final int capacity;

  /// Zero participants never makes the room unavailable.
  final int currentParticipants;

  const AvoraPersistentRoom({
    required this.internalRoomId,
    required this.ownerAvoraId,
    required this.publicRoomNumber,
    required this.status,
    required this.visibility,
    required this.passwordProtected,
    required this.capacity,
    required this.currentParticipants,
  })  : assert(capacity > 0),
        assert(currentParticipants >= 0);

  bool get operational => status == AvoraRoomOperationalStatus.active;

  bool get hasCapacity => currentParticipants < capacity;
}

class AvoraRoomAdminGrant {
  final String id;

  final String internalRoomId;

  final String userAvoraId;

  final Set<AvoraRoomAdminPermission> permissions;

  final String grantedByAvoraId;

  final DateTime startsAt;
  final DateTime? endsAt;

  final bool revoked;

  const AvoraRoomAdminGrant({
    required this.id,
    required this.internalRoomId,
    required this.userAvoraId,
    required this.permissions,
    required this.grantedByAvoraId,
    required this.startsAt,
    this.endsAt,
    this.revoked = false,
  });

  bool isActiveAt(DateTime now) {
    if (revoked) {
      return false;
    }

    if (now.isBefore(startsAt)) {
      return false;
    }

    final end = endsAt;

    if (end != null && !now.isBefore(end)) {
      return false;
    }

    return true;
  }

  bool allows(
    AvoraRoomAdminPermission permission,
    DateTime now,
  ) {
    return isActiveAt(now) && permissions.contains(permission);
  }
}

class AvoraRoomJoinContext {
  final bool userRoomBanned;
  final bool userRestricted;

  final bool passwordSatisfied;

  const AvoraRoomJoinContext({
    this.userRoomBanned = false,
    this.userRestricted = false,
    this.passwordSatisfied = false,
  });
}

class AvoraRoomJoinDecision {
  final bool allowed;
  final AvoraRoomJoinDenyReason reason;

  const AvoraRoomJoinDecision({
    required this.allowed,
    required this.reason,
  });
}

class AvoraRoomPublicIdentity {
  final String internalRoomId;

  final String ownerImmutableAvoraId;

  /// What normal users search/see.
  final String publicRoomNumber;

  /// Optional owner vanity visible on profile.
  final String? ownerVanityUid;

  const AvoraRoomPublicIdentity({
    required this.internalRoomId,
    required this.ownerImmutableAvoraId,
    required this.publicRoomNumber,
    this.ownerVanityUid,
  });
}

class AvoraPersistentRoomPolicy {
  const AvoraPersistentRoomPolicy._();

  /// Personal room UI may mirror owner's vanity UID.
  /// If no vanity exists, immutable AVORA ID is used publicly.
  static String resolvePersonalRoomPublicNumber({
    required String ownerImmutableAvoraId,
    required String? ownerVanityUid,
    required bool mirrorOwnerVisibleUid,
  }) {
    if (mirrorOwnerVisibleUid) {
      final vanity = ownerVanityUid?.trim();

      if (vanity != null && vanity.isNotEmpty) {
        return vanity;
      }

      return ownerImmutableAvoraId;
    }

    return ownerImmutableAvoraId;
  }

  static AvoraRoomJoinDecision evaluateJoin({
    required AvoraPersistentRoom room,
    required AvoraRoomJoinContext context,
  }) {
    if (!room.operational) {
      return const AvoraRoomJoinDecision(
        allowed: false,
        reason: AvoraRoomJoinDenyReason.roomNotActive,
      );
    }

    if (context.userRestricted) {
      return const AvoraRoomJoinDecision(
        allowed: false,
        reason: AvoraRoomJoinDenyReason.userRestricted,
      );
    }

    if (context.userRoomBanned) {
      return const AvoraRoomJoinDecision(
        allowed: false,
        reason: AvoraRoomJoinDenyReason.userRoomBanned,
      );
    }

    if (room.visibility == AvoraRoomVisibility.private) {
      return const AvoraRoomJoinDecision(
        allowed: false,
        reason: AvoraRoomJoinDenyReason.roomPrivate,
      );
    }

    if (room.passwordProtected && !context.passwordSatisfied) {
      return const AvoraRoomJoinDecision(
        allowed: false,
        reason: AvoraRoomJoinDenyReason.passwordRequired,
      );
    }

    if (!room.hasCapacity) {
      return const AvoraRoomJoinDecision(
        allowed: false,
        reason: AvoraRoomJoinDenyReason.capacityReached,
      );
    }

    return const AvoraRoomJoinDecision(
      allowed: true,
      reason: AvoraRoomJoinDenyReason.none,
    );
  }

  /// Critical AVORA rule:
  /// owner presence never controls whether a room is open.
  static bool ownerMustBeOnlineForRoomToOperate() {
    return false;
  }

  /// Empty room remains a persistent server entity.
  static bool emptyRoomAutomaticallyCloses() {
    return false;
  }

  /// Discovery/ranking and availability are separate concerns.
  static bool ownerOfflineForcesDiscoveryRemoval() {
    return false;
  }

  /// Backend room identity never becomes the vanity UID.
  static bool vanityUidReplacesInternalRoomId() {
    return false;
  }

  /// Original AVORA ID remains authoritative for ownership.
  static bool originalAvoraIdRemainsAuthoritative() {
    return true;
  }
}
