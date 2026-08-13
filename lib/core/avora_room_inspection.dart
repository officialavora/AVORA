enum AvoraRoomInspectionPurpose {
  reportReview,
  safetyCheck,
  abuseInvestigation,
  supportInvestigation,
  fraudReview,
  policyReview,
}

enum AvoraRoomInspectionDenyReason {
  none,
  roomInactive,
  staffNotAuthorized,
  scopeDenied,
  functionalPermissionMissing,
  policyDenied,
  purposeMissing,
}

enum AvoraRoomConnectionStatus {
  connected,
  reconnecting,
  disconnected,
}

enum AvoraRoomModerationAction {
  dropSeat,
  kickFromRoom,
  temporaryRoomBlock,
  permanentRoomBlock,
  roomMute,
  stopMedia,
  resetRoomPassword,
}

class AvoraRoomLockState {
  final bool locked;

  /// Only indicates whether a credential exists.
  /// Plaintext password is never exposed here.
  final bool passwordConfigured;

  /// Backend credential/hash reference only.
  final String? passwordCredentialReference;

  const AvoraRoomLockState({
    required this.locked,
    required this.passwordConfigured,
    this.passwordCredentialReference,
  });
}

class AvoraRoomOccupantSnapshot {
  /// Immutable authoritative AVORA ID.
  final String avoraId;

  /// Public vanity/display ID, if assigned.
  final String? publicUid;

  final String displayName;

  /// Null means audience / not currently seated.
  final int? seatNumber;

  final String roomRole;

  final bool identityVerified;

  final DateTime joinedRoomAt;
  final DateTime? seatedAt;

  final bool selfMicMuted;
  final bool moderationMicMuted;

  final bool mediaPlaying;

  final AvoraRoomConnectionStatus connectionStatus;

  /// Safe summary only. Raw security/risk signals stay internal.
  final int openReportCount;

  final bool currentlyRoomBlocked;

  const AvoraRoomOccupantSnapshot({
    required this.avoraId,
    required this.publicUid,
    required this.displayName,
    required this.seatNumber,
    required this.roomRole,
    required this.identityVerified,
    required this.joinedRoomAt,
    required this.seatedAt,
    required this.selfMicMuted,
    required this.moderationMicMuted,
    required this.mediaPlaying,
    required this.connectionStatus,
    required this.openReportCount,
    required this.currentlyRoomBlocked,
  });

  Duration roomPresenceAt(DateTime now) {
    if (now.isBefore(joinedRoomAt)) {
      return Duration.zero;
    }

    return now.difference(joinedRoomAt);
  }

  Duration seatedDurationAt(DateTime now) {
    final started = seatedAt;

    if (started == null || now.isBefore(started)) {
      return Duration.zero;
    }

    return now.difference(started);
  }
}

class AvoraRoomInspectionSnapshot {
  final String roomId;

  final String ownerAvoraId;

  final AvoraRoomLockState lockState;

  final List<AvoraRoomOccupantSnapshot> occupants;

  final DateTime generatedAt;

  const AvoraRoomInspectionSnapshot({
    required this.roomId,
    required this.ownerAvoraId,
    required this.lockState,
    required this.occupants,
    required this.generatedAt,
  });

  AvoraRoomOccupantSnapshot? occupantOnSeat(int seatNumber) {
    for (final occupant in occupants) {
      if (occupant.seatNumber == seatNumber) {
        return occupant;
      }
    }

    return null;
  }

  AvoraRoomOccupantSnapshot? occupantByAvoraId(
    String avoraId,
  ) {
    for (final occupant in occupants) {
      if (occupant.avoraId == avoraId) {
        return occupant;
      }
    }

    return null;
  }
}

class AvoraRoomInspectionContext {
  final String staffAvoraId;

  final String roomId;

  final bool roomActive;

  /// Role/scope authority resolved server-side.
  final bool staffAuthorized;

  /// Country/region/room scope resolved server-side.
  final bool scopeAllowed;

  /// Separate functional permission.
  final bool hasRoomInspectionPermission;

  final bool countryPolicyAllowsInspection;

  final AvoraRoomInspectionPurpose? purpose;

  final bool roomLocked;

  const AvoraRoomInspectionContext({
    required this.staffAvoraId,
    required this.roomId,
    required this.roomActive,
    required this.staffAuthorized,
    required this.scopeAllowed,
    required this.hasRoomInspectionPermission,
    required this.countryPolicyAllowsInspection,
    required this.purpose,
    required this.roomLocked,
  });
}

class AvoraRoomInspectionDecision {
  final bool allowed;

  final AvoraRoomInspectionDenyReason reason;

  /// Authorized staff can enter locked room without
  /// learning/revealing its plaintext password.
  final bool moderationOverrideJoin;

  final bool requiresAudit;

  const AvoraRoomInspectionDecision({
    required this.allowed,
    required this.reason,
    required this.moderationOverrideJoin,
    required this.requiresAudit,
  });
}

class AvoraRoomModerationCapability {
  final Set<AvoraRoomModerationAction> allowedActions;

  const AvoraRoomModerationCapability({
    required this.allowedActions,
  });

  bool allows(AvoraRoomModerationAction action) {
    return allowedActions.contains(action);
  }
}

class AvoraRoomModerationActionRequest {
  final String actionId;

  final String staffAvoraId;

  final String roomId;

  /// Always authoritative immutable target ID.
  final String targetAvoraId;

  final AvoraRoomModerationAction action;

  final String reasonCode;

  final String? reasonText;

  final DateTime requestedAt;

  const AvoraRoomModerationActionRequest({
    required this.actionId,
    required this.staffAvoraId,
    required this.roomId,
    required this.targetAvoraId,
    required this.action,
    required this.reasonCode,
    required this.reasonText,
    required this.requestedAt,
  });
}

class AvoraRoomInspectionAuditEvent {
  final String auditId;

  final String staffAvoraId;

  final String roomId;

  final AvoraRoomInspectionPurpose purpose;

  final bool usedModerationOverride;

  final DateTime occurredAt;

  const AvoraRoomInspectionAuditEvent({
    required this.auditId,
    required this.staffAvoraId,
    required this.roomId,
    required this.purpose,
    required this.usedModerationOverride,
    required this.occurredAt,
  });
}

class AvoraRoomInspectionPolicy {
  const AvoraRoomInspectionPolicy._();

  static AvoraRoomInspectionDecision evaluateInspection({
    required AvoraRoomInspectionContext context,
  }) {
    if (!context.roomActive) {
      return const AvoraRoomInspectionDecision(
        allowed: false,
        reason: AvoraRoomInspectionDenyReason.roomInactive,
        moderationOverrideJoin: false,
        requiresAudit: false,
      );
    }

    if (!context.staffAuthorized) {
      return const AvoraRoomInspectionDecision(
        allowed: false,
        reason: AvoraRoomInspectionDenyReason.staffNotAuthorized,
        moderationOverrideJoin: false,
        requiresAudit: false,
      );
    }

    if (!context.scopeAllowed) {
      return const AvoraRoomInspectionDecision(
        allowed: false,
        reason: AvoraRoomInspectionDenyReason.scopeDenied,
        moderationOverrideJoin: false,
        requiresAudit: false,
      );
    }

    if (!context.hasRoomInspectionPermission) {
      return const AvoraRoomInspectionDecision(
        allowed: false,
        reason: AvoraRoomInspectionDenyReason.functionalPermissionMissing,
        moderationOverrideJoin: false,
        requiresAudit: false,
      );
    }

    if (!context.countryPolicyAllowsInspection) {
      return const AvoraRoomInspectionDecision(
        allowed: false,
        reason: AvoraRoomInspectionDenyReason.policyDenied,
        moderationOverrideJoin: false,
        requiresAudit: false,
      );
    }

    if (context.purpose == null) {
      return const AvoraRoomInspectionDecision(
        allowed: false,
        reason: AvoraRoomInspectionDenyReason.purposeMissing,
        moderationOverrideJoin: false,
        requiresAudit: false,
      );
    }

    return AvoraRoomInspectionDecision(
      allowed: true,
      reason: AvoraRoomInspectionDenyReason.none,
      moderationOverrideJoin: context.roomLocked,
      requiresAudit: true,
    );
  }

  /// Platform moderation never needs the plaintext room password.
  static bool staffCanRevealPlaintextRoomPassword() {
    return false;
  }

  /// Authorized moderation can inspect a locked room without
  /// changing its password or making it public.
  static bool moderationOverrideCanEnterLockedRoom() {
    return true;
  }

  static bool moderationOverrideUnlocksRoomForNormalUsers() {
    return false;
  }

  static bool moderationOverrideChangesRoomPassword() {
    return false;
  }

  /// Ordinary room-owner power never grants platform-level
  /// security data access.
  static bool roomOwnerAutomaticallyGetsSensitiveSecurityData() {
    return false;
  }

  /// Room moderation always targets immutable AVORA ID.
  static bool moderationUsesVanityUidAsAuthority() {
    return false;
  }

  /// Inspection must always be attributable in audit history.
  static bool inspectionCanBeUnaudited() {
    return false;
  }
}
