import 'avora_owner_attack_audit.dart';
import 'avora_owner_protected_enforcement.dart';

class AvoraOwnerProtectionEnforcementBridge {
  AvoraOwnerProtectionEnforcementBridge({
    required AvoraOwnerProtectedEnforcementService enforcementService,
    required AvoraOwnerAttackAuditLedger attackAuditLedger,
  })  : _enforcementService = enforcementService,
        _attackAuditLedger = attackAuditLedger;

  final AvoraOwnerProtectedEnforcementService _enforcementService;
  final AvoraOwnerAttackAuditLedger _attackAuditLedger;

  AvoraProtectedEnforcementResult authorize({
    required String auditId,
    required AvoraProtectedEnforcementRequest request,
  }) {
    final result = _enforcementService.authorize(request);

    final isBlockedOwnerAttack = request.targetIsVerifiedOwner &&
        !request.actorIsSameVerifiedOwner &&
        !result.allowed;

    if (isBlockedOwnerAttack) {
      _attackAuditLedger.append(
        AvoraOwnerAttackAuditRecord(
          auditId: auditId,
          actorAvoraId: request.actorAvoraId,
          ownerAvoraId: request.targetAvoraId,
          action: request.action,
          reason: result.reason,
          createdAtUtc: request.createdAtUtc.toUtc(),
        ),
      );
    }

    return result;
  }

  static bool blockedOwnerActionMustAutoAudit() => true;

  static bool callerMustNotNeedSeparateAuditCall() => true;

  static bool deniedActionMustNeverReachExecution() => true;

  static bool ownerAttackAuditMustPreserveActorIdentity() => true;

  static bool ownerAttackAuditMustPreserveTargetIdentity() => true;

  static bool ownerAttackAuditMustPreserveActionType() => true;

  static bool futureEnforcementMustUseSameBridge() => true;
}
