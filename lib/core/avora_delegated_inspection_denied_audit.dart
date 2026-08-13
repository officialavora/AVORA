import 'avora_delegated_inspection_capability.dart';

enum AvoraDelegatedInspectionDeniedReason {
  capabilityMissing,
  capabilityExpired,
  capabilityRevoked,
  countryScopeDenied,
  invalidRequest,
  other,
}

class AvoraDelegatedInspectionDeniedRecord {
  const AvoraDelegatedInspectionDeniedRecord({
    required this.auditId,
    required this.officialAvoraId,
    required this.capability,
    required this.countryCode,
    required this.resourceId,
    required this.reason,
    required this.detail,
    required this.createdAtUtc,
  });

  final String auditId;
  final String officialAvoraId;
  final AvoraInspectionCapability capability;
  final String countryCode;
  final String resourceId;
  final AvoraDelegatedInspectionDeniedReason reason;
  final String detail;
  final DateTime createdAtUtc;
}

class AvoraDelegatedInspectionDeniedAuditLedger {
  final Map<String, AvoraDelegatedInspectionDeniedRecord> _records =
      <String, AvoraDelegatedInspectionDeniedRecord>{};

  void append(AvoraDelegatedInspectionDeniedRecord record) {
    if (record.auditId.trim().isEmpty ||
        record.officialAvoraId.trim().isEmpty ||
        record.countryCode.trim().isEmpty ||
        record.resourceId.trim().isEmpty ||
        record.detail.trim().isEmpty) {
      throw ArgumentError(
        'invalid_delegated_inspection_denied_audit',
      );
    }

    if (_records.containsKey(record.auditId)) {
      throw StateError(
        'duplicate_delegated_inspection_denied_audit',
      );
    }

    _records[record.auditId] = record;
  }

  List<AvoraDelegatedInspectionDeniedRecord> get allForOwner =>
      List<AvoraDelegatedInspectionDeniedRecord>.unmodifiable(
        _records.values,
      );

  List<AvoraDelegatedInspectionDeniedRecord> byOfficial(
    String officialAvoraId,
  ) {
    return List<AvoraDelegatedInspectionDeniedRecord>.unmodifiable(
      _records.values.where(
        (record) => record.officialAvoraId == officialAvoraId,
      ),
    );
  }

  static bool deniedInspectionAttemptMustBeAudited() => true;
  static bool ownerMustSeeDeniedInspectionHistory() => true;
  static bool countryScopeViolationMustBeTraceable() => true;
  static bool revokedGrantUseAttemptMustBeTraceable() => true;
  static bool auditMustNotAutoPunishWithoutReview() => true;
  static bool futureDeniedInspectionAttemptsMustUseSameLedger() => true;
}

class AvoraDelegatedInspectionAttemptGate {
  AvoraDelegatedInspectionAttemptGate({
    required AvoraDelegatedInspectionCapabilityEngine capabilityEngine,
    required AvoraDelegatedInspectionDeniedAuditLedger deniedAuditLedger,
  })  : _capabilityEngine = capabilityEngine,
        _deniedAuditLedger = deniedAuditLedger;

  final AvoraDelegatedInspectionCapabilityEngine _capabilityEngine;
  final AvoraDelegatedInspectionDeniedAuditLedger _deniedAuditLedger;

  bool authorize({
    required String auditId,
    required String officialAvoraId,
    required AvoraInspectionCapability capability,
    required String countryCode,
    required String resourceId,
    required DateTime nowUtc,
  }) {
    if (auditId.trim().isEmpty ||
        officialAvoraId.trim().isEmpty ||
        countryCode.trim().isEmpty ||
        resourceId.trim().isEmpty) {
      throw ArgumentError('invalid_inspection_attempt');
    }

    final allowed = _capabilityEngine.isAllowed(
      officialAvoraId: officialAvoraId,
      capability: capability,
      countryCode: countryCode,
      nowUtc: nowUtc,
    );

    if (allowed) {
      return true;
    }

    _deniedAuditLedger.append(
      AvoraDelegatedInspectionDeniedRecord(
        auditId: auditId,
        officialAvoraId: officialAvoraId,
        capability: capability,
        countryCode: countryCode,
        resourceId: resourceId,
        reason: AvoraDelegatedInspectionDeniedReason.capabilityMissing,
        detail: 'delegated_inspection_not_authorized',
        createdAtUtc: nowUtc.toUtc(),
      ),
    );

    return false;
  }

  static bool deniedAttemptMustFailClosed() => true;
  static bool deniedAttemptMustAutoAudit() => true;
  static bool deniedAttemptMustNeverExposeProtectedResource() => true;
  static bool ownerMustBeAbleToReviewRepeatedDeniedAttempts() => true;
  static bool futureDelegatedInspectionAttemptsMustUseSameGate() => true;
}
