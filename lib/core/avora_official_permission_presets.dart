import 'avora_official_permission_engine.dart';

enum AvoraOfficialPresetRole {
  manager,
  superAdmin,
  admin,
  bd,
  agency,
  support,
}

class AvoraOfficialPermissionPreset {
  const AvoraOfficialPermissionPreset._();

  static Set<AvoraOfficialPermission> permissionsFor(
    AvoraOfficialPresetRole role,
  ) {
    switch (role) {
      case AvoraOfficialPresetRole.manager:
        return {
          AvoraOfficialPermission.viewUsers,
          AvoraOfficialPermission.viewRooms,
          AvoraOfficialPermission.enterRooms,
          AvoraOfficialPermission.manageRooms,
          AvoraOfficialPermission.viewAgencies,
          AvoraOfficialPermission.manageAgencies,
          AvoraOfficialPermission.viewBd,
          AvoraOfficialPermission.manageBd,
          AvoraOfficialPermission.viewHosts,
          AvoraOfficialPermission.manageHosts,
          AvoraOfficialPermission.viewTargets,
          AvoraOfficialPermission.manageTargets,
          AvoraOfficialPermission.viewReports,
          AvoraOfficialPermission.resolveReports,
          AvoraOfficialPermission.viewAudit,
        };

      case AvoraOfficialPresetRole.superAdmin:
        return {
          AvoraOfficialPermission.viewUsers,
          AvoraOfficialPermission.editUsers,
          AvoraOfficialPermission.viewRooms,
          AvoraOfficialPermission.enterRooms,
          AvoraOfficialPermission.manageRooms,
          AvoraOfficialPermission.roomBan,
          AvoraOfficialPermission.roomUnban,
          AvoraOfficialPermission.userBan,
          AvoraOfficialPermission.userUnban,
          AvoraOfficialPermission.viewReports,
          AvoraOfficialPermission.resolveReports,
          AvoraOfficialPermission.viewAudit,
        };

      case AvoraOfficialPresetRole.admin:
        return {
          AvoraOfficialPermission.viewUsers,
          AvoraOfficialPermission.viewRooms,
          AvoraOfficialPermission.enterRooms,
          AvoraOfficialPermission.manageRooms,
          AvoraOfficialPermission.viewReports,
          AvoraOfficialPermission.resolveReports,
        };

      case AvoraOfficialPresetRole.bd:
        return {
          AvoraOfficialPermission.viewAgencies,
          AvoraOfficialPermission.manageAgencies,
          AvoraOfficialPermission.viewHosts,
          AvoraOfficialPermission.viewTargets,
        };

      case AvoraOfficialPresetRole.agency:
        return {
          AvoraOfficialPermission.viewHosts,
          AvoraOfficialPermission.manageHosts,
          AvoraOfficialPermission.viewTargets,
        };

      case AvoraOfficialPresetRole.support:
        return {
          AvoraOfficialPermission.viewUsers,
          AvoraOfficialPermission.viewReports,
          AvoraOfficialPermission.resolveReports,
        };
    }
  }

  static Set<AvoraOfficialPermission> effectivePermissions({
    required AvoraOfficialPresetRole role,
    Set<AvoraOfficialPermission> additions = const {},
    Set<AvoraOfficialPermission> removals = const {},
  }) {
    final result = <AvoraOfficialPermission>{
      ...permissionsFor(role),
      ...additions,
    };

    result.removeAll(removals);

    return Set<AvoraOfficialPermission>.unmodifiable(result);
  }

  static bool presetsAreStartingDefaultsOnly() => true;
  static bool ownerCanAddIndividualPermission() => true;
  static bool ownerCanRemoveIndividualPermission() => true;
  static bool manualOverrideMustWinOverPreset() => true;
  static bool presetMustNeverGrantOwnerAuthority() => true;
  static bool countryScopeStillRequiredSeparately() => true;
  static bool futureRolesCanReceiveNewPresetWithoutEngineRewrite() => true;
}
