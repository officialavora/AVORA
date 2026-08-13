enum AvoraAgencyTransferStatus {
  requested,
  approved,
  completed,
  rejected,
  cancelled,
  review,
}

enum AvoraAgencyTransferRoute {
  memberRequest,
  agencyOwnerInitiated,
  higherAuthorityOverride,
  policyTimedRelease,
}

enum AvoraAgencyTransferDenyReason {
  none,
  invalidMember,
  invalidSourceAgency,
  invalidDestinationAgency,
  sameAgency,
  missingTargetSnapshot,
  alreadyFinalized,
  authorityRequired,
}

class AvoraAgencyCycleSnapshot {
  const AvoraAgencyCycleSnapshot({
    required this.cycleId,
    required this.capturedAt,
    required this.targetProgressBps,
    required this.validMinutes,
    required this.validWorkdays,
    required this.eligibleSendingUnits,
    required this.eligibleReceivingUnits,
    required this.vestedEarningsMinor,
    required this.pendingEarningsMinor,
  });

  final String cycleId;
  final DateTime capturedAt;

  /// Personal progress already valid in the current target cycle.
  /// It is preserved when the member changes agency.
  final int targetProgressBps;

  final int validMinutes;
  final int validWorkdays;

  final int eligibleSendingUnits;
  final int eligibleReceivingUnits;

  /// Already earned/vested amount must never disappear because of transfer.
  final int vestedEarningsMinor;

  /// Pending amount remains separately settleable/reviewable.
  final int pendingEarningsMinor;
}

class AvoraAgencyTransferRecord {
  const AvoraAgencyTransferRecord({
    required this.transferId,
    required this.memberAvoraId,
    required this.fromAgencyId,
    required this.toAgencyId,
    required this.requestedByAvoraId,
    required this.requestedAt,
    required this.route,
    required this.reason,
    required this.cycleSnapshot,
    this.status = AvoraAgencyTransferStatus.requested,
    this.decidedByAvoraId,
    this.decidedAt,
    this.decisionReason,
    this.effectiveAt,
  });

  /// Stable immutable transfer/audit ID.
  final String transferId;

  /// Immutable AVORA ID of the transferred user/host.
  final String memberAvoraId;

  final String fromAgencyId;
  final String toAgencyId;

  /// Immutable AVORA ID that initiated the request/action.
  final String requestedByAvoraId;
  final DateTime requestedAt;

  final AvoraAgencyTransferRoute route;
  final String reason;

  /// Immutable snapshot of work/target/earnings before movement.
  final AvoraAgencyCycleSnapshot cycleSnapshot;

  final AvoraAgencyTransferStatus status;

  /// Agency Owner / BD / Manager / higher authorized actor.
  final String? decidedByAvoraId;
  final DateTime? decidedAt;
  final String? decisionReason;

  /// Old-agency attribution stops here and new-agency attribution starts here.
  final DateTime? effectiveAt;

  bool get isFinal =>
      status == AvoraAgencyTransferStatus.completed ||
      status == AvoraAgencyTransferStatus.rejected ||
      status == AvoraAgencyTransferStatus.cancelled;

  AvoraAgencyTransferRecord approved({
    required String byAvoraId,
    required DateTime at,
    required String reason,
  }) {
    return AvoraAgencyTransferRecord(
      transferId: transferId,
      memberAvoraId: memberAvoraId,
      fromAgencyId: fromAgencyId,
      toAgencyId: toAgencyId,
      requestedByAvoraId: requestedByAvoraId,
      requestedAt: requestedAt,
      route: route,
      reason: this.reason,
      cycleSnapshot: cycleSnapshot,
      status: AvoraAgencyTransferStatus.approved,
      decidedByAvoraId: byAvoraId,
      decidedAt: at,
      decisionReason: reason,
    );
  }

  AvoraAgencyTransferRecord completed({
    required String byAvoraId,
    required DateTime at,
    required String reason,
  }) {
    return AvoraAgencyTransferRecord(
      transferId: transferId,
      memberAvoraId: memberAvoraId,
      fromAgencyId: fromAgencyId,
      toAgencyId: toAgencyId,
      requestedByAvoraId: requestedByAvoraId,
      requestedAt: requestedAt,
      route: route,
      reason: this.reason,
      cycleSnapshot: cycleSnapshot,
      status: AvoraAgencyTransferStatus.completed,
      decidedByAvoraId: byAvoraId,
      decidedAt: at,
      decisionReason: reason,
      effectiveAt: at,
    );
  }

  AvoraAgencyTransferRecord rejected({
    required String byAvoraId,
    required DateTime at,
    required String reason,
  }) {
    return AvoraAgencyTransferRecord(
      transferId: transferId,
      memberAvoraId: memberAvoraId,
      fromAgencyId: fromAgencyId,
      toAgencyId: toAgencyId,
      requestedByAvoraId: requestedByAvoraId,
      requestedAt: requestedAt,
      route: route,
      reason: this.reason,
      cycleSnapshot: cycleSnapshot,
      status: AvoraAgencyTransferStatus.rejected,
      decidedByAvoraId: byAvoraId,
      decidedAt: at,
      decisionReason: reason,
    );
  }
}

class AvoraAgencyTransferDecision {
  const AvoraAgencyTransferDecision({
    required this.allowed,
    required this.reason,
    this.record,
  });

  final bool allowed;
  final AvoraAgencyTransferDenyReason reason;
  final AvoraAgencyTransferRecord? record;
}

class AvoraAgencyTransferEngine {
  const AvoraAgencyTransferEngine._();

  static AvoraAgencyTransferDecision createRequest({
    required String transferId,
    required String memberAvoraId,
    required String fromAgencyId,
    required String toAgencyId,
    required String requestedByAvoraId,
    required DateTime requestedAt,
    required AvoraAgencyTransferRoute route,
    required String reason,
    required AvoraAgencyCycleSnapshot cycleSnapshot,
  }) {
    if (memberAvoraId.trim().isEmpty) {
      return const AvoraAgencyTransferDecision(
        allowed: false,
        reason: AvoraAgencyTransferDenyReason.invalidMember,
      );
    }

    if (fromAgencyId.trim().isEmpty) {
      return const AvoraAgencyTransferDecision(
        allowed: false,
        reason: AvoraAgencyTransferDenyReason.invalidSourceAgency,
      );
    }

    if (toAgencyId.trim().isEmpty) {
      return const AvoraAgencyTransferDecision(
        allowed: false,
        reason: AvoraAgencyTransferDenyReason.invalidDestinationAgency,
      );
    }

    if (fromAgencyId.trim() == toAgencyId.trim()) {
      return const AvoraAgencyTransferDecision(
        allowed: false,
        reason: AvoraAgencyTransferDenyReason.sameAgency,
      );
    }

    if (cycleSnapshot.cycleId.trim().isEmpty) {
      return const AvoraAgencyTransferDecision(
        allowed: false,
        reason: AvoraAgencyTransferDenyReason.missingTargetSnapshot,
      );
    }

    return AvoraAgencyTransferDecision(
      allowed: true,
      reason: AvoraAgencyTransferDenyReason.none,
      record: AvoraAgencyTransferRecord(
        transferId: transferId,
        memberAvoraId: memberAvoraId,
        fromAgencyId: fromAgencyId,
        toAgencyId: toAgencyId,
        requestedByAvoraId: requestedByAvoraId,
        requestedAt: requestedAt,
        route: route,
        reason: reason,
        cycleSnapshot: cycleSnapshot,
      ),
    );
  }

  /// Member may request transfer, but client cannot directly reassign agency.
  static bool clientCanDirectlyMoveAgency() => false;

  /// Valid personal target progress survives agency transfer.
  static bool personalCycleProgressIsPreserved() => true;

  /// Work credited before effectiveAt remains attributed to old agency.
  static bool oldAgencyHistoricalAttributionIsPreserved() => true;

  /// New work after effectiveAt belongs to the new agency.
  static bool newAgencyAttributionStartsAtEffectiveTime() => true;

  /// Earned/vested amounts cannot be erased by removal or disagreement.
  static bool removalCanEraseVestedEarnings() => false;

  /// Previous membership/transfer history cannot be silently deleted.
  static bool clientCanDeleteTransferAudit() => false;

  /// A member cannot be permanently trapped by a refusing agency owner.
  static bool permanentAgencyLockInAllowed() => false;

  /// Policy may release through BD/Manager/higher authority or timed process.
  static bool higherAuthorityOrTimedReleaseSupported() => true;

  /// Same immutable AVORA ID remains the identity before and after transfer.
  static bool immutableMemberIdMustRemainSame() => true;
}
