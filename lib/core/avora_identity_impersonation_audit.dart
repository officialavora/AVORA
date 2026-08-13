enum AvoraImpersonationAttemptType {
  unauthorizedTitle,
  protectedNameClone,
  protectedProfileMediaClone,
  other,
}

enum AvoraImpersonationReviewStatus {
  pending,
  investigating,
  dismissed,
  confirmed,
}

class AvoraImpersonationAuditRecord {
  const AvoraImpersonationAuditRecord({
    required this.auditId,
    required this.actorAvoraId,
    required this.attemptType,
    required this.requestedValue,
    required this.reason,
    required this.createdAtUtc,
    required this.status,
    this.protectedAvoraId,
  });

  final String auditId;
  final String actorAvoraId;
  final String? protectedAvoraId;

  final AvoraImpersonationAttemptType attemptType;
  final String requestedValue;
  final String reason;
  final DateTime createdAtUtc;

  final AvoraImpersonationReviewStatus status;

  AvoraImpersonationAuditRecord copyWith({
    AvoraImpersonationReviewStatus? status,
  }) {
    return AvoraImpersonationAuditRecord(
      auditId: auditId,
      actorAvoraId: actorAvoraId,
      protectedAvoraId: protectedAvoraId,
      attemptType: attemptType,
      requestedValue: requestedValue,
      reason: reason,
      createdAtUtc: createdAtUtc,
      status: status ?? this.status,
    );
  }
}

class AvoraIdentityImpersonationAuditLedger {
  final Map<String, AvoraImpersonationAuditRecord> _records =
      <String, AvoraImpersonationAuditRecord>{};

  List<AvoraImpersonationAuditRecord> get allForOwner =>
      List<AvoraImpersonationAuditRecord>.unmodifiable(
        _records.values,
      );

  void append(AvoraImpersonationAuditRecord record) {
    if (record.auditId.trim().isEmpty ||
        record.actorAvoraId.trim().isEmpty ||
        record.requestedValue.trim().isEmpty ||
        record.reason.trim().isEmpty) {
      throw ArgumentError('invalid_impersonation_audit');
    }

    if (_records.containsKey(record.auditId)) {
      throw StateError('duplicate_impersonation_audit');
    }

    _records[record.auditId] = record;
  }

  AvoraImpersonationAuditRecord? byAuditId(
    String auditId,
  ) {
    return _records[auditId.trim()];
  }

  List<AvoraImpersonationAuditRecord> byActor(
    String actorAvoraId,
  ) {
    return List<AvoraImpersonationAuditRecord>.unmodifiable(
      _records.values.where(
        (record) => record.actorAvoraId == actorAvoraId,
      ),
    );
  }

  List<AvoraImpersonationAuditRecord> pendingForOwner() {
    return List<AvoraImpersonationAuditRecord>.unmodifiable(
      _records.values.where(
        (record) => record.status == AvoraImpersonationReviewStatus.pending,
      ),
    );
  }

  void updateReviewStatus({
    required String auditId,
    required AvoraImpersonationReviewStatus status,
  }) {
    final current = byAuditId(auditId);

    if (current == null) {
      throw StateError('impersonation_audit_not_found');
    }

    _records[current.auditId] = current.copyWith(
      status: status,
    );
  }

  static bool blockedImpersonationMustBeRecorded() => true;

  static bool ownerMustSeeAllImpersonationAttempts() => true;

  static bool repeatedAttemptsMustRemainTraceable() => true;

  static bool originalAttemptEvidenceMustRemainImmutable() => true;

  static bool reviewStatusMustRemainSeparateFromEvidence() => true;

  static bool futureIdentitySurfacesMustUseSameAuditLedger() => true;
}
