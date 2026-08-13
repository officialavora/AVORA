enum AvoraInspectionCapability {
  viewEvidenceTimeline,
  reviewReports,
  inspectLockedRoom,
  reviewModerationSignals,
  reviewPromotionEvidence,
  reviewContactContent,
}

class AvoraDelegatedInspectionGrant {
  const AvoraDelegatedInspectionGrant({
    required this.grantId,
    required this.officialAvoraId,
    required this.capability,
    required this.countryCodes,
    required this.grantedByOwnerAvoraId,
    required this.reason,
    required this.startedAtUtc,
    this.expiresAtUtc,
    this.revokedAtUtc,
    this.revokedByOwnerAvoraId,
  });

  final String grantId;
  final String officialAvoraId;
  final AvoraInspectionCapability capability;

  final Set<String> countryCodes;

  final String grantedByOwnerAvoraId;
  final String reason;

  final DateTime startedAtUtc;
  final DateTime? expiresAtUtc;

  final DateTime? revokedAtUtc;
  final String? revokedByOwnerAvoraId;

  bool isActiveAt(DateTime nowUtc) {
    if (revokedAtUtc != null) {
      return false;
    }

    final expiry = expiresAtUtc;

    if (expiry != null && !nowUtc.toUtc().isBefore(expiry.toUtc())) {
      return false;
    }

    return !nowUtc.toUtc().isBefore(startedAtUtc.toUtc());
  }

  bool coversCountry(String countryCode) {
    final code = countryCode.trim().toUpperCase();

    return countryCodes.contains('*') || countryCodes.contains(code);
  }

  AvoraDelegatedInspectionGrant revoke({
    required String ownerAvoraId,
    required DateTime revokedAtUtc,
  }) {
    if (ownerAvoraId.trim().isEmpty) {
      throw ArgumentError('owner_revoke_identity_required');
    }

    return AvoraDelegatedInspectionGrant(
      grantId: grantId,
      officialAvoraId: officialAvoraId,
      capability: capability,
      countryCodes: countryCodes,
      grantedByOwnerAvoraId: grantedByOwnerAvoraId,
      reason: reason,
      startedAtUtc: startedAtUtc,
      expiresAtUtc: expiresAtUtc,
      revokedAtUtc: revokedAtUtc.toUtc(),
      revokedByOwnerAvoraId: ownerAvoraId,
    );
  }
}

enum AvoraInspectionGrantAuditType {
  grant,
  revoke,
}

class AvoraInspectionGrantAuditRecord {
  const AvoraInspectionGrantAuditRecord({
    required this.auditId,
    required this.grantId,
    required this.officialAvoraId,
    required this.capability,
    required this.type,
    required this.actorOwnerAvoraId,
    required this.reason,
    required this.createdAtUtc,
  });

  final String auditId;
  final String grantId;
  final String officialAvoraId;
  final AvoraInspectionCapability capability;
  final AvoraInspectionGrantAuditType type;
  final String actorOwnerAvoraId;
  final String reason;
  final DateTime createdAtUtc;
}

class AvoraDelegatedInspectionCapabilityEngine {
  final Map<String, AvoraDelegatedInspectionGrant> _grants =
      <String, AvoraDelegatedInspectionGrant>{};

  final List<AvoraInspectionGrantAuditRecord> _audit =
      <AvoraInspectionGrantAuditRecord>[];

  void grant({
    required String auditId,
    required AvoraDelegatedInspectionGrant grant,
  }) {
    if (auditId.trim().isEmpty ||
        grant.grantId.trim().isEmpty ||
        grant.officialAvoraId.trim().isEmpty ||
        grant.grantedByOwnerAvoraId.trim().isEmpty ||
        grant.reason.trim().isEmpty ||
        grant.countryCodes.isEmpty) {
      throw ArgumentError('invalid_inspection_grant');
    }

    if (_grants.containsKey(grant.grantId)) {
      throw StateError('duplicate_inspection_grant');
    }

    if (_audit.any((item) => item.auditId == auditId)) {
      throw StateError('duplicate_inspection_grant_audit');
    }

    _grants[grant.grantId] = grant;

    _audit.add(
      AvoraInspectionGrantAuditRecord(
        auditId: auditId,
        grantId: grant.grantId,
        officialAvoraId: grant.officialAvoraId,
        capability: grant.capability,
        type: AvoraInspectionGrantAuditType.grant,
        actorOwnerAvoraId: grant.grantedByOwnerAvoraId,
        reason: grant.reason,
        createdAtUtc: grant.startedAtUtc.toUtc(),
      ),
    );
  }

  void revoke({
    required String auditId,
    required String grantId,
    required String ownerAvoraId,
    required String reason,
    required DateTime revokedAtUtc,
  }) {
    final current = _grants[grantId];

    if (current == null) {
      throw StateError('inspection_grant_not_found');
    }

    if (current.revokedAtUtc != null) {
      throw StateError('inspection_grant_already_revoked');
    }

    if (auditId.trim().isEmpty ||
        ownerAvoraId.trim().isEmpty ||
        reason.trim().isEmpty) {
      throw ArgumentError('invalid_inspection_revoke');
    }

    if (_audit.any((item) => item.auditId == auditId)) {
      throw StateError('duplicate_inspection_grant_audit');
    }

    _grants[grantId] = current.revoke(
      ownerAvoraId: ownerAvoraId,
      revokedAtUtc: revokedAtUtc,
    );

    _audit.add(
      AvoraInspectionGrantAuditRecord(
        auditId: auditId,
        grantId: current.grantId,
        officialAvoraId: current.officialAvoraId,
        capability: current.capability,
        type: AvoraInspectionGrantAuditType.revoke,
        actorOwnerAvoraId: ownerAvoraId,
        reason: reason,
        createdAtUtc: revokedAtUtc.toUtc(),
      ),
    );
  }

  bool isAllowed({
    required String officialAvoraId,
    required AvoraInspectionCapability capability,
    required String countryCode,
    required DateTime nowUtc,
  }) {
    return _grants.values.any(
      (grant) =>
          grant.officialAvoraId == officialAvoraId &&
          grant.capability == capability &&
          grant.isActiveAt(nowUtc) &&
          grant.coversCountry(countryCode),
    );
  }

  List<AvoraInspectionGrantAuditRecord> get auditHistory =>
      List<AvoraInspectionGrantAuditRecord>.unmodifiable(
        _audit,
      );

  static bool ownerMayDelegateInspectionCapabilities() => true;

  static bool delegationMustBeGranular() => true;

  static bool delegationMayBeCountryScoped() => true;

  static bool delegationMayExpireAutomatically() => true;

  static bool ownerMayRevokeAnyDelegatedCapability() => true;

  static bool delegatedOfficialMustNotSeePlaintextPassword() => true;

  static bool delegatedInspectionMustNotEnableCovertRecordingByDefault() =>
      true;

  static bool everyGrantAndRevokeMustBeAudited() => true;

  static bool crossCountryAccessMustRequireExplicitScope() => true;

  static bool futureInspectionCapabilitiesMustUseSameEngine() => true;
}
