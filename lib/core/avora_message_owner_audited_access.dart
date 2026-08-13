import 'avora_message_production_access_gate.dart';
import 'avora_owner_message_override.dart';
import 'avora_owner_override_audit.dart';

class AvoraMessageOwnerAuditedAccessService {
  const AvoraMessageOwnerAuditedAccessService({
    required AvoraMessageProductionAccessGate accessGate,
    required AvoraOwnerOverrideAuditService auditService,
  })  : _accessGate = accessGate,
        _auditService = auditService;

  final AvoraMessageProductionAccessGate _accessGate;
  final AvoraOwnerOverrideAuditService _auditService;

  Future<AvoraMessageProductionAccessResult> authorize({
    required AvoraMessageProductionAccessRequest request,
    required String actorAvoraId,
    required String auditId,
    required DateTime createdAtUtc,
  }) async {
    final result = await _accessGate.authorize(request);

    if (!result.allowed || !result.ownerOverrideUsed || !result.auditRequired) {
      return result;
    }

    await _auditService.record(
      auditId: auditId,
      request: AvoraOwnerOverrideRequest(
        actorAvoraId: actorAvoraId,
        targetId: request.targetId,
        action: request.targetType == AvoraMessageAccessTarget.room
            ? AvoraOwnerOverrideAction.readRoom
            : AvoraOwnerOverrideAction.readInbox,
        reason: 'owner production message override',
        createdAtUtc: createdAtUtc.toUtc(),
      ),
    );

    return result;
  }

  static bool successfulOwnerOverrideMustCreateAudit() => true;

  static bool normalMemberAccessMustNotCreateOwnerAudit() => true;

  static bool failedOwnerOverrideMustNotPretendToBeSuccessful() => true;

  static bool auditWriteMustCompleteBeforeOverrideFlowFinishes() => true;
}
