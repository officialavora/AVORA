import 'avora_owner_absolute_protection.dart';

enum AvoraProtectedEnforcementAction {
  accountBan,
  roomBan,
  roomKick,
  roomRemove,
  roomMute,
  userBlock,
  countryBan,
  demote,
  removeFromScope,
}

class AvoraProtectedEnforcementRequest {
  const AvoraProtectedEnforcementRequest({
    required this.actorAvoraId,
    required this.targetAvoraId,
    required this.action,
    required this.targetIsVerifiedOwner,
    required this.actorIsSameVerifiedOwner,
    required this.reason,
    required this.createdAtUtc,
  });

  final String actorAvoraId;
  final String targetAvoraId;
  final AvoraProtectedEnforcementAction action;

  final bool targetIsVerifiedOwner;
  final bool actorIsSameVerifiedOwner;

  final String reason;
  final DateTime createdAtUtc;
}

class AvoraProtectedEnforcementResult {
  const AvoraProtectedEnforcementResult({
    required this.allowed,
    required this.reason,
    required this.auditRequired,
  });

  final bool allowed;
  final String reason;
  final bool auditRequired;
}

class AvoraOwnerProtectedEnforcementService {
  const AvoraOwnerProtectedEnforcementService();

  AvoraProtectedEnforcementResult authorize(
    AvoraProtectedEnforcementRequest request,
  ) {
    if (request.actorAvoraId.trim().isEmpty ||
        request.targetAvoraId.trim().isEmpty ||
        request.reason.trim().isEmpty) {
      return const AvoraProtectedEnforcementResult(
        allowed: false,
        reason: 'invalid_enforcement_request',
        auditRequired: true,
      );
    }

    final protection = AvoraOwnerAbsoluteProtectionGuard.evaluate(
      targetIsVerifiedOwner: request.targetIsVerifiedOwner,
      actorIsSameVerifiedOwner: request.actorIsSameVerifiedOwner,
      action: _mapAction(request.action),
    );

    if (!protection.allowed) {
      return AvoraProtectedEnforcementResult(
        allowed: false,
        reason: protection.reason,
        auditRequired: true,
      );
    }

    return AvoraProtectedEnforcementResult(
      allowed: true,
      reason: request.targetIsVerifiedOwner
          ? 'owner_self_control_authorized'
          : 'normal_enforcement_authorized',
      auditRequired: protection.auditRequired || request.targetIsVerifiedOwner,
    );
  }

  AvoraProtectedOwnerAction _mapAction(
    AvoraProtectedEnforcementAction action,
  ) {
    switch (action) {
      case AvoraProtectedEnforcementAction.accountBan:
        return AvoraProtectedOwnerAction.accountBan;

      case AvoraProtectedEnforcementAction.roomBan:
        return AvoraProtectedOwnerAction.roomBan;

      case AvoraProtectedEnforcementAction.roomKick:
        return AvoraProtectedOwnerAction.roomKick;

      case AvoraProtectedEnforcementAction.roomRemove:
        return AvoraProtectedOwnerAction.roomRemove;

      case AvoraProtectedEnforcementAction.roomMute:
        return AvoraProtectedOwnerAction.roomMute;

      case AvoraProtectedEnforcementAction.userBlock:
        return AvoraProtectedOwnerAction.block;

      case AvoraProtectedEnforcementAction.countryBan:
        return AvoraProtectedOwnerAction.countryBan;

      case AvoraProtectedEnforcementAction.demote:
        return AvoraProtectedOwnerAction.demote;

      case AvoraProtectedEnforcementAction.removeFromScope:
        return AvoraProtectedOwnerAction.removeFromScope;
    }
  }

  static bool everyEnforcementMustCheckOwnerProtection() => true;

  static bool ownerProtectionMustRunBeforePermissionCheck() => true;

  static bool lowerRolePermissionMustNeverOverrideProtection() => true;

  static bool blockedOwnerAttackMustRemainAuditable() => true;

  static bool futureEnforcementTypesMustIntegrateProtection() => true;
}
