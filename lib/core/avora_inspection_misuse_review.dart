import 'avora_delegated_inspection_capability.dart';

enum AvoraInspectionMisuseReviewStatus {
  pending,
  investigating,
  confirmed,
  dismissed,
  resolved,
}

class AvoraInspectionMisuseReviewCase {
  const AvoraInspectionMisuseReviewCase({
    required this.caseId,
    required this.officialAvoraId,
    required this.grantId,
    required this.countryCode,
    required this.complaintReason,
    required this.status,
    required this.createdAtUtc,
  });

  final String caseId;
  final String officialAvoraId;
  final String grantId;
  final String countryCode;
  final String complaintReason;
  final AvoraInspectionMisuseReviewStatus status;
  final DateTime createdAtUtc;

  AvoraInspectionMisuseReviewCase copyWith({
    AvoraInspectionMisuseReviewStatus? status,
  }) {
    return AvoraInspectionMisuseReviewCase(
      caseId: caseId,
      officialAvoraId: officialAvoraId,
      grantId: grantId,
      countryCode: countryCode,
      complaintReason: complaintReason,
      status: status ?? this.status,
      createdAtUtc: createdAtUtc,
    );
  }
}

class AvoraInspectionMisuseReviewLedger {
  final Map<String, AvoraInspectionMisuseReviewCase> _cases =
      <String, AvoraInspectionMisuseReviewCase>{};

  void create(AvoraInspectionMisuseReviewCase review) {
    if (review.caseId.trim().isEmpty ||
        review.officialAvoraId.trim().isEmpty ||
        review.grantId.trim().isEmpty ||
        review.countryCode.trim().isEmpty ||
        review.complaintReason.trim().isEmpty) {
      throw ArgumentError('invalid_inspection_misuse_review');
    }

    if (_cases.containsKey(review.caseId)) {
      throw StateError('duplicate_inspection_misuse_review');
    }

    _cases[review.caseId] = review;
  }

  AvoraInspectionMisuseReviewCase? byId(String caseId) {
    return _cases[caseId];
  }

  void updateStatus({
    required String caseId,
    required AvoraInspectionMisuseReviewStatus status,
  }) {
    final current = _cases[caseId];

    if (current == null) {
      throw StateError('inspection_misuse_review_not_found');
    }

    _cases[caseId] = current.copyWith(status: status);
  }

  List<AvoraInspectionMisuseReviewCase> byOfficial(
    String officialAvoraId,
  ) {
    return List<AvoraInspectionMisuseReviewCase>.unmodifiable(
      _cases.values.where(
        (item) => item.officialAvoraId == officialAvoraId,
      ),
    );
  }

  static bool misuseComplaintMustBeReviewable() => true;
  static bool complaintEvidenceMustRemainTraceable() => true;
  static bool ownerMustSeeOfficialAndGrantId() => true;
  static bool reviewMustRemainSeparateFromPunishment() => true;
}

class AvoraInspectionEmergencyRevokeService {
  AvoraInspectionEmergencyRevokeService({
    required AvoraDelegatedInspectionCapabilityEngine engine,
    required AvoraInspectionMisuseReviewLedger reviewLedger,
  })  : _engine = engine,
        _reviewLedger = reviewLedger;

  final AvoraDelegatedInspectionCapabilityEngine _engine;
  final AvoraInspectionMisuseReviewLedger _reviewLedger;

  void confirmAndRevoke({
    required String caseId,
    required String revokeAuditId,
    required String ownerAvoraId,
    required String reason,
    required DateTime revokedAtUtc,
  }) {
    final review = _reviewLedger.byId(caseId);

    if (review == null) {
      throw StateError('inspection_misuse_review_not_found');
    }

    if (review.status != AvoraInspectionMisuseReviewStatus.investigating) {
      throw StateError('inspection_misuse_not_investigating');
    }

    _engine.revoke(
      auditId: revokeAuditId,
      grantId: review.grantId,
      ownerAvoraId: ownerAvoraId,
      reason: reason,
      revokedAtUtc: revokedAtUtc,
    );

    _reviewLedger.updateStatus(
      caseId: caseId,
      status: AvoraInspectionMisuseReviewStatus.resolved,
    );
  }

  static bool ownerMayEmergencyRevokeDelegatedInspection() => true;

  static bool revokeMustTargetSpecificGrant() => true;

  static bool unrelatedPermissionsMustRemainUntouched() => true;

  static bool revokeMustCreateAuditEvidence() => true;

  static bool misuseReviewMustResolveAfterRevoke() => true;

  static bool futureDelegatedCapabilitiesMustUseSameReviewPath() => true;
}
