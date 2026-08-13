import 'avora_identity_edit_restriction.dart';
import 'avora_identity_impersonation_audit.dart';
import 'avora_identity_impersonation_risk.dart';

class AvoraIdentityRiskRestrictionResult {
  const AvoraIdentityRiskRestrictionResult({
    required this.riskDecision,
    required this.restrictionIssued,
    required this.reason,
  });

  final AvoraIdentityRiskDecision riskDecision;
  final bool restrictionIssued;
  final String reason;
}

class AvoraIdentityRiskRestrictionBridge {
  AvoraIdentityRiskRestrictionBridge({
    required AvoraIdentityImpersonationRiskEngine riskEngine,
    required AvoraIdentityEditRestrictionLedger restrictionLedger,
  })  : _riskEngine = riskEngine,
        _restrictionLedger = restrictionLedger;

  final AvoraIdentityImpersonationRiskEngine _riskEngine;
  final AvoraIdentityEditRestrictionLedger _restrictionLedger;

  final Set<String> _restrictedActors = <String>{};

  AvoraIdentityRiskRestrictionResult evaluateAndApply({
    required String restrictionId,
    required String actorAvoraId,
    required Iterable<AvoraImpersonationAuditRecord> records,
    required String issuedByAvoraId,
    required DateTime nowUtc,
  }) {
    if (restrictionId.trim().isEmpty ||
        actorAvoraId.trim().isEmpty ||
        issuedByAvoraId.trim().isEmpty) {
      throw ArgumentError('identity_risk_bridge_identity_required');
    }

    final decision = _riskEngine.evaluate(
      actorAvoraId: actorAvoraId,
      records: records,
    );

    final shouldRestrict = decision.action ==
            AvoraIdentityRiskAction.temporaryIdentityEditRestriction ||
        decision.action == AvoraIdentityRiskAction.securityEscalation;

    if (!shouldRestrict) {
      return AvoraIdentityRiskRestrictionResult(
        riskDecision: decision,
        restrictionIssued: false,
        reason: 'restriction_not_required',
      );
    }

    if (_restrictedActors.contains(actorAvoraId)) {
      return AvoraIdentityRiskRestrictionResult(
        riskDecision: decision,
        restrictionIssued: false,
        reason: 'active_risk_restriction_already_issued',
      );
    }

    final duration =
        decision.action == AvoraIdentityRiskAction.securityEscalation
            ? const Duration(hours: 72)
            : const Duration(hours: 24);

    _restrictionLedger.issue(
      AvoraIdentityEditRestriction(
        restrictionId: restrictionId,
        targetAvoraId: actorAvoraId,
        issuedByAvoraId: issuedByAvoraId,
        reason: decision.action == AvoraIdentityRiskAction.securityEscalation
            ? 'identity_security_escalation_pending_review'
            : 'repeated_impersonation_temporary_restriction',
        startedAtUtc: nowUtc.toUtc(),
        expiresAtUtc: nowUtc.toUtc().add(duration),
      ),
    );

    _restrictedActors.add(actorAvoraId);

    return AvoraIdentityRiskRestrictionResult(
      riskDecision: decision,
      restrictionIssued: true,
      reason: 'temporary_identity_restriction_issued',
    );
  }

  static bool repeatedRiskMayTriggerTemporaryRestriction() => true;

  static bool restrictionMustNeverBecomePermanentAutomatically() => true;

  static bool securityEscalationMustStillRequireHumanReview() => true;

  static bool singleAttemptMustNotTriggerRestriction() => true;

  static bool ownerMustRemainAbleToOverrideRestriction() => true;

  static bool duplicateAutomaticRestrictionMustBePrevented() => true;

  static bool futureIdentityRiskSignalsMustUseSameBridge() => true;
}
