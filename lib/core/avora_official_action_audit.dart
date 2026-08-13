enum AvoraOfficialActionType {
  roleGrant,
  roleRevoke,
  permissionGrant,
  permissionRevoke,
  userBan,
  userUnban,
  roomBan,
  roomUnban,
  roomKick,
  roomMute,
  roomManage,
  agencyManage,
  bdManage,
  hostManage,
  targetManage,
  rewardManage,
  reportResolve,
  policyChange,
  walletReview,
  manualCorrection,
  other,
}

class AvoraOfficialActionAuditRecord {
  const AvoraOfficialActionAuditRecord({
    required this.auditId,
    required this.actorAvoraId,
    required this.actorRole,
    required this.actorCountryCode,
    required this.targetId,
    required this.targetCountryCode,
    required this.actionType,
    required this.reason,
    required this.beforeState,
    required this.afterState,
    required this.createdAtUtc,
    required this.ownerVisible,
    required this.immutable,
  });

  final String auditId;

  final String actorAvoraId;
  final String actorRole;
  final String actorCountryCode;

  final String targetId;
  final String targetCountryCode;

  final AvoraOfficialActionType actionType;

  final String reason;

  final Map<String, Object?> beforeState;
  final Map<String, Object?> afterState;

  final DateTime createdAtUtc;

  final bool ownerVisible;
  final bool immutable;
}

class AvoraOfficialActionAuditLedger {
  final Map<String, AvoraOfficialActionAuditRecord> _records =
      <String, AvoraOfficialActionAuditRecord>{};

  void append(AvoraOfficialActionAuditRecord record) {
    if (record.auditId.trim().isEmpty ||
        record.actorAvoraId.trim().isEmpty ||
        record.actorRole.trim().isEmpty ||
        record.targetId.trim().isEmpty ||
        record.reason.trim().isEmpty) {
      throw ArgumentError('invalid_official_action_audit');
    }

    if (!record.immutable || !record.ownerVisible) {
      throw ArgumentError('official_audit_must_be_owner_visible_immutable');
    }

    if (_records.containsKey(record.auditId)) {
      throw StateError('duplicate_official_action_audit');
    }

    _records[record.auditId] = record;
  }

  List<AvoraOfficialActionAuditRecord> allForOwner() {
    return List<AvoraOfficialActionAuditRecord>.unmodifiable(
      _records.values,
    );
  }

  List<AvoraOfficialActionAuditRecord> byActor(
    String actorAvoraId,
  ) {
    return List<AvoraOfficialActionAuditRecord>.unmodifiable(
      _records.values.where(
        (record) => record.actorAvoraId == actorAvoraId,
      ),
    );
  }

  List<AvoraOfficialActionAuditRecord> byCountry(
    String countryCode,
  ) {
    final code = countryCode.trim().toUpperCase();

    return List<AvoraOfficialActionAuditRecord>.unmodifiable(
      _records.values.where(
        (record) =>
            record.actorCountryCode.toUpperCase() == code ||
            record.targetCountryCode.toUpperCase() == code,
      ),
    );
  }

  List<AvoraOfficialActionAuditRecord> byTarget(
    String targetId,
  ) {
    return List<AvoraOfficialActionAuditRecord>.unmodifiable(
      _records.values.where(
        (record) => record.targetId == targetId,
      ),
    );
  }

  static bool everyOfficialActionMustCreateAudit() => true;

  static bool auditMustIdentifyActorRoleAndCountry() => true;

  static bool auditMustPreserveBeforeAndAfterState() => true;

  static bool ownerMustSeeGlobalAuditHistory() => true;

  static bool ownerMustBeAbleToInvestigateAnyOfficial() => true;

  static bool auditHistoryMustNeverBeSilentlyDeleted() => true;

  static bool futureOfficialActionsMustUseSameLedger() => true;
}

class AvoraCountryAuthorityIsolation {
  const AvoraCountryAuthorityIsolation._();

  static bool mayManageTarget({
    required bool actorIsVerifiedOwner,
    required String actorCountryCode,
    required String targetCountryCode,
    required bool actorHasRequiredPermission,
  }) {
    if (actorIsVerifiedOwner) {
      return true;
    }

    if (!actorHasRequiredPermission) {
      return false;
    }

    final actorCountry = actorCountryCode.trim().toUpperCase();
    final targetCountry = targetCountryCode.trim().toUpperCase();

    if (actorCountry.isEmpty || targetCountry.isEmpty) {
      return false;
    }

    return actorCountry == targetCountry;
  }

  static bool countryManagerMustRemainCountryScoped() => true;

  static bool oneCountryManagerMustNotControlAnotherCountry() => true;

  static bool oneCountryTeamMustNotControlAnotherCountryTeam() => true;

  static bool countryIsolationMustApplyToFutureOfficialRoles() => true;

  static bool ownerMustRemainGlobalAboveCountryIsolation() => true;
}

class AvoraOwnerAuditCorrectionRecord {
  const AvoraOwnerAuditCorrectionRecord({
    required this.correctionId,
    required this.originalAuditId,
    required this.ownerAvoraId,
    required this.reason,
    required this.correctiveAction,
    required this.createdAtUtc,
  });

  final String correctionId;
  final String originalAuditId;
  final String ownerAvoraId;
  final String reason;
  final String correctiveAction;
  final DateTime createdAtUtc;
}

class AvoraOwnerAuditCorrectionLedger {
  final Map<String, AvoraOwnerAuditCorrectionRecord> _corrections =
      <String, AvoraOwnerAuditCorrectionRecord>{};

  void append(AvoraOwnerAuditCorrectionRecord record) {
    if (record.correctionId.trim().isEmpty ||
        record.originalAuditId.trim().isEmpty ||
        record.ownerAvoraId.trim().isEmpty ||
        record.reason.trim().isEmpty ||
        record.correctiveAction.trim().isEmpty) {
      throw ArgumentError('invalid_owner_audit_correction');
    }

    if (_corrections.containsKey(record.correctionId)) {
      throw StateError('duplicate_owner_audit_correction');
    }

    _corrections[record.correctionId] = record;
  }

  List<AvoraOwnerAuditCorrectionRecord> forOriginalAudit(
    String auditId,
  ) {
    return List<AvoraOwnerAuditCorrectionRecord>.unmodifiable(
      _corrections.values.where(
        (record) => record.originalAuditId == auditId,
      ),
    );
  }

  static bool ownerCorrectionMustNotRewriteOriginalAudit() => true;

  static bool correctionMustCreateNewAuditEvidence() => true;

  static bool ownerMustBeAbleToCorrectOfficialMisuse() => true;

  static bool ownerMustBeAbleToRevokeMisusedAuthority() => true;

  static bool futureCorrectionsMustRemainTraceable() => true;
}
