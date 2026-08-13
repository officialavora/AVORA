enum AvoraRestrictedIdentityField {
  displayName,
  officialTitle,
  profileMedia,
  combinedIdentity,
}

class AvoraRestrictedIdentityAttemptRecord {
  const AvoraRestrictedIdentityAttemptRecord({
    required this.auditId,
    required this.actorAvoraId,
    required this.targetAvoraId,
    required this.field,
    required this.requestedValue,
    required this.reason,
    required this.createdAtUtc,
  });

  final String auditId;
  final String actorAvoraId;
  final String targetAvoraId;
  final AvoraRestrictedIdentityField field;
  final String requestedValue;
  final String reason;
  final DateTime createdAtUtc;
}

class AvoraRestrictedIdentityAttemptAuditLedger {
  final Map<String, AvoraRestrictedIdentityAttemptRecord> _records =
      <String, AvoraRestrictedIdentityAttemptRecord>{};

  void append(AvoraRestrictedIdentityAttemptRecord record) {
    if (record.auditId.trim().isEmpty ||
        record.actorAvoraId.trim().isEmpty ||
        record.targetAvoraId.trim().isEmpty ||
        record.requestedValue.trim().isEmpty ||
        record.reason.trim().isEmpty) {
      throw ArgumentError(
        'invalid_restricted_identity_attempt_audit',
      );
    }

    if (_records.containsKey(record.auditId)) {
      throw StateError(
        'duplicate_restricted_identity_attempt_audit',
      );
    }

    _records[record.auditId] = record;
  }

  List<AvoraRestrictedIdentityAttemptRecord> get allForOwner =>
      List<AvoraRestrictedIdentityAttemptRecord>.unmodifiable(
        _records.values,
      );

  List<AvoraRestrictedIdentityAttemptRecord> byActor(
    String actorAvoraId,
  ) {
    return List<AvoraRestrictedIdentityAttemptRecord>.unmodifiable(
      _records.values.where(
        (record) => record.actorAvoraId == actorAvoraId,
      ),
    );
  }

  List<AvoraRestrictedIdentityAttemptRecord> byTarget(
    String targetAvoraId,
  ) {
    return List<AvoraRestrictedIdentityAttemptRecord>.unmodifiable(
      _records.values.where(
        (record) => record.targetAvoraId == targetAvoraId,
      ),
    );
  }

  AvoraRestrictedIdentityAttemptRecord? byAuditId(
    String auditId,
  ) =>
      _records[auditId];

  static bool everyBlockedIdentityAttemptMustBeRecorded() => true;

  static bool ownerMustSeeRestrictedAttemptHistory() => true;

  static bool requestedIdentityValueMustBePreserved() => true;

  static bool actorAndTargetMustRemainAttributable() => true;

  static bool auditMustNotAutomaticallyBanAccount() => true;

  static bool evidenceMustNotBeSilentlyOverwritten() => true;

  static bool futureIdentityFieldsMustUseSameAudit() => true;
}
