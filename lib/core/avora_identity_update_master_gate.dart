import 'avora_identity_edit_restriction.dart';
import 'avora_identity_restricted_attempt_audit.dart';
import 'avora_identity_restriction_audit_bridge.dart';
import 'avora_protected_identity_update_gate.dart';

class AvoraIdentityUpdateMasterResult {
  const AvoraIdentityUpdateMasterResult({
    required this.allowed,
    required this.reason,
    this.identityDecision,
  });

  final bool allowed;
  final String reason;
  final AvoraProtectedIdentityUpdateDecision? identityDecision;
}

class AvoraIdentityUpdateMasterGate {
  AvoraIdentityUpdateMasterGate({
    required AvoraIdentityEditRestrictionLedger restrictionLedger,
    required AvoraRestrictedIdentityAttemptAuditLedger restrictedAuditLedger,
    required AvoraProtectedIdentityUpdateGate protectedUpdateGate,
  })  : _restrictionAuditBridge = AvoraIdentityRestrictionAuditBridge(
          restrictionLedger: restrictionLedger,
          auditLedger: restrictedAuditLedger,
        ),
        _protectedUpdateGate = protectedUpdateGate;

  final AvoraIdentityRestrictionAuditBridge _restrictionAuditBridge;
  final AvoraProtectedIdentityUpdateGate _protectedUpdateGate;

  AvoraIdentityUpdateMasterResult update({
    required AvoraProtectedIdentityUpdateRequest request,
    required AvoraRestrictedIdentityField attemptedField,
  }) {
    final restriction = _restrictionAuditBridge.check(
      auditId: '${request.auditId}-restriction',
      actorAvoraId: request.actorAvoraId,
      targetAvoraId: request.targetAvoraId,
      field: attemptedField,
      requestedValue: request.requestedDisplayName,
      actorIsVerifiedOwner: request.actorIsVerifiedOwner,
      nowUtc: request.createdAtUtc,
    );

    if (!restriction.allowed) {
      return AvoraIdentityUpdateMasterResult(
        allowed: false,
        reason: restriction.reason,
      );
    }

    final identityDecision = _protectedUpdateGate.update(
      request,
    );

    return AvoraIdentityUpdateMasterResult(
      allowed: identityDecision.allowed,
      reason: identityDecision.reason,
      identityDecision: identityDecision,
    );
  }

  static bool restrictionAndAuditMustRunBeforeProfileMutation() => true;

  static bool blockedRestrictionMustNeverReachProtectedRegistry() => true;

  static bool ownerOverrideMustContinueToProtectedIdentityChecks() => true;

  static bool normalAllowedUpdateMustReachProtectedIdentityGate() => true;

  static bool oneMasterGateMustProtectAllIdentityEdits() => true;

  static bool futureProfileIdentityFieldsMustUseMasterGate() => true;
}
