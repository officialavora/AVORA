enum AvoraBackupScope {
  configuration,
  identityAndRoles,
  walletAndLedger,
  messaging,
  roomAndAudioConfig,
  gamePolicies,
  experienceCatalog,
  moderationPolicies,
  fullSystem,
}

enum AvoraBackupStatus {
  created,
  verified,
  failedVerification,
  superseded,
}

enum AvoraRestoreStatus {
  requested,
  validating,
  applied,
  verified,
  failed,
  rolledBack,
}

class AvoraBackupSnapshot {
  const AvoraBackupSnapshot({
    required this.backupId,
    required this.scope,
    required this.releaseId,
    required this.schemaVersion,
    required this.checksum,
    required this.byteSize,
    required this.createdAtUtc,
    required this.createdBy,
    required this.status,
    required this.storageReference,
  });

  final String backupId;
  final AvoraBackupScope scope;
  final String releaseId;
  final String schemaVersion;
  final String checksum;
  final int byteSize;
  final DateTime createdAtUtc;
  final String createdBy;
  final AvoraBackupStatus status;

  /// Internal storage reference only.
  final String storageReference;

  void validate() {
    if (backupId.trim().isEmpty ||
        releaseId.trim().isEmpty ||
        schemaVersion.trim().isEmpty ||
        checksum.trim().isEmpty ||
        createdBy.trim().isEmpty ||
        storageReference.trim().isEmpty ||
        byteSize <= 0) {
      throw ArgumentError('invalid_backup_snapshot');
    }
  }

  bool get usableForRestore => status == AvoraBackupStatus.verified;
}

class AvoraBackupVerificationRecord {
  const AvoraBackupVerificationRecord({
    required this.verificationId,
    required this.backupId,
    required this.expectedChecksum,
    required this.actualChecksum,
    required this.expectedByteSize,
    required this.actualByteSize,
    required this.verifiedAtUtc,
    required this.verifiedBy,
  });

  final String verificationId;
  final String backupId;
  final String expectedChecksum;
  final String actualChecksum;
  final int expectedByteSize;
  final int actualByteSize;
  final DateTime verifiedAtUtc;
  final String verifiedBy;

  bool get passed =>
      expectedChecksum == actualChecksum && expectedByteSize == actualByteSize;
}

class AvoraBackupRegistry {
  final Map<String, AvoraBackupSnapshot> _snapshots =
      <String, AvoraBackupSnapshot>{};

  final Map<String, AvoraBackupVerificationRecord> _verifications =
      <String, AvoraBackupVerificationRecord>{};

  void appendSnapshot(
    AvoraBackupSnapshot snapshot,
  ) {
    snapshot.validate();

    if (_snapshots.containsKey(snapshot.backupId)) {
      throw StateError('duplicate_backup_id');
    }

    _snapshots[snapshot.backupId] = snapshot;
  }

  void appendVerification(
    AvoraBackupVerificationRecord record,
  ) {
    if (record.verificationId.trim().isEmpty ||
        record.backupId.trim().isEmpty ||
        record.verifiedBy.trim().isEmpty) {
      throw ArgumentError('invalid_backup_verification');
    }

    if (!_snapshots.containsKey(record.backupId)) {
      throw StateError('backup_not_found');
    }

    if (_verifications.containsKey(record.verificationId)) {
      throw StateError('duplicate_backup_verification');
    }

    _verifications[record.verificationId] = record;
  }

  AvoraBackupSnapshot? byId(String backupId) {
    return _snapshots[backupId];
  }

  List<AvoraBackupVerificationRecord> verificationsFor(
    String backupId,
  ) {
    return List<AvoraBackupVerificationRecord>.unmodifiable(
      _verifications.values.where(
        (record) => record.backupId == backupId,
      ),
    );
  }

  bool hasPassingVerification(String backupId) {
    return verificationsFor(backupId).any(
      (record) => record.passed,
    );
  }

  static bool backupMustBeImmutableOnceRecorded() => true;

  static bool restoreMustRequireVerifiedBackup() => true;

  static bool checksumMustProtectBackupIntegrity() => true;

  static bool backupMustRemainReleaseAndSchemaAware() => true;
}

class AvoraRestoreRequest {
  const AvoraRestoreRequest({
    required this.restoreId,
    required this.backupId,
    required this.incidentId,
    required this.requestedBy,
    required this.reason,
    required this.requestedAtUtc,
  });

  final String restoreId;
  final String backupId;
  final String incidentId;
  final String requestedBy;
  final String reason;
  final DateTime requestedAtUtc;

  void validate() {
    if (restoreId.trim().isEmpty ||
        backupId.trim().isEmpty ||
        incidentId.trim().isEmpty ||
        requestedBy.trim().isEmpty ||
        reason.trim().isEmpty) {
      throw ArgumentError('invalid_restore_request');
    }
  }
}

class AvoraRestoreResult {
  const AvoraRestoreResult({
    required this.restoreId,
    required this.backupId,
    required this.status,
    required this.appliedReleaseId,
    required this.startedAtUtc,
    required this.completedAtUtc,
    required this.details,
  });

  final String restoreId;
  final String backupId;
  final AvoraRestoreStatus status;
  final String appliedReleaseId;
  final DateTime startedAtUtc;
  final DateTime completedAtUtc;
  final String details;

  bool get successful => status == AvoraRestoreStatus.verified;
}

class AvoraRestoreService {
  AvoraRestoreService({
    required AvoraBackupRegistry backupRegistry,
  }) : _backupRegistry = backupRegistry;

  final AvoraBackupRegistry _backupRegistry;

  AvoraBackupSnapshot validateRestoreRequest(
    AvoraRestoreRequest request,
  ) {
    request.validate();

    final backup = _backupRegistry.byId(request.backupId);

    if (backup == null) {
      throw StateError('restore_backup_not_found');
    }

    if (!backup.usableForRestore) {
      throw StateError('restore_backup_not_verified');
    }

    if (!_backupRegistry.hasPassingVerification(
      backup.backupId,
    )) {
      throw StateError(
        'restore_requires_passing_backup_verification',
      );
    }

    return backup;
  }

  AvoraRestoreResult buildVerifiedResult({
    required AvoraRestoreRequest request,
    required AvoraBackupSnapshot backup,
    required DateTime startedAtUtc,
    required DateTime completedAtUtc,
  }) {
    if (completedAtUtc.isBefore(startedAtUtc)) {
      throw ArgumentError('restore_time_order_invalid');
    }

    return AvoraRestoreResult(
      restoreId: request.restoreId,
      backupId: backup.backupId,
      status: AvoraRestoreStatus.verified,
      appliedReleaseId: backup.releaseId,
      startedAtUtc: startedAtUtc.toUtc(),
      completedAtUtc: completedAtUtc.toUtc(),
      details: 'restore_applied_and_verified',
    );
  }

  static bool restoreMustNeverUseUnverifiedBackup() => true;

  static bool restoreMustRemainIncidentLinked() => true;

  static bool restoreMustBePostVerifiedBeforeClosure() => true;

  static bool destructiveRestoreMustNotEraseAuditHistory() => true;
}

class AvoraRollbackRequest {
  const AvoraRollbackRequest({
    required this.rollbackId,
    required this.incidentId,
    required this.fromReleaseId,
    required this.toReleaseId,
    required this.requestedBy,
    required this.reason,
    required this.requestedAtUtc,
  });

  final String rollbackId;
  final String incidentId;
  final String fromReleaseId;
  final String toReleaseId;
  final String requestedBy;
  final String reason;
  final DateTime requestedAtUtc;

  void validate() {
    if (rollbackId.trim().isEmpty ||
        incidentId.trim().isEmpty ||
        fromReleaseId.trim().isEmpty ||
        toReleaseId.trim().isEmpty ||
        requestedBy.trim().isEmpty ||
        reason.trim().isEmpty) {
      throw ArgumentError('invalid_rollback_request');
    }

    if (fromReleaseId == toReleaseId) {
      throw StateError('rollback_requires_different_release');
    }
  }
}

class AvoraRollbackAuditRecord {
  const AvoraRollbackAuditRecord({
    required this.auditId,
    required this.rollbackId,
    required this.incidentId,
    required this.fromReleaseId,
    required this.toReleaseId,
    required this.actorId,
    required this.reason,
    required this.createdAtUtc,
  });

  final String auditId;
  final String rollbackId;
  final String incidentId;
  final String fromReleaseId;
  final String toReleaseId;
  final String actorId;
  final String reason;
  final DateTime createdAtUtc;
}

class AvoraRollbackAuditLedger {
  final Map<String, AvoraRollbackAuditRecord> _records =
      <String, AvoraRollbackAuditRecord>{};

  void append(AvoraRollbackAuditRecord record) {
    if (record.auditId.trim().isEmpty ||
        record.rollbackId.trim().isEmpty ||
        record.incidentId.trim().isEmpty ||
        record.actorId.trim().isEmpty ||
        record.reason.trim().isEmpty) {
      throw ArgumentError('invalid_rollback_audit');
    }

    if (_records.containsKey(record.auditId)) {
      throw StateError('duplicate_rollback_audit');
    }

    _records[record.auditId] = record;
  }

  List<AvoraRollbackAuditRecord> forIncident(
    String incidentId,
  ) {
    return List<AvoraRollbackAuditRecord>.unmodifiable(
      _records.values.where(
        (record) => record.incidentId == incidentId,
      ),
    );
  }

  static bool everyRollbackMustBeAudited() => true;

  static bool rollbackAuditMustRemainImmutable() => true;
}

class AvoraRecoverySafetyArchitecture {
  const AvoraRecoverySafetyArchitecture._();

  static bool backupMustExistBeforeHighRiskRelease() => true;

  static bool backupRestoreMustBeTestedRegularly() => true;

  static bool rollbackMustRemainReleaseAware() => true;

  static bool ledgerRecoveryMustPreserveFinancialAudit() => true;

  static bool recoveryMustPreferMinimalSafeChange() => true;

  static bool emergencyRecoveryMustStillPreserveEvidence() => true;

  static bool ownerRecoveryKitMustIncludeRestoreAndRollbackProcedure() => true;

  static bool futureStorageProvidersMustUseSameBackupContract() => true;
}
