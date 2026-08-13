enum AvoraProtectedOwnerAction {
  accountBan,
  roomBan,
  roomKick,
  roomRemove,
  roomMute,
  block,
  countryBan,
  demote,
  revokeOwnerAccess,
  removeFromScope,
  disableOwnerId,
}

class AvoraOwnerProtectionDecision {
  const AvoraOwnerProtectionDecision({
    required this.allowed,
    required this.reason,
    required this.auditRequired,
  });

  final bool allowed;
  final String reason;
  final bool auditRequired;
}

class AvoraOwnerAbsoluteProtectionGuard {
  const AvoraOwnerAbsoluteProtectionGuard._();

  static AvoraOwnerProtectionDecision evaluate({
    required bool targetIsVerifiedOwner,
    required bool actorIsSameVerifiedOwner,
    required AvoraProtectedOwnerAction action,
  }) {
    if (!targetIsVerifiedOwner) {
      return const AvoraOwnerProtectionDecision(
        allowed: true,
        reason: 'normal_target_policy_applies',
        auditRequired: false,
      );
    }

    // Owner may perform explicitly controlled self-actions only.
    if (actorIsSameVerifiedOwner) {
      return const AvoraOwnerProtectionDecision(
        allowed: true,
        reason: 'owner_self_control_allowed',
        auditRequired: true,
      );
    }

    return const AvoraOwnerProtectionDecision(
      allowed: false,
      reason: 'owner_target_is_protected',
      auditRequired: true,
    );
  }

  static bool lowerRolesMustNeverBanOwner() => true;

  static bool lowerRolesMustNeverKickOwner() => true;

  static bool lowerRolesMustNeverRemoveOwner() => true;

  static bool lowerRolesMustNeverMuteOwner() => true;

  static bool lowerRolesMustNeverBlockOwner() => true;

  static bool lowerRolesMustNeverDemoteOwner() => true;

  static bool countryAuthorityMustNeverOverrideOwner() => true;

  static bool roomAuthorityMustNeverOverrideOwner() => true;

  static bool ownerProtectionMustApplyAcrossAllCountries() => true;

  static bool ownerProtectionMustApplyAcrossAllRooms() => true;

  static bool failedOwnerAttackMustBeAudited() => true;

  static bool futureEnforcementActionsMustInheritProtection() => true;
}
