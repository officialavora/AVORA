import 'avora_identity_impersonation_guard.dart';

enum AvoraProtectedIdentityChangeType {
  register,
  titleChange,
  displayNameChange,
  profileMediaChange,
  ownerOverride,
}

class AvoraProtectedIdentityAuditRecord {
  const AvoraProtectedIdentityAuditRecord({
    required this.auditId,
    required this.targetAvoraId,
    required this.actorAvoraId,
    required this.changeType,
    required this.beforeValue,
    required this.afterValue,
    required this.reason,
    required this.createdAtUtc,
  });

  final String auditId;
  final String targetAvoraId;
  final String actorAvoraId;
  final AvoraProtectedIdentityChangeType changeType;
  final String beforeValue;
  final String afterValue;
  final String reason;
  final DateTime createdAtUtc;
}

class AvoraProtectedIdentityRegistry {
  final Map<String, AvoraProtectedIdentityProfile> _profiles =
      <String, AvoraProtectedIdentityProfile>{};

  final Map<String, AvoraProtectedIdentityAuditRecord> _audits =
      <String, AvoraProtectedIdentityAuditRecord>{};

  Iterable<AvoraProtectedIdentityProfile> get protectedProfiles =>
      List<AvoraProtectedIdentityProfile>.unmodifiable(
        _profiles.values,
      );

  List<AvoraProtectedIdentityAuditRecord> get auditHistory =>
      List<AvoraProtectedIdentityAuditRecord>.unmodifiable(
        _audits.values,
      );

  void register({
    required AvoraProtectedIdentityProfile profile,
    required String auditId,
    required String actorAvoraId,
    required String reason,
    required DateTime createdAtUtc,
  }) {
    _validateAuditFields(
      auditId: auditId,
      actorAvoraId: actorAvoraId,
      reason: reason,
    );

    if (_profiles.containsKey(profile.avoraId)) {
      throw StateError('protected_identity_already_registered');
    }

    if (_audits.containsKey(auditId)) {
      throw StateError('duplicate_protected_identity_audit');
    }

    _profiles[profile.avoraId] = profile;

    _audits[auditId] = AvoraProtectedIdentityAuditRecord(
      auditId: auditId,
      targetAvoraId: profile.avoraId,
      actorAvoraId: actorAvoraId,
      changeType: AvoraProtectedIdentityChangeType.register,
      beforeValue: '',
      afterValue: profile.normalizedDisplayName,
      reason: reason,
      createdAtUtc: createdAtUtc.toUtc(),
    );
  }

  AvoraProtectedIdentityProfile? profileFor(
    String avoraId,
  ) {
    return _profiles[avoraId];
  }

  void replace({
    required AvoraProtectedIdentityProfile profile,
    required String auditId,
    required String actorAvoraId,
    required AvoraProtectedIdentityChangeType changeType,
    required String beforeValue,
    required String afterValue,
    required String reason,
    required DateTime createdAtUtc,
  }) {
    _validateAuditFields(
      auditId: auditId,
      actorAvoraId: actorAvoraId,
      reason: reason,
    );

    if (!_profiles.containsKey(profile.avoraId)) {
      throw StateError('protected_identity_not_registered');
    }

    if (_audits.containsKey(auditId)) {
      throw StateError('duplicate_protected_identity_audit');
    }

    _profiles[profile.avoraId] = profile;

    _audits[auditId] = AvoraProtectedIdentityAuditRecord(
      auditId: auditId,
      targetAvoraId: profile.avoraId,
      actorAvoraId: actorAvoraId,
      changeType: changeType,
      beforeValue: beforeValue,
      afterValue: afterValue,
      reason: reason,
      createdAtUtc: createdAtUtc.toUtc(),
    );
  }

  List<AvoraProtectedIdentityAuditRecord> historyFor(
    String avoraId,
  ) {
    return List<AvoraProtectedIdentityAuditRecord>.unmodifiable(
      _audits.values.where(
        (record) => record.targetAvoraId == avoraId,
      ),
    );
  }

  void _validateAuditFields({
    required String auditId,
    required String actorAvoraId,
    required String reason,
  }) {
    if (auditId.trim().isEmpty ||
        actorAvoraId.trim().isEmpty ||
        reason.trim().isEmpty) {
      throw ArgumentError('protected_identity_audit_required');
    }
  }

  static bool protectedIdentityMustBeServerRegistered() => true;
  static bool titleChangesMustBeAudited() => true;
  static bool displayNameChangesMustBeAudited() => true;
  static bool profileMediaChangesMustBeAudited() => true;
  static bool ownerOverridesMustBeAudited() => true;
  static bool oldIdentityHistoryMustRemainAvailable() => true;
  static bool futureProtectedRolesMustUseRegistry() => true;
}
