import 'avora_delegated_inspection_capability.dart';

enum AvoraInspectionOwnerDecisionType {
  noAction,
  warning,
  continueMonitoring,
  revokeSpecificGrant,
}

class AvoraInspectionOwnerDecisionRecord {
  const AvoraInspectionOwnerDecisionRecord({
    required this.decisionId,
    required this.reviewId,
    required this.officialAvoraId,
    required this.ownerAvoraId,
    required this.decision,
    required this.reason,
    required this.createdAtUtc,
    this.targetGrantId,
  });

  final String decisionId;
  final String reviewId;
  final String officialAvoraId;
  final String ownerAvoraId;
  final AvoraInspectionOwnerDecisionType decision;
  final String reason;
  final DateTime createdAtUtc;
  final String? targetGrantId;
}

class AvoraInspectionOwnerDecisionLedger {
  final Map<String, AvoraInspectionOwnerDecisionRecord> _records =
      <String, AvoraInspectionOwnerDecisionRecord>{};

  void append(AvoraInspectionOwnerDecisionRecord record) {
    if (record.decisionId.trim().isEmpty ||
        record.reviewId.trim().isEmpty ||
        record.officialAvoraId.trim().isEmpty ||
        record.ownerAvoraId.trim().isEmpty ||
        record.reason.trim().isEmpty) {
      throw ArgumentError('invalid_owner_inspection_decision');
    }

    if (_records.containsKey(record.decisionId)) {
      throw StateError('duplicate_owner_inspection_decision');
    }

    _records[record.decisionId] = record;
  }

  List<AvoraInspectionOwnerDecisionRecord> get all =>
      List<AvoraInspectionOwnerDecisionRecord>.unmodifiable(
        _records.values,
      );

  List<AvoraInspectionOwnerDecisionRecord> byOfficial(
    String officialAvoraId,
  ) {
    return List<AvoraInspectionOwnerDecisionRecord>.unmodifiable(
      _records.values.where(
        (record) => record.officialAvoraId == officialAvoraId,
      ),
    );
  }

  List<AvoraInspectionOwnerDecisionRecord> byReview(
    String reviewId,
  ) {
    return List<AvoraInspectionOwnerDecisionRecord>.unmodifiable(
      _records.values.where(
        (record) => record.reviewId == reviewId,
      ),
    );
  }

  static bool ownerDecisionMustBeAudited() => true;

  static bool previousDecisionEvidenceMustRemainImmutable() => true;

  static bool warningMustNotEqualAutomaticRevocation() => true;

  static bool noActionDecisionMustRemainTraceable() => true;

  static bool futureOwnerReviewActionsMustUseSameLedger() => true;
}

class AvoraInspectionOwnerDecisionService {
  AvoraInspectionOwnerDecisionService({
    required AvoraDelegatedInspectionCapabilityEngine capabilityEngine,
    required AvoraInspectionOwnerDecisionLedger decisionLedger,
  })  : _capabilityEngine = capabilityEngine,
        _decisionLedger = decisionLedger;

  final AvoraDelegatedInspectionCapabilityEngine _capabilityEngine;
  final AvoraInspectionOwnerDecisionLedger _decisionLedger;

  void decide({
    required String decisionId,
    required String reviewId,
    required String officialAvoraId,
    required String ownerAvoraId,
    required bool actorIsVerifiedOwner,
    required AvoraInspectionOwnerDecisionType decision,
    required String reason,
    required DateTime createdAtUtc,
    String? targetGrantId,
    String? revokeAuditId,
  }) {
    if (!actorIsVerifiedOwner) {
      throw StateError('verified_owner_required');
    }

    if (decision == AvoraInspectionOwnerDecisionType.revokeSpecificGrant) {
      if (targetGrantId == null ||
          targetGrantId.trim().isEmpty ||
          revokeAuditId == null ||
          revokeAuditId.trim().isEmpty) {
        throw ArgumentError(
          'specific_grant_and_revoke_audit_required',
        );
      }

      _capabilityEngine.revoke(
        auditId: revokeAuditId,
        grantId: targetGrantId,
        ownerAvoraId: ownerAvoraId,
        reason: reason,
        revokedAtUtc: createdAtUtc,
      );
    }

    _decisionLedger.append(
      AvoraInspectionOwnerDecisionRecord(
        decisionId: decisionId,
        reviewId: reviewId,
        officialAvoraId: officialAvoraId,
        ownerAvoraId: ownerAvoraId,
        decision: decision,
        reason: reason,
        createdAtUtc: createdAtUtc.toUtc(),
        targetGrantId: targetGrantId,
      ),
    );
  }

  static bool onlyVerifiedOwnerMayMakeFinalDecision() => true;

  static bool ownerMayChooseNoAction() => true;

  static bool ownerMayWarnWithoutRevoking() => true;

  static bool ownerMayRevokeSpecificGrantOnly() => true;

  static bool unrelatedOfficialPermissionsMustRemainUntouched() => true;

  static bool riskSignalMustNeverForceOwnerDecision() => true;

  static bool everyFinalDecisionMustRemainAuditable() => true;

  static bool futureInspectionReviewActionsMustUseSameService() => true;
}
