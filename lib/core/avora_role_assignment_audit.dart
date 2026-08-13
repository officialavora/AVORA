enum AvoraRoleMutationAuditAction {
  roleActivated,
  capabilityActivated,
  roleRevoked,
  capabilityRevoked,
}

/// Immutable audit snapshot for every role/capability assignment mutation.
///
/// IDs and historical mutation facts are snapshots. They must never be
/// retroactively rewritten when display names, roles, scopes, or policy
/// configuration change later.
class AvoraRoleMutationAuditEvent {
  const AvoraRoleMutationAuditEvent({
    required this.actorAvoraId,
    required this.targetAvoraId,
    required this.action,
    required this.subjectType,
    required this.subjectKey,
    required this.scopeType,
    required this.scopeId,
    required this.occurredAtUtc,
    required this.reasonCode,
    required this.reasonText,
    required this.beforeActive,
    required this.afterActive,
    required this.changed,
    required this.policyAudienceKey,
  });

  final String actorAvoraId;
  final String targetAvoraId;
  final AvoraRoleMutationAuditAction action;

  /// "role" or "capability".
  final String subjectType;

  /// Enum-name snapshot, e.g. admin / countryManager.
  final String subjectKey;

  /// Scope snapshot at mutation time.
  final String scopeType;
  final String scopeId;

  final DateTime occurredAtUtc;

  final String reasonCode;
  final String reasonText;

  /// Authority state in the exact affected role/capability + scope.
  final bool beforeActive;
  final bool afterActive;

  /// False for idempotent duplicate activation/revocation attempts.
  final bool changed;

  /// Empty when the subject intentionally has no operational policy mapping.
  final String policyAudienceKey;

  static bool immutableAvoraIdsRemainAuthoritative() => true;

  static bool historicalAuditSnapshotsCanBeSilentlyRewritten() => false;

  static bool auditHistoryCanBeSilentlyDeletedByClient() => false;

  static bool revocationDeletesOriginalActivationAudit() => false;
}
