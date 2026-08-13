enum AvoraOwnerInspectionReason {
  userReport,
  promotionAbuse,
  safetyReview,
  fraudReview,
  policyReview,
  other,
}

class AvoraOwnerRoomInspectionRequest {
  const AvoraOwnerRoomInspectionRequest({
    required this.ownerAvoraId,
    required this.roomId,
    required this.reason,
    required this.createdAtUtc,
    required this.ownerIsVerified,
  });

  final String ownerAvoraId;
  final String roomId;
  final AvoraOwnerInspectionReason reason;
  final DateTime createdAtUtc;
  final bool ownerIsVerified;
}

class AvoraOwnerRoomInspectionDecision {
  const AvoraOwnerRoomInspectionDecision({
    required this.allowed,
    required this.reason,
    required this.mayBypassRoomLock,
    required this.mayReadPlaintextPassword,
    required this.auditRequired,
  });

  final bool allowed;
  final String reason;
  final bool mayBypassRoomLock;
  final bool mayReadPlaintextPassword;
  final bool auditRequired;
}

class AvoraOwnerRoomInspectionPolicy {
  const AvoraOwnerRoomInspectionPolicy._();

  static AvoraOwnerRoomInspectionDecision evaluate(
    AvoraOwnerRoomInspectionRequest request,
  ) {
    if (!request.ownerIsVerified ||
        request.ownerAvoraId.trim().isEmpty ||
        request.roomId.trim().isEmpty) {
      return const AvoraOwnerRoomInspectionDecision(
        allowed: false,
        reason: 'verified_owner_required',
        mayBypassRoomLock: false,
        mayReadPlaintextPassword: false,
        auditRequired: true,
      );
    }

    return const AvoraOwnerRoomInspectionDecision(
      allowed: true,
      reason: 'owner_inspection_authorized',
      mayBypassRoomLock: true,
      mayReadPlaintextPassword: false,
      auditRequired: true,
    );
  }

  static bool ownerMayInspectAnyCountryRoom() => true;

  static bool ownerMayBypassRoomLockWithoutPassword() => true;

  static bool plaintextRoomPasswordMustNeverBeExposed() => true;

  static bool inspectionMustBeAudited() => true;

  static bool inspectionMustRespectPrivacyAndLegalPolicy() => true;

  static bool inspectionMustNotBecomeCovertRecordingByDefault() => true;

  static bool futureRoomTypesMustUseSameInspectionPolicy() => true;
}

class AvoraOwnerRoomInspectionAudit {
  const AvoraOwnerRoomInspectionAudit({
    required this.auditId,
    required this.ownerAvoraId,
    required this.roomId,
    required this.reason,
    required this.createdAtUtc,
  });

  final String auditId;
  final String ownerAvoraId;
  final String roomId;
  final AvoraOwnerInspectionReason reason;
  final DateTime createdAtUtc;
}
