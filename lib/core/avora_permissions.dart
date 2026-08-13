import 'avora_roles.dart';

/// Actions that one AVORA role may perform on another role assignment.
enum AvoraRoleAction {
  appoint,
  edit,
  suspend,
  remove,
}

/// Stable reason codes for permission checks.
///
/// These can later be written to AVORA audit logs without depending
/// on human-readable UI text.
enum AvoraPermissionReason {
  allowed,
  noActiveRole,
  insufficientHierarchy,
  outOfScope,
}

class AvoraPermissionDecision {
  final bool allowed;
  final AvoraPermissionReason reason;

  const AvoraPermissionDecision._({
    required this.allowed,
    required this.reason,
  });

  const AvoraPermissionDecision.allow()
      : this._(
          allowed: true,
          reason: AvoraPermissionReason.allowed,
        );

  const AvoraPermissionDecision.deny(
    AvoraPermissionReason reason,
  ) : this._(
          allowed: false,
          reason: reason,
        );
}

/// AVORA Permission Engine v1.
///
/// Core authority:
/// Owner -> Manager -> Super Admin -> Admin -> BD -> Agency -> User
///
/// Security default:
/// - a role can manage only a lower-authority role;
/// - an assignment must be active;
/// - global scope can manage any scope;
/// - non-global scope can manage only the exact same scope for now.
///
/// Region -> Country -> Agency -> Room inheritance will be added later
/// when AVORA's scope registry exists.
class AvoraPermissionEngine {
  const AvoraPermissionEngine._();

  static AvoraPermissionDecision checkRoleAction({
    required AvoraAccessProfile actor,
    required AvoraRole targetRole,
    required AvoraScope targetScope,
    required AvoraRoleAction action,
    DateTime? at,
  }) {
    final checkTime = at ?? DateTime.now();

    var hasActiveRole = false;
    var hasEnoughAuthority = false;

    for (final assignment in actor.roles) {
      if (!assignment.isActiveAt(checkTime)) {
        continue;
      }

      hasActiveRole = true;

      if (!_canRolePerformAction(
        actorRole: assignment.role,
        targetRole: targetRole,
        action: action,
      )) {
        continue;
      }

      hasEnoughAuthority = true;

      if (!assignment.scope.covers(targetScope)) {
        continue;
      }

      return const AvoraPermissionDecision.allow();
    }

    if (!hasActiveRole) {
      return const AvoraPermissionDecision.deny(
        AvoraPermissionReason.noActiveRole,
      );
    }

    if (!hasEnoughAuthority) {
      return const AvoraPermissionDecision.deny(
        AvoraPermissionReason.insufficientHierarchy,
      );
    }

    return const AvoraPermissionDecision.deny(
      AvoraPermissionReason.outOfScope,
    );
  }

  static bool canManageRole({
    required AvoraAccessProfile actor,
    required AvoraRole targetRole,
    required AvoraScope targetScope,
    required AvoraRoleAction action,
    DateTime? at,
  }) {
    return checkRoleAction(
      actor: actor,
      targetRole: targetRole,
      targetScope: targetScope,
      action: action,
      at: at,
    ).allowed;
  }

  static bool _canRolePerformAction({
    required AvoraRole actorRole,
    required AvoraRole targetRole,
    required AvoraRoleAction action,
  }) {
    switch (action) {
      case AvoraRoleAction.appoint:
      case AvoraRoleAction.edit:
      case AvoraRoleAction.suspend:
      case AvoraRoleAction.remove:
        return actorRole.canManageRole(targetRole);
    }
  }
}
