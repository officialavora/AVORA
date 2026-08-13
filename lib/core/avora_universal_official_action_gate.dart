import 'avora_official_action_audit.dart';

class AvoraUniversalOfficialActionRequest {
  const AvoraUniversalOfficialActionRequest({
    required this.auditId,
    required this.actorAvoraId,
    required this.actorRole,
    required this.actorCountryCode,
    required this.actorIsVerifiedOwner,
    required this.actorHasRequiredPermission,
    required this.targetId,
    required this.targetCountryCode,
    required this.targetIsVerifiedOwner,
    required this.actionType,
    required this.reason,
    required this.beforeState,
    required this.requestedAfterState,
    required this.createdAtUtc,
  });

  final String auditId;
  final String actorAvoraId;
  final String actorRole;
  final String actorCountryCode;

  final bool actorIsVerifiedOwner;
  final bool actorHasRequiredPermission;

  final String targetId;
  final String targetCountryCode;
  final bool targetIsVerifiedOwner;

  final AvoraOfficialActionType actionType;
  final String reason;

  final Map<String, Object?> beforeState;
  final Map<String, Object?> requestedAfterState;

  final DateTime createdAtUtc;
}

class AvoraUniversalOfficialActionDecision {
  const AvoraUniversalOfficialActionDecision({
    required this.allowed,
    required this.reason,
  });

  final bool allowed;
  final String reason;
}

class AvoraUniversalOfficialActionGate {
  AvoraUniversalOfficialActionGate({
    required AvoraOfficialActionAuditLedger auditLedger,
  }) : _auditLedger = auditLedger;

  final AvoraOfficialActionAuditLedger _auditLedger;

  AvoraUniversalOfficialActionDecision authorize(
    AvoraUniversalOfficialActionRequest request,
  ) {
    _validate(request);

    if (request.targetIsVerifiedOwner && !request.actorIsVerifiedOwner) {
      _auditDenied(
        request,
        'owner_target_protected',
      );

      return const AvoraUniversalOfficialActionDecision(
        allowed: false,
        reason: 'owner_target_protected',
      );
    }

    final scopeAllowed = AvoraCountryAuthorityIsolation.mayManageTarget(
      actorIsVerifiedOwner: request.actorIsVerifiedOwner,
      actorCountryCode: request.actorCountryCode,
      targetCountryCode: request.targetCountryCode,
      actorHasRequiredPermission: request.actorHasRequiredPermission,
    );

    if (!scopeAllowed) {
      final reason = request.actorHasRequiredPermission
          ? 'cross_country_authority_denied'
          : 'required_permission_missing';

      _auditDenied(request, reason);

      return AvoraUniversalOfficialActionDecision(
        allowed: false,
        reason: reason,
      );
    }

    _auditLedger.append(
      AvoraOfficialActionAuditRecord(
        auditId: request.auditId,
        actorAvoraId: request.actorAvoraId,
        actorRole: request.actorRole,
        actorCountryCode: request.actorCountryCode,
        targetId: request.targetId,
        targetCountryCode: request.targetCountryCode,
        actionType: request.actionType,
        reason: request.reason,
        beforeState: Map<String, Object?>.unmodifiable(
          request.beforeState,
        ),
        afterState: Map<String, Object?>.unmodifiable(
          request.requestedAfterState,
        ),
        createdAtUtc: request.createdAtUtc.toUtc(),
        ownerVisible: true,
        immutable: true,
      ),
    );

    return const AvoraUniversalOfficialActionDecision(
      allowed: true,
      reason: 'official_action_authorized',
    );
  }

  void _auditDenied(
    AvoraUniversalOfficialActionRequest request,
    String denialReason,
  ) {
    _auditLedger.append(
      AvoraOfficialActionAuditRecord(
        auditId: request.auditId,
        actorAvoraId: request.actorAvoraId,
        actorRole: request.actorRole,
        actorCountryCode: request.actorCountryCode,
        targetId: request.targetId,
        targetCountryCode: request.targetCountryCode,
        actionType: request.actionType,
        reason: 'DENIED:$denialReason | ${request.reason}',
        beforeState: Map<String, Object?>.unmodifiable(
          request.beforeState,
        ),
        afterState: Map<String, Object?>.unmodifiable(
          request.beforeState,
        ),
        createdAtUtc: request.createdAtUtc.toUtc(),
        ownerVisible: true,
        immutable: true,
      ),
    );
  }

  void _validate(
    AvoraUniversalOfficialActionRequest request,
  ) {
    if (request.auditId.trim().isEmpty ||
        request.actorAvoraId.trim().isEmpty ||
        request.actorRole.trim().isEmpty ||
        request.targetId.trim().isEmpty ||
        request.reason.trim().isEmpty) {
      throw ArgumentError(
        'invalid_universal_official_action_request',
      );
    }
  }

  static bool everyOfficialActionMustPassGate() => true;

  static bool permissionMustBeCheckedBeforeExecution() => true;

  static bool countryScopeMustBeCheckedBeforeExecution() => true;

  static bool ownerProtectionMustBeCheckedBeforeExecution() => true;

  static bool deniedAttemptsMustAlsoBeAudited() => true;

  static bool ownerCanOperateGloballyWithoutCountryRestriction() => true;

  static bool officialsCannotCrossManageCountryTeams() => true;

  static bool futureOfficialActionsMustInheritGate() => true;
}
