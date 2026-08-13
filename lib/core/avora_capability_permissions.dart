import 'avora_roles.dart';

enum AvoraCapabilityAction {
  assign,
  edit,
  suspend,
  remove,
}

enum AvoraCapabilityPermissionReason {
  allowed,
  noActiveAuthority,
  notAuthorized,
  outOfScope,
}

class AvoraCapabilityPermissionDecision {
  final bool allowed;
  final AvoraCapabilityPermissionReason reason;

  const AvoraCapabilityPermissionDecision._(
    this.allowed,
    this.reason,
  );

  const AvoraCapabilityPermissionDecision.allow()
      : this._(
          true,
          AvoraCapabilityPermissionReason.allowed,
        );

  const AvoraCapabilityPermissionDecision.deny(
    AvoraCapabilityPermissionReason reason,
  ) : this._(false, reason);
}

/// AVORA Capability Matrix V1
///
/// Core role remains authoritative.
/// Capabilities are additional scoped assignments.
///
/// Owner:
///   All capabilities.
///
/// Manager:
///   All capabilities within scope.
///
/// Super Admin:
///   Merchant, Seller, CS Head, CS Agent, Event Organizer.
///
/// Admin:
///   Seller, CS Agent, Event Organizer.
///
/// BD:
///   Seller, Event Organizer.
///
/// Agency/User:
///   Cannot grant capabilities.
///
/// CS Head:
///   Can manage CS Agent within its own scope.
///
/// Country Manager:
///   Assignment only in this layer.
///   Actual country-management powers will be defined separately.
class AvoraCapabilityPermissionEngine {
  const AvoraCapabilityPermissionEngine._();

  static AvoraCapabilityPermissionDecision check({
    required AvoraAccessProfile actor,
    required AvoraCapability targetCapability,
    required AvoraScope targetScope,
    required AvoraCapabilityAction action,
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();

    var hasActiveAuthority = false;
    var hasMatchingAuthority = false;

    for (final assignment in actor.roles) {
      if (!assignment.isActiveAt(now)) {
        continue;
      }

      hasActiveAuthority = true;

      if (!_roleCanManage(
        assignment.role,
        targetCapability,
        action,
      )) {
        continue;
      }

      hasMatchingAuthority = true;

      if (!assignment.scope.covers(targetScope)) {
        continue;
      }

      return const AvoraCapabilityPermissionDecision.allow();
    }

    for (final assignment in actor.capabilities) {
      if (!assignment.isActiveAt(now)) {
        continue;
      }

      hasActiveAuthority = true;

      if (!_capabilityCanManage(
        assignment.capability,
        targetCapability,
        action,
      )) {
        continue;
      }

      hasMatchingAuthority = true;

      if (!assignment.scope.covers(targetScope)) {
        continue;
      }

      return const AvoraCapabilityPermissionDecision.allow();
    }

    if (!hasActiveAuthority) {
      return const AvoraCapabilityPermissionDecision.deny(
        AvoraCapabilityPermissionReason.noActiveAuthority,
      );
    }

    if (!hasMatchingAuthority) {
      return const AvoraCapabilityPermissionDecision.deny(
        AvoraCapabilityPermissionReason.notAuthorized,
      );
    }

    return const AvoraCapabilityPermissionDecision.deny(
      AvoraCapabilityPermissionReason.outOfScope,
    );
  }

  static bool canManage({
    required AvoraAccessProfile actor,
    required AvoraCapability targetCapability,
    required AvoraScope targetScope,
    required AvoraCapabilityAction action,
    DateTime? at,
  }) {
    return check(
      actor: actor,
      targetCapability: targetCapability,
      targetScope: targetScope,
      action: action,
      at: at,
    ).allowed;
  }

  static bool _roleCanManage(
    AvoraRole role,
    AvoraCapability capability,
    AvoraCapabilityAction action,
  ) {
    switch (action) {
      case AvoraCapabilityAction.assign:
      case AvoraCapabilityAction.edit:
      case AvoraCapabilityAction.suspend:
      case AvoraCapabilityAction.remove:
        break;
    }

    switch (role) {
      case AvoraRole.owner:
      case AvoraRole.manager:
        return true;

      case AvoraRole.superAdmin:
        return capability != AvoraCapability.countryManager;

      case AvoraRole.admin:
        return capability == AvoraCapability.seller ||
            capability == AvoraCapability.csAgent ||
            capability == AvoraCapability.eventOrganizer;

      case AvoraRole.bd:
        return capability == AvoraCapability.seller ||
            capability == AvoraCapability.eventOrganizer;

      case AvoraRole.agency:
      case AvoraRole.user:
        return false;
    }
  }

  static bool _capabilityCanManage(
    AvoraCapability actorCapability,
    AvoraCapability targetCapability,
    AvoraCapabilityAction action,
  ) {
    switch (action) {
      case AvoraCapabilityAction.assign:
      case AvoraCapabilityAction.edit:
      case AvoraCapabilityAction.suspend:
      case AvoraCapabilityAction.remove:
        break;
    }

    if (actorCapability == AvoraCapability.csHead) {
      return targetCapability == AvoraCapability.csAgent;
    }

    return false;
  }
}
