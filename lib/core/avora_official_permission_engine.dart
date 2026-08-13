enum AvoraOfficialPermission {
  viewUsers,
  editUsers,
  viewRooms,
  enterRooms,
  manageRooms,
  roomBan,
  roomUnban,
  userBan,
  userUnban,
  viewAgencies,
  manageAgencies,
  viewBd,
  manageBd,
  viewHosts,
  manageHosts,
  viewWalletSummary,
  viewTargets,
  manageTargets,
  viewRewards,
  manageRewards,
  viewReports,
  resolveReports,
  viewAudit,
  managePolicies,
  assignRoles,
  revokeRoles,
  manageCountry,
  custom,
}

class AvoraOfficialPermissionGrant {
  const AvoraOfficialPermissionGrant({
    required this.grantId,
    required this.officialAvoraId,
    required this.permission,
    required this.countryCodes,
    required this.active,
    required this.grantedByAvoraId,
    required this.reason,
    required this.createdAtUtc,
    this.expiresAtUtc,
  });

  final String grantId;
  final String officialAvoraId;
  final AvoraOfficialPermission permission;

  /// Empty means no country granted.
  /// Use {'*'} only for explicit global official permission.
  final Set<String> countryCodes;

  final bool active;
  final String grantedByAvoraId;
  final String reason;
  final DateTime createdAtUtc;
  final DateTime? expiresAtUtc;

  bool isActiveAt(DateTime nowUtc) {
    if (!active) return false;

    final expiry = expiresAtUtc;

    if (expiry != null && !nowUtc.toUtc().isBefore(expiry.toUtc())) {
      return false;
    }

    return true;
  }

  bool coversCountry(String countryCode) {
    final code = countryCode.trim().toUpperCase();

    return countryCodes.contains('*') || countryCodes.contains(code);
  }
}

class AvoraOfficialPermissionEngine {
  final Map<String, AvoraOfficialPermissionGrant> _grants =
      <String, AvoraOfficialPermissionGrant>{};

  void grant(AvoraOfficialPermissionGrant grant) {
    if (grant.grantId.trim().isEmpty ||
        grant.officialAvoraId.trim().isEmpty ||
        grant.grantedByAvoraId.trim().isEmpty ||
        grant.reason.trim().isEmpty ||
        grant.countryCodes.isEmpty) {
      throw ArgumentError('invalid_official_permission_grant');
    }

    if (_grants.containsKey(grant.grantId)) {
      throw StateError('duplicate_permission_grant');
    }

    _grants[grant.grantId] = grant;
  }

  bool isAllowed({
    required String officialAvoraId,
    required AvoraOfficialPermission permission,
    required String countryCode,
    required DateTime nowUtc,
  }) {
    return _grants.values.any(
      (grant) =>
          grant.officialAvoraId == officialAvoraId &&
          grant.permission == permission &&
          grant.isActiveAt(nowUtc) &&
          grant.coversCountry(countryCode),
    );
  }

  List<AvoraOfficialPermissionGrant> grantsFor(
    String officialAvoraId,
  ) {
    return List<AvoraOfficialPermissionGrant>.unmodifiable(
      _grants.values.where(
        (grant) => grant.officialAvoraId == officialAvoraId,
      ),
    );
  }

  static bool permissionsMustBeGranular() => true;
  static bool ownerMustBeAbleToGrantOnePermissionAtATime() => true;
  static bool ownerMustBeAbleToReduceOrRevokeAuthority() => true;
  static bool countryScopeMustBeExplicit() => true;
  static bool permissionChangesMustBeAudited() => true;
  static bool futureOfficialRolesMustUseSameEngine() => true;
}

class AvoraOwnerGlobalOverridePolicy {
  const AvoraOwnerGlobalOverridePolicy._();

  static bool canAccessCountry({
    required bool activeVerifiedOwner,
    required String countryCode,
  }) =>
      activeVerifiedOwner && countryCode.trim().isNotEmpty;

  static bool canEnterNormallyBannedRoom({
    required bool activeVerifiedOwner,
  }) =>
      activeVerifiedOwner;

  static bool canBypassNormalRoomLock({
    required bool activeVerifiedOwner,
  }) =>
      activeVerifiedOwner;

  static bool canOperateAcrossAllOfficialScopes({
    required bool activeVerifiedOwner,
  }) =>
      activeVerifiedOwner;

  static bool countryPartitionMustNeverLimitOwner() => true;
  static bool ownerOverrideMustRemainAudited() => true;
  static bool ownerMustRemainIdentifiedAsOwner() => true;
  static bool ownerMustNotNeedLowerRolePermissionGrant() => true;
}
