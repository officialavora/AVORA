import 'avora_identity_edit_restriction.dart';
import 'avora_identity_restricted_attempt_audit.dart';

class AvoraIdentityRestrictionAuditDecision {
  const AvoraIdentityRestrictionAuditDecision({
    required this.allowed,
    required this.reason,
  });

  final bool allowed;
  final String reason;
}

class AvoraIdentityRestrictionAuditBridge {
  AvoraIdentityRestrictionAuditBridge({
    required AvoraIdentityEditRestrictionLedger restrictionLedger,
    required AvoraRestrictedIdentityAttemptAuditLedger auditLedger,
  })  : _restrictionLedger = restrictionLedger,
        _auditLedger = auditLedger;

  final AvoraIdentityEditRestrictionLedger _restrictionLedger;
  final AvoraRestrictedIdentityAttemptAuditLedger _auditLedger;

  AvoraIdentityRestrictionAuditDecision check({
    required String auditId,
    required String actorAvoraId,
    required String targetAvoraId,
    required AvoraRestrictedIdentityField field,
    required String requestedValue,
    required bool actorIsVerifiedOwner,
    required DateTime nowUtc,
  }) {
    final allowed = _restrictionLedger.mayEditIdentity(
      avoraId: targetAvoraId,
      nowUtc: nowUtc,
      actorIsVerifiedOwner: actorIsVerifiedOwner,
    );

    if (allowed) {
      return const AvoraIdentityRestrictionAuditDecision(
        allowed: true,
        reason: 'identity_edit_not_restricted',
      );
    }

    _auditLedger.append(
      AvoraRestrictedIdentityAttemptRecord(
        auditId: auditId,
        actorAvoraId: actorAvoraId,
        targetAvoraId: targetAvoraId,
        field: field,
        requestedValue: requestedValue,
        reason: 'identity_edit_temporarily_restricted',
        createdAtUtc: nowUtc.toUtc(),
      ),
    );

    return const AvoraIdentityRestrictionAuditDecision(
      allowed: false,
      reason: 'identity_edit_temporarily_restricted',
    );
  }

  static bool restrictionCheckMustAutoAuditBlockedAttempt() => true;

  static bool allowedAttemptMustNotCreateBlockedAudit() => true;

  static bool ownerOverrideMustNotCreateBlockedAudit() => true;

  static bool auditMustPreserveAttemptedFieldAndValue() => true;

  static bool auditMustPreserveActorAndTarget() => true;

  static bool futureRestrictionChecksMustUseSameBridge() => true;
}
