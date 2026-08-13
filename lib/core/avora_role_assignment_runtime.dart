import 'avora_capability_permissions.dart';
import 'avora_permissions.dart';
import 'avora_role_assignment_audit.dart';
import 'avora_role_policy_delivery.dart';
import 'avora_role_policy_runtime_delivery.dart';
import 'avora_roles.dart';

class AvoraRoleMutationAuthorizationException implements Exception {
  const AvoraRoleMutationAuthorizationException({
    required this.operation,
  });

  final String operation;

  @override
  String toString() =>
      'AvoraRoleMutationAuthorizationException: unauthorized $operation';
}

class AvoraRoleAssignmentRuntimeResult {
  const AvoraRoleAssignmentRuntimeResult({
    required this.accessProfile,
    required this.policyAudience,
    required this.policyDelivery,
    required this.auditEvent,
  });

  final AvoraAccessProfile accessProfile;
  final AvoraRolePolicyAudience? policyAudience;
  final AvoraRolePolicyDeliveryInstruction? policyDelivery;
  final AvoraRoleMutationAuditEvent auditEvent;
}

class AvoraRoleAssignmentRuntimeRevocationResult {
  const AvoraRoleAssignmentRuntimeRevocationResult({
    required this.immutableAvoraId,
    required this.accessProfile,
    required this.policyAudience,
    required this.policyDelivery,
    required this.changed,
    required this.auditEvent,
  });

  final String immutableAvoraId;
  final AvoraAccessProfile accessProfile;
  final AvoraRolePolicyAudience? policyAudience;

  /// Revocation never masquerades as activation-policy delivery.
  final AvoraRolePolicyDeliveryInstruction? policyDelivery;

  final bool changed;
  final AvoraRoleMutationAuditEvent auditEvent;
}

/// Canonical runtime entrypoint for AVORA role/capability assignment changes.
///
/// Every mutation requires immutable actor + target AVORA IDs and creates an
/// immutable audit snapshot.
///
/// The supplied access profile is never mutated in place.
class AvoraRoleAssignmentRuntime {
  const AvoraRoleAssignmentRuntime._();

  static AvoraRoleAssignmentRuntimeResult activateRole({
    required String immutableAvoraId,
    required String actorAvoraId,
    required AvoraAccessProfile actorProfile,
    required String reasonCode,
    String reasonText = '',
    required AvoraAccessProfile currentProfile,
    required AvoraRoleAssignment assignment,
    required String policyCountryCode,
    required String policyScopeKey,
    required List<AvoraRolePolicyDocument> policies,
    required DateTime nowUtc,
  }) {
    _requireMutationIdentity(
      immutableAvoraId: immutableAvoraId,
      actorAvoraId: actorAvoraId,
      reasonCode: reasonCode,
    );

    _requireRoleAuthorization(
      actorProfile: actorProfile,
      targetRole: assignment.role,
      targetScope: assignment.scope,
      action: AvoraRoleAction.appoint,
      at: nowUtc,
    );

    final audience = policyAudienceForRole(assignment.role);

    final beforeActive = _hasActiveRoleInScope(
      currentProfile,
      assignment.role,
      assignment.scope,
      nowUtc,
    );

    final alreadyActive = assignment.isActiveAt(nowUtc) && beforeActive;

    if (alreadyActive) {
      final audit = _buildAudit(
        actorAvoraId: actorAvoraId,
        targetAvoraId: immutableAvoraId,
        action: AvoraRoleMutationAuditAction.roleActivated,
        subjectType: 'role',
        subjectKey: assignment.role.name,
        scope: assignment.scope,
        occurredAtUtc: nowUtc,
        reasonCode: reasonCode,
        reasonText: reasonText,
        beforeActive: true,
        afterActive: true,
        changed: false,
        policyAudience: audience,
      );

      return AvoraRoleAssignmentRuntimeResult(
        accessProfile: _copyProfile(currentProfile),
        policyAudience: audience,
        policyDelivery: null,
        auditEvent: audit,
      );
    }

    final updatedProfile = AvoraAccessProfile(
      roles: List<AvoraRoleAssignment>.unmodifiable([
        ...currentProfile.roles,
        assignment,
      ]),
      capabilities: List<AvoraCapabilityAssignment>.unmodifiable(
        currentProfile.capabilities,
      ),
    );

    AvoraRolePolicyDeliveryInstruction? delivery;

    if (audience != null) {
      final activePolicyAssignment = AvoraActivePolicyAssignment(
        audience: audience,
        active: assignment.isActiveAt(nowUtc),
        countryCode: policyCountryCode.trim(),
        scopeKey: policyScopeKey.trim(),
      );

      delivery = AvoraRolePolicyRuntimeDelivery.onRoleActivated(
        immutableAvoraId: immutableAvoraId,
        assignment: activePolicyAssignment,
        policies: policies,
        nowUtc: nowUtc,
      );
    }

    final afterActive = _hasActiveRoleInScope(
      updatedProfile,
      assignment.role,
      assignment.scope,
      nowUtc,
    );

    final audit = _buildAudit(
      actorAvoraId: actorAvoraId,
      targetAvoraId: immutableAvoraId,
      action: AvoraRoleMutationAuditAction.roleActivated,
      subjectType: 'role',
      subjectKey: assignment.role.name,
      scope: assignment.scope,
      occurredAtUtc: nowUtc,
      reasonCode: reasonCode,
      reasonText: reasonText,
      beforeActive: beforeActive,
      afterActive: afterActive,
      changed: true,
      policyAudience: audience,
    );

    return AvoraRoleAssignmentRuntimeResult(
      accessProfile: updatedProfile,
      policyAudience: audience,
      policyDelivery: delivery,
      auditEvent: audit,
    );
  }

  static AvoraRoleAssignmentRuntimeResult activateCapability({
    required String immutableAvoraId,
    required String actorAvoraId,
    required AvoraAccessProfile actorProfile,
    required String reasonCode,
    String reasonText = '',
    required AvoraAccessProfile currentProfile,
    required AvoraCapabilityAssignment assignment,
    required String policyCountryCode,
    required String policyScopeKey,
    required List<AvoraRolePolicyDocument> policies,
    required DateTime nowUtc,
  }) {
    _requireMutationIdentity(
      immutableAvoraId: immutableAvoraId,
      actorAvoraId: actorAvoraId,
      reasonCode: reasonCode,
    );

    _requireCapabilityAuthorization(
      actorProfile: actorProfile,
      targetCapability: assignment.capability,
      targetScope: assignment.scope,
      action: AvoraCapabilityAction.assign,
      at: nowUtc,
    );

    final audience = policyAudienceForCapability(
      assignment.capability,
    );

    final beforeActive = _hasActiveCapabilityInScope(
      currentProfile,
      assignment.capability,
      assignment.scope,
      nowUtc,
    );

    final alreadyActive = assignment.isActiveAt(nowUtc) && beforeActive;

    if (alreadyActive) {
      final audit = _buildAudit(
        actorAvoraId: actorAvoraId,
        targetAvoraId: immutableAvoraId,
        action: AvoraRoleMutationAuditAction.capabilityActivated,
        subjectType: 'capability',
        subjectKey: assignment.capability.name,
        scope: assignment.scope,
        occurredAtUtc: nowUtc,
        reasonCode: reasonCode,
        reasonText: reasonText,
        beforeActive: true,
        afterActive: true,
        changed: false,
        policyAudience: audience,
      );

      return AvoraRoleAssignmentRuntimeResult(
        accessProfile: _copyProfile(currentProfile),
        policyAudience: audience,
        policyDelivery: null,
        auditEvent: audit,
      );
    }

    final updatedProfile = AvoraAccessProfile(
      roles: List<AvoraRoleAssignment>.unmodifiable(
        currentProfile.roles,
      ),
      capabilities: List<AvoraCapabilityAssignment>.unmodifiable([
        ...currentProfile.capabilities,
        assignment,
      ]),
    );

    AvoraRolePolicyDeliveryInstruction? delivery;

    if (audience != null) {
      final activePolicyAssignment = AvoraActivePolicyAssignment(
        audience: audience,
        active: assignment.isActiveAt(nowUtc),
        countryCode: policyCountryCode.trim(),
        scopeKey: policyScopeKey.trim(),
      );

      delivery = AvoraRolePolicyRuntimeDelivery.onCapabilityActivated(
        immutableAvoraId: immutableAvoraId,
        assignment: activePolicyAssignment,
        policies: policies,
        nowUtc: nowUtc,
      );
    }

    final afterActive = _hasActiveCapabilityInScope(
      updatedProfile,
      assignment.capability,
      assignment.scope,
      nowUtc,
    );

    final audit = _buildAudit(
      actorAvoraId: actorAvoraId,
      targetAvoraId: immutableAvoraId,
      action: AvoraRoleMutationAuditAction.capabilityActivated,
      subjectType: 'capability',
      subjectKey: assignment.capability.name,
      scope: assignment.scope,
      occurredAtUtc: nowUtc,
      reasonCode: reasonCode,
      reasonText: reasonText,
      beforeActive: beforeActive,
      afterActive: afterActive,
      changed: true,
      policyAudience: audience,
    );

    return AvoraRoleAssignmentRuntimeResult(
      accessProfile: updatedProfile,
      policyAudience: audience,
      policyDelivery: delivery,
      auditEvent: audit,
    );
  }

  static AvoraRoleAssignmentRuntimeRevocationResult revokeRole({
    required String immutableAvoraId,
    required String actorAvoraId,
    required AvoraAccessProfile actorProfile,
    required String reasonCode,
    String reasonText = '',
    required AvoraAccessProfile currentProfile,
    required AvoraRole role,
    required AvoraScope scope,
    required DateTime nowUtc,
  }) {
    _requireMutationIdentity(
      immutableAvoraId: immutableAvoraId,
      actorAvoraId: actorAvoraId,
      reasonCode: reasonCode,
    );

    _requireRoleAuthorization(
      actorProfile: actorProfile,
      targetRole: role,
      targetScope: scope,
      action: AvoraRoleAction.remove,
      at: nowUtc,
    );

    final audience = policyAudienceForRole(role);

    final beforeActive = _hasActiveRoleInScope(
      currentProfile,
      role,
      scope,
      nowUtc,
    );

    var changed = false;

    final updatedRoles = currentProfile.roles.map((existing) {
      final matches =
          existing.role == role && _sameScope(existing.scope, scope);

      final stillGranted =
          existing.endsAt == null || nowUtc.isBefore(existing.endsAt!);

      if (!matches || !stillGranted) {
        return existing;
      }

      changed = true;

      return AvoraRoleAssignment(
        role: existing.role,
        scope: existing.scope,
        startsAt: existing.startsAt,
        endsAt: nowUtc,
      );
    }).toList(growable: false);

    final updatedProfile = AvoraAccessProfile(
      roles: List<AvoraRoleAssignment>.unmodifiable(updatedRoles),
      capabilities: List<AvoraCapabilityAssignment>.unmodifiable(
        currentProfile.capabilities,
      ),
    );

    final afterActive = _hasActiveRoleInScope(
      updatedProfile,
      role,
      scope,
      nowUtc,
    );

    final audit = _buildAudit(
      actorAvoraId: actorAvoraId,
      targetAvoraId: immutableAvoraId,
      action: AvoraRoleMutationAuditAction.roleRevoked,
      subjectType: 'role',
      subjectKey: role.name,
      scope: scope,
      occurredAtUtc: nowUtc,
      reasonCode: reasonCode,
      reasonText: reasonText,
      beforeActive: beforeActive,
      afterActive: afterActive,
      changed: changed,
      policyAudience: audience,
    );

    return AvoraRoleAssignmentRuntimeRevocationResult(
      immutableAvoraId: immutableAvoraId.trim(),
      accessProfile: updatedProfile,
      policyAudience: audience,
      policyDelivery: null,
      changed: changed,
      auditEvent: audit,
    );
  }

  static AvoraRoleAssignmentRuntimeRevocationResult revokeCapability({
    required String immutableAvoraId,
    required String actorAvoraId,
    required AvoraAccessProfile actorProfile,
    required String reasonCode,
    String reasonText = '',
    required AvoraAccessProfile currentProfile,
    required AvoraCapability capability,
    required AvoraScope scope,
    required DateTime nowUtc,
  }) {
    _requireMutationIdentity(
      immutableAvoraId: immutableAvoraId,
      actorAvoraId: actorAvoraId,
      reasonCode: reasonCode,
    );

    _requireCapabilityAuthorization(
      actorProfile: actorProfile,
      targetCapability: capability,
      targetScope: scope,
      action: AvoraCapabilityAction.remove,
      at: nowUtc,
    );

    final audience = policyAudienceForCapability(capability);

    final beforeActive = _hasActiveCapabilityInScope(
      currentProfile,
      capability,
      scope,
      nowUtc,
    );

    var changed = false;

    final updatedCapabilities = currentProfile.capabilities.map((existing) {
      final matches = existing.capability == capability &&
          _sameScope(existing.scope, scope);

      final stillGranted =
          existing.endsAt == null || nowUtc.isBefore(existing.endsAt!);

      if (!matches || !stillGranted) {
        return existing;
      }

      changed = true;

      return AvoraCapabilityAssignment(
        capability: existing.capability,
        scope: existing.scope,
        startsAt: existing.startsAt,
        endsAt: nowUtc,
      );
    }).toList(growable: false);

    final updatedProfile = AvoraAccessProfile(
      roles: List<AvoraRoleAssignment>.unmodifiable(
        currentProfile.roles,
      ),
      capabilities: List<AvoraCapabilityAssignment>.unmodifiable(
        updatedCapabilities,
      ),
    );

    final afterActive = _hasActiveCapabilityInScope(
      updatedProfile,
      capability,
      scope,
      nowUtc,
    );

    final audit = _buildAudit(
      actorAvoraId: actorAvoraId,
      targetAvoraId: immutableAvoraId,
      action: AvoraRoleMutationAuditAction.capabilityRevoked,
      subjectType: 'capability',
      subjectKey: capability.name,
      scope: scope,
      occurredAtUtc: nowUtc,
      reasonCode: reasonCode,
      reasonText: reasonText,
      beforeActive: beforeActive,
      afterActive: afterActive,
      changed: changed,
      policyAudience: audience,
    );

    return AvoraRoleAssignmentRuntimeRevocationResult(
      immutableAvoraId: immutableAvoraId.trim(),
      accessProfile: updatedProfile,
      policyAudience: audience,
      policyDelivery: null,
      changed: changed,
      auditEvent: audit,
    );
  }

  static AvoraRolePolicyAudience? policyAudienceForRole(
    AvoraRole role,
  ) {
    return switch (role.name) {
      'manager' => AvoraRolePolicyAudience.manager,
      'superAdmin' => AvoraRolePolicyAudience.superAdmin,
      'admin' => AvoraRolePolicyAudience.admin,
      'bd' => AvoraRolePolicyAudience.bd,
      'agency' => AvoraRolePolicyAudience.agency,
      'host' => AvoraRolePolicyAudience.host,
      _ => null,
    };
  }

  static AvoraRolePolicyAudience? policyAudienceForCapability(
    AvoraCapability capability,
  ) {
    return switch (capability.name) {
      'countryManager' => AvoraRolePolicyAudience.manager,
      'host' => AvoraRolePolicyAudience.host,
      _ => null,
    };
  }

  static void _requireRoleAuthorization({
    required AvoraAccessProfile actorProfile,
    required AvoraRole targetRole,
    required AvoraScope targetScope,
    required AvoraRoleAction action,
    required DateTime at,
  }) {
    final allowed = AvoraPermissionEngine.canManageRole(
      actor: actorProfile,
      targetRole: targetRole,
      targetScope: targetScope,
      action: action,
      at: at,
    );

    if (!allowed) {
      throw AvoraRoleMutationAuthorizationException(
        operation: 'role ${action.name}',
      );
    }
  }

  static void _requireCapabilityAuthorization({
    required AvoraAccessProfile actorProfile,
    required AvoraCapability targetCapability,
    required AvoraScope targetScope,
    required AvoraCapabilityAction action,
    required DateTime at,
  }) {
    final decision = AvoraCapabilityPermissionEngine.check(
      actor: actorProfile,
      targetCapability: targetCapability,
      targetScope: targetScope,
      action: action,
      at: at,
    );

    if (!decision.allowed) {
      throw AvoraRoleMutationAuthorizationException(
        operation: 'capability ${action.name}',
      );
    }
  }

  static AvoraRoleMutationAuditEvent _buildAudit({
    required String actorAvoraId,
    required String targetAvoraId,
    required AvoraRoleMutationAuditAction action,
    required String subjectType,
    required String subjectKey,
    required AvoraScope scope,
    required DateTime occurredAtUtc,
    required String reasonCode,
    required String reasonText,
    required bool beforeActive,
    required bool afterActive,
    required bool changed,
    required AvoraRolePolicyAudience? policyAudience,
  }) {
    return AvoraRoleMutationAuditEvent(
      actorAvoraId: actorAvoraId.trim(),
      targetAvoraId: targetAvoraId.trim(),
      action: action,
      subjectType: subjectType,
      subjectKey: subjectKey,
      scopeType: scope.type.name,
      scopeId: scope.id ?? '',
      occurredAtUtc: occurredAtUtc.toUtc(),
      reasonCode: reasonCode.trim(),
      reasonText: reasonText.trim(),
      beforeActive: beforeActive,
      afterActive: afterActive,
      changed: changed,
      policyAudienceKey: policyAudience?.name ?? '',
    );
  }

  static bool _hasActiveRoleInScope(
    AvoraAccessProfile profile,
    AvoraRole role,
    AvoraScope scope,
    DateTime at,
  ) {
    return profile.roles.any(
      (assignment) =>
          assignment.role == role &&
          _sameScope(assignment.scope, scope) &&
          assignment.isActiveAt(at),
    );
  }

  static bool _hasActiveCapabilityInScope(
    AvoraAccessProfile profile,
    AvoraCapability capability,
    AvoraScope scope,
    DateTime at,
  ) {
    return profile.capabilities.any(
      (assignment) =>
          assignment.capability == capability &&
          _sameScope(assignment.scope, scope) &&
          assignment.isActiveAt(at),
    );
  }

  static AvoraAccessProfile _copyProfile(
    AvoraAccessProfile profile,
  ) {
    return AvoraAccessProfile(
      roles: List<AvoraRoleAssignment>.unmodifiable(profile.roles),
      capabilities: List<AvoraCapabilityAssignment>.unmodifiable(
        profile.capabilities,
      ),
    );
  }

  static bool _sameScope(AvoraScope left, AvoraScope right) {
    return left.type == right.type && left.id == right.id;
  }

  static void _requireMutationIdentity({
    required String immutableAvoraId,
    required String actorAvoraId,
    required String reasonCode,
  }) {
    if (immutableAvoraId.trim().isEmpty) {
      throw ArgumentError.value(
        immutableAvoraId,
        'immutableAvoraId',
        'Immutable target AVORA ID is required.',
      );
    }

    if (actorAvoraId.trim().isEmpty) {
      throw ArgumentError.value(
        actorAvoraId,
        'actorAvoraId',
        'Immutable actor AVORA ID is required.',
      );
    }

    if (reasonCode.trim().isEmpty) {
      throw ArgumentError.value(
        reasonCode,
        'reasonCode',
        'A mutation audit reason code is required.',
      );
    }
  }
}
