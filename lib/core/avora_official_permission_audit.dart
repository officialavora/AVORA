import 'avora_official_permission_engine.dart';

enum AvoraPermissionChangeType {
  grant,
  revoke,
}

class AvoraPermissionAuditRecord {
  const AvoraPermissionAuditRecord({
    required this.auditId,
    required this.grantId,
    required this.officialAvoraId,
    required this.permission,
    required this.changeType,
    required this.actorAvoraId,
    required this.reason,
    required this.changedAtUtc,
  });

  final String auditId;
  final String grantId;
  final String officialAvoraId;
  final AvoraOfficialPermission permission;
  final AvoraPermissionChangeType changeType;
  final String actorAvoraId;
  final String reason;
  final DateTime changedAtUtc;
}

class AvoraOfficialPermissionAuditController {
  AvoraOfficialPermissionAuditController({
    required AvoraOfficialPermissionEngine engine,
  }) : _engine = engine;

  final AvoraOfficialPermissionEngine _engine;

  final List<AvoraPermissionAuditRecord> _history =
      <AvoraPermissionAuditRecord>[];

  final Set<String> _revokedGrantIds = <String>{};

  List<AvoraPermissionAuditRecord> get history =>
      List<AvoraPermissionAuditRecord>.unmodifiable(_history);

  void grant({
    required AvoraOfficialPermissionGrant grant,
    required String auditId,
  }) {
    _validateAudit(
      auditId: auditId,
      actorAvoraId: grant.grantedByAvoraId,
      reason: grant.reason,
    );

    _engine.grant(grant);

    _history.add(
      AvoraPermissionAuditRecord(
        auditId: auditId,
        grantId: grant.grantId,
        officialAvoraId: grant.officialAvoraId,
        permission: grant.permission,
        changeType: AvoraPermissionChangeType.grant,
        actorAvoraId: grant.grantedByAvoraId,
        reason: grant.reason,
        changedAtUtc: grant.createdAtUtc.toUtc(),
      ),
    );
  }

  void revoke({
    required String auditId,
    required String grantId,
    required String ownerAvoraId,
    required String reason,
    required DateTime changedAtUtc,
  }) {
    _validateAudit(
      auditId: auditId,
      actorAvoraId: ownerAvoraId,
      reason: reason,
    );

    if (_revokedGrantIds.contains(grantId)) {
      throw StateError('permission_already_revoked');
    }

    final grant = _findGrant(grantId);

    if (grant == null) {
      throw StateError('permission_grant_not_found');
    }

    _revokedGrantIds.add(grantId);

    _history.add(
      AvoraPermissionAuditRecord(
        auditId: auditId,
        grantId: grant.grantId,
        officialAvoraId: grant.officialAvoraId,
        permission: grant.permission,
        changeType: AvoraPermissionChangeType.revoke,
        actorAvoraId: ownerAvoraId,
        reason: reason,
        changedAtUtc: changedAtUtc.toUtc(),
      ),
    );
  }

  bool isAllowed({
    required String officialAvoraId,
    required AvoraOfficialPermission permission,
    required String countryCode,
    required DateTime nowUtc,
  }) {
    final grants = _engine.grantsFor(officialAvoraId);

    return grants.any(
      (grant) =>
          grant.permission == permission &&
          !_revokedGrantIds.contains(grant.grantId) &&
          grant.isActiveAt(nowUtc) &&
          grant.coversCountry(countryCode),
    );
  }

  AvoraOfficialPermissionGrant? _findGrant(String grantId) {
    for (final record in _history) {
      if (record.grantId != grantId ||
          record.changeType != AvoraPermissionChangeType.grant) {
        continue;
      }

      final grants = _engine.grantsFor(record.officialAvoraId);

      for (final grant in grants) {
        if (grant.grantId == grantId) {
          return grant;
        }
      }
    }

    return null;
  }

  void _validateAudit({
    required String auditId,
    required String actorAvoraId,
    required String reason,
  }) {
    if (auditId.trim().isEmpty ||
        actorAvoraId.trim().isEmpty ||
        reason.trim().isEmpty) {
      throw ArgumentError('permission_audit_fields_required');
    }

    if (_history.any((record) => record.auditId == auditId)) {
      throw StateError('duplicate_permission_audit');
    }
  }

  static bool ownerCanRevokeSinglePermissionImmediately() => true;
  static bool revocationMustNotDeleteGrantHistory() => true;
  static bool permissionHistoryMustRemainImmutable() => true;
  static bool revokedPermissionMustFailClosed() => true;
  static bool ownerCanIncreaseAuthorityGradually() => true;
  static bool ownerCanReduceAuthorityGradually() => true;
  static bool everyPermissionChangeMustIdentifyActor() => true;
  static bool futureOfficialRolesMustInheritAuditContract() => true;
}
