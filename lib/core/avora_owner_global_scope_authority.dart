enum AvoraOperationalRoleScope {
  manager,
  superAdmin,
  admin,
  bd,
  agency,
  user,
  seller,
  host,
  support,
  eventOrganizer,
  custom,
}

class AvoraOwnerOperationalContext {
  const AvoraOwnerOperationalContext({
    required this.ownerAvoraId,
    required this.countryCode,
    required this.roleScope,
    required this.reason,
  });

  final String ownerAvoraId;
  final String countryCode;
  final AvoraOperationalRoleScope roleScope;
  final String reason;

  bool get isValid =>
      ownerAvoraId.trim().isNotEmpty &&
      countryCode.trim().isNotEmpty &&
      reason.trim().isNotEmpty;
}

class AvoraOwnerGlobalScopeAuthority {
  const AvoraOwnerGlobalScopeAuthority._();

  static bool canOperateInCountry({
    required bool activeVerifiedOwner,
    required String countryCode,
  }) {
    return activeVerifiedOwner && countryCode.trim().isNotEmpty;
  }

  static bool canOperateAsScope({
    required bool activeVerifiedOwner,
    required AvoraOperationalRoleScope roleScope,
  }) {
    return activeVerifiedOwner;
  }

  static bool ownerMayManageLowerRolesDirectly() => true;

  static bool ownerMayOperateAcrossAllCountries() => true;

  static bool ownerIdAndPanelMustUseSameAuthoritySource() => true;

  static bool ownerMustNotNeedLowerRoleAssignmentToAct() => true;

  static bool ownerActionsMustRemainIdentifiedAsOwner() => true;

  static bool ownerMustNotImpersonateAnotherUsersLogin() => true;

  static bool ownerScopedActionMustBeAudited() => true;

  static bool countryManagerScopeMustNotLimitGlobalOwner() => true;

  static bool futureRolesMustAutomaticallyRemainBelowOwnerAuthority() => true;
}
