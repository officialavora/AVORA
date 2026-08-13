import 'avora_roles.dart';

enum AvoraPermissionKey {
  viewUsers,
  moderateUsers,
  banUsers,
  manageRooms,
  manageAgencies,
  manageSellerInventory,
  manageRechargeOperations,
  manageCsTickets,
  manageEvents,
  manageCountryOperations,
  viewAuditLogs,
  manageSystemSettings,
}

enum AvoraFunctionalPermissionReason {
  allowed,
  noActiveAuthority,
  permissionNotGranted,
  outOfScope,
}

class AvoraFunctionalPermissionDecision {
  final bool allowed;
  final AvoraFunctionalPermissionReason reason;

  const AvoraFunctionalPermissionDecision._(
    this.allowed,
    this.reason,
  );

  const AvoraFunctionalPermissionDecision.allow()
      : this._(
          true,
          AvoraFunctionalPermissionReason.allowed,
        );

  const AvoraFunctionalPermissionDecision.deny(
    AvoraFunctionalPermissionReason reason,
  ) : this._(false, reason);
}

class AvoraFunctionalPermissionEngine {
  const AvoraFunctionalPermissionEngine._();

  static AvoraFunctionalPermissionDecision check({
    required AvoraAccessProfile actor,
    required AvoraPermissionKey permission,
    required AvoraScope targetScope,
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();

    var hasActiveAuthority = false;
    var hasPermission = false;

    for (final assignment in actor.roles) {
      if (!assignment.isActiveAt(now)) {
        continue;
      }

      hasActiveAuthority = true;

      if (!_roleHasPermission(assignment.role, permission)) {
        continue;
      }

      hasPermission = true;

      if (!assignment.scope.covers(targetScope)) {
        continue;
      }

      return const AvoraFunctionalPermissionDecision.allow();
    }

    for (final assignment in actor.capabilities) {
      if (!assignment.isActiveAt(now)) {
        continue;
      }

      hasActiveAuthority = true;

      if (!_capabilityHasPermission(
        assignment.capability,
        permission,
      )) {
        continue;
      }

      hasPermission = true;

      if (!assignment.scope.covers(targetScope)) {
        continue;
      }

      return const AvoraFunctionalPermissionDecision.allow();
    }

    if (!hasActiveAuthority) {
      return const AvoraFunctionalPermissionDecision.deny(
        AvoraFunctionalPermissionReason.noActiveAuthority,
      );
    }

    if (!hasPermission) {
      return const AvoraFunctionalPermissionDecision.deny(
        AvoraFunctionalPermissionReason.permissionNotGranted,
      );
    }

    return const AvoraFunctionalPermissionDecision.deny(
      AvoraFunctionalPermissionReason.outOfScope,
    );
  }

  static bool can({
    required AvoraAccessProfile actor,
    required AvoraPermissionKey permission,
    required AvoraScope targetScope,
    DateTime? at,
  }) {
    return check(
      actor: actor,
      permission: permission,
      targetScope: targetScope,
      at: at,
    ).allowed;
  }

  static bool _roleHasPermission(
    AvoraRole role,
    AvoraPermissionKey permission,
  ) {
    switch (role) {
      case AvoraRole.owner:
        return true;

      case AvoraRole.manager:
        return permission != AvoraPermissionKey.manageSystemSettings;

      case AvoraRole.superAdmin:
        return permission == AvoraPermissionKey.viewUsers ||
            permission == AvoraPermissionKey.moderateUsers ||
            permission == AvoraPermissionKey.banUsers ||
            permission == AvoraPermissionKey.manageRooms ||
            permission == AvoraPermissionKey.manageAgencies ||
            permission == AvoraPermissionKey.manageCsTickets ||
            permission == AvoraPermissionKey.manageEvents ||
            permission == AvoraPermissionKey.viewAuditLogs;

      case AvoraRole.admin:
        return permission == AvoraPermissionKey.viewUsers ||
            permission == AvoraPermissionKey.moderateUsers ||
            permission == AvoraPermissionKey.banUsers ||
            permission == AvoraPermissionKey.manageRooms ||
            permission == AvoraPermissionKey.manageCsTickets ||
            permission == AvoraPermissionKey.manageEvents;

      case AvoraRole.bd:
        return permission == AvoraPermissionKey.viewUsers ||
            permission == AvoraPermissionKey.manageAgencies ||
            permission == AvoraPermissionKey.manageEvents;

      case AvoraRole.agency:
      case AvoraRole.user:
        return false;
    }
  }

  static bool _capabilityHasPermission(
    AvoraCapability capability,
    AvoraPermissionKey permission,
  ) {
    switch (capability) {
      case AvoraCapability.merchant:
      case AvoraCapability.seller:
        return permission == AvoraPermissionKey.manageSellerInventory;

      case AvoraCapability.countryManager:
        return permission == AvoraPermissionKey.viewUsers ||
            permission == AvoraPermissionKey.moderateUsers ||
            permission == AvoraPermissionKey.manageAgencies ||
            permission == AvoraPermissionKey.manageEvents ||
            permission == AvoraPermissionKey.manageCountryOperations ||
            permission == AvoraPermissionKey.viewAuditLogs;

      case AvoraCapability.csHead:
      case AvoraCapability.csAgent:
        return permission == AvoraPermissionKey.viewUsers ||
            permission == AvoraPermissionKey.manageCsTickets;

      case AvoraCapability.eventOrganizer:
        return permission == AvoraPermissionKey.manageEvents;
    }
  }
}
