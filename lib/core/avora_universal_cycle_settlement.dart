import 'avora_reward_eligibility.dart';

enum AvoraUniversalSettlementModule {
  salary,
  event,
  cp,
  family,
  agency,
  bd,
  host,
  cs,
  staff,
  room,
  leaderboard,
  referral,
  invite,
  target,
  rechargeCampaign,
  game,
  other,
}

enum AvoraUniversalSettlementStatus {
  pendingFinalization,
  ineligible,
  readyForDispatch,
  pendingReview,
  settled,
  failedRetryable,
  reversed,
}

enum AvoraUniversalSettlementReason {
  none,
  invalidCycle,
  cycleNotClosed,
  rewardIneligible,
  invalidReward,
  alreadySettled,
  reviewRequired,
  automaticDispatchPrepared,
  dispatchSucceeded,
  dispatchFailedRetryable,
  reversed,
}

class AvoraUniversalCycleSnapshot {
  const AvoraUniversalCycleSnapshot({
    required this.cycleId,
    required this.module,
    required this.startAtUtc,
    required this.endAtUtc,
    required this.timeZoneId,
    required this.policyVersion,
    required this.countryCode,
  });

  final String cycleId;
  final AvoraUniversalSettlementModule module;

  /// Authoritative cycle boundaries are precomputed by backend/business-time
  /// policy and snapshotted as UTC instants.
  final DateTime startAtUtc;
  final DateTime endAtUtc;

  /// IANA zone used when this cycle was created, e.g. Asia/Riyadh.
  final String timeZoneId;

  /// Historical cycle always keeps the policy version it started with.
  final String policyVersion;

  final String countryCode;

  bool get valid =>
      cycleId.trim().isNotEmpty &&
      timeZoneId.trim().isNotEmpty &&
      policyVersion.trim().isNotEmpty &&
      startAtUtc.isUtc &&
      endAtUtc.isUtc &&
      endAtUtc.isAfter(startAtUtc);
}

class AvoraUniversalSettlementSubject {
  const AvoraUniversalSettlementSubject({
    required this.subjectId,
    required this.beneficiaryAvoraId,
    required this.beneficiaryEligibility,
    required this.eligibleMetricUnits,
    required this.rewardValueType,
    required this.rewardUnits,
    required this.destinationKey,
    required this.settlementAdapterKey,
  });

  /// Can be AVORA ID, family ID, agency ID, room ID, CP ID, etc.
  final String subjectId;

  /// Immutable AVORA ID that ultimately receives the entitlement/reward.
  final String beneficiaryAvoraId;

  /// Central reward eligibility gate is reused.
  final AvoraRewardEligibilityProfile beneficiaryEligibility;

  /// Already-finalized eligible metric snapshot from the source module.
  final int eligibleMetricUnits;

  /// Opaque downstream reward type, e.g. coins / salaryCoinEquivalent / frame.
  final String rewardValueType;
  final int rewardUnits;

  /// Opaque destination understood by the downstream settlement adapter.
  final String destinationKey;

  /// Routes to existing Salary/Gift/Event/etc. authoritative settlement logic.
  final String settlementAdapterKey;
}

class AvoraUniversalSettlementInstruction {
  const AvoraUniversalSettlementInstruction({
    required this.settlementKey,
    required this.cycleId,
    required this.module,
    required this.subjectId,
    required this.beneficiaryAvoraId,
    required this.policyVersion,
    required this.timeZoneId,
    required this.eligibleMetricUnits,
    required this.rewardValueType,
    required this.rewardUnits,
    required this.destinationKey,
    required this.settlementAdapterKey,
    required this.createdAtUtc,
  });

  final String settlementKey;
  final String cycleId;
  final AvoraUniversalSettlementModule module;
  final String subjectId;
  final String beneficiaryAvoraId;

  final String policyVersion;
  final String timeZoneId;

  final int eligibleMetricUnits;
  final String rewardValueType;
  final int rewardUnits;

  final String destinationKey;
  final String settlementAdapterKey;

  final DateTime createdAtUtc;
}

class AvoraUniversalSettlementRecord {
  const AvoraUniversalSettlementRecord({
    required this.settlementKey,
    required this.cycleId,
    required this.module,
    required this.subjectId,
    required this.beneficiaryAvoraId,
    required this.policyVersion,
    required this.status,
    required this.reason,
    required this.eligibleMetricUnits,
    required this.rewardValueType,
    required this.rewardUnits,
    required this.destinationKey,
    required this.updatedAtUtc,
    this.ledgerReferenceId,
  });

  final String settlementKey;
  final String cycleId;
  final AvoraUniversalSettlementModule module;

  final String subjectId;
  final String beneficiaryAvoraId;
  final String policyVersion;

  final AvoraUniversalSettlementStatus status;
  final AvoraUniversalSettlementReason reason;

  final int eligibleMetricUnits;
  final String rewardValueType;
  final int rewardUnits;
  final String destinationKey;

  final DateTime updatedAtUtc;
  final String? ledgerReferenceId;
}

class AvoraUniversalSettlementAuditEvent {
  const AvoraUniversalSettlementAuditEvent({
    required this.auditId,
    required this.settlementKey,
    required this.cycleId,
    required this.subjectId,
    required this.fromStatus,
    required this.toStatus,
    required this.reason,
    required this.occurredAtUtc,
  });

  final String auditId;
  final String settlementKey;
  final String cycleId;
  final String subjectId;

  final AvoraUniversalSettlementStatus fromStatus;
  final AvoraUniversalSettlementStatus toStatus;
  final AvoraUniversalSettlementReason reason;

  final DateTime occurredAtUtc;
}

class AvoraUniversalSettlementDecision {
  const AvoraUniversalSettlementDecision({
    required this.record,
    required this.auditEvent,
    this.instruction,
  });

  final AvoraUniversalSettlementRecord record;
  final AvoraUniversalSettlementAuditEvent auditEvent;
  final AvoraUniversalSettlementInstruction? instruction;
}

class AvoraUniversalCycleSettlementEngine {
  const AvoraUniversalCycleSettlementEngine._();

  static String settlementKey({
    required AvoraUniversalCycleSnapshot cycle,
    required AvoraUniversalSettlementSubject subject,
  }) =>
      '${cycle.module.name}:${cycle.cycleId}:'
      '${subject.subjectId}:${subject.beneficiaryAvoraId}:'
      '${cycle.policyVersion}';

  static AvoraUniversalSettlementDecision prepareAtCycleClose({
    required AvoraUniversalCycleSnapshot cycle,
    required AvoraUniversalSettlementSubject subject,
    required DateTime serverNowUtc,
    required Set<String> alreadySettledKeys,
    required String auditId,
    bool reviewRequired = false,
  }) {
    final key = settlementKey(cycle: cycle, subject: subject);

    AvoraUniversalSettlementDecision decision({
      required AvoraUniversalSettlementStatus status,
      required AvoraUniversalSettlementReason reason,
      AvoraUniversalSettlementInstruction? instruction,
    }) {
      return AvoraUniversalSettlementDecision(
        record: AvoraUniversalSettlementRecord(
          settlementKey: key,
          cycleId: cycle.cycleId,
          module: cycle.module,
          subjectId: subject.subjectId,
          beneficiaryAvoraId: subject.beneficiaryAvoraId,
          policyVersion: cycle.policyVersion,
          status: status,
          reason: reason,
          eligibleMetricUnits: subject.eligibleMetricUnits,
          rewardValueType: subject.rewardValueType,
          rewardUnits: subject.rewardUnits,
          destinationKey: subject.destinationKey,
          updatedAtUtc: serverNowUtc,
        ),
        auditEvent: AvoraUniversalSettlementAuditEvent(
          auditId: auditId,
          settlementKey: key,
          cycleId: cycle.cycleId,
          subjectId: subject.subjectId,
          fromStatus: AvoraUniversalSettlementStatus.pendingFinalization,
          toStatus: status,
          reason: reason,
          occurredAtUtc: serverNowUtc,
        ),
        instruction: instruction,
      );
    }

    if (!cycle.valid || !serverNowUtc.isUtc) {
      return decision(
        status: AvoraUniversalSettlementStatus.pendingReview,
        reason: AvoraUniversalSettlementReason.invalidCycle,
      );
    }

    if (serverNowUtc.isBefore(cycle.endAtUtc)) {
      return decision(
        status: AvoraUniversalSettlementStatus.pendingFinalization,
        reason: AvoraUniversalSettlementReason.cycleNotClosed,
      );
    }

    if (alreadySettledKeys.contains(key)) {
      return decision(
        status: AvoraUniversalSettlementStatus.settled,
        reason: AvoraUniversalSettlementReason.alreadySettled,
      );
    }

    if (!subject.beneficiaryEligibility.eligibleForRewards) {
      return decision(
        status: AvoraUniversalSettlementStatus.ineligible,
        reason: AvoraUniversalSettlementReason.rewardIneligible,
      );
    }

    if (subject.rewardUnits <= 0 ||
        subject.rewardValueType.trim().isEmpty ||
        subject.destinationKey.trim().isEmpty ||
        subject.settlementAdapterKey.trim().isEmpty) {
      return decision(
        status: AvoraUniversalSettlementStatus.ineligible,
        reason: AvoraUniversalSettlementReason.invalidReward,
      );
    }

    if (reviewRequired) {
      return decision(
        status: AvoraUniversalSettlementStatus.pendingReview,
        reason: AvoraUniversalSettlementReason.reviewRequired,
      );
    }

    final instruction = AvoraUniversalSettlementInstruction(
      settlementKey: key,
      cycleId: cycle.cycleId,
      module: cycle.module,
      subjectId: subject.subjectId,
      beneficiaryAvoraId: subject.beneficiaryAvoraId,
      policyVersion: cycle.policyVersion,
      timeZoneId: cycle.timeZoneId,
      eligibleMetricUnits: subject.eligibleMetricUnits,
      rewardValueType: subject.rewardValueType,
      rewardUnits: subject.rewardUnits,
      destinationKey: subject.destinationKey,
      settlementAdapterKey: subject.settlementAdapterKey,
      createdAtUtc: serverNowUtc,
    );

    return decision(
      status: AvoraUniversalSettlementStatus.readyForDispatch,
      reason: AvoraUniversalSettlementReason.automaticDispatchPrepared,
      instruction: instruction,
    );
  }

  static AvoraUniversalSettlementRecord recordDispatchResult({
    required AvoraUniversalSettlementRecord current,
    required DateTime serverNowUtc,
    required bool settled,
    required bool retryableFailure,
    required bool pendingReview,
    String? ledgerReferenceId,
  }) {
    if (settled) {
      return AvoraUniversalSettlementRecord(
        settlementKey: current.settlementKey,
        cycleId: current.cycleId,
        module: current.module,
        subjectId: current.subjectId,
        beneficiaryAvoraId: current.beneficiaryAvoraId,
        policyVersion: current.policyVersion,
        status: AvoraUniversalSettlementStatus.settled,
        reason: AvoraUniversalSettlementReason.dispatchSucceeded,
        eligibleMetricUnits: current.eligibleMetricUnits,
        rewardValueType: current.rewardValueType,
        rewardUnits: current.rewardUnits,
        destinationKey: current.destinationKey,
        updatedAtUtc: serverNowUtc,
        ledgerReferenceId: ledgerReferenceId,
      );
    }

    if (pendingReview) {
      return AvoraUniversalSettlementRecord(
        settlementKey: current.settlementKey,
        cycleId: current.cycleId,
        module: current.module,
        subjectId: current.subjectId,
        beneficiaryAvoraId: current.beneficiaryAvoraId,
        policyVersion: current.policyVersion,
        status: AvoraUniversalSettlementStatus.pendingReview,
        reason: AvoraUniversalSettlementReason.reviewRequired,
        eligibleMetricUnits: current.eligibleMetricUnits,
        rewardValueType: current.rewardValueType,
        rewardUnits: current.rewardUnits,
        destinationKey: current.destinationKey,
        updatedAtUtc: serverNowUtc,
        ledgerReferenceId: ledgerReferenceId,
      );
    }

    return AvoraUniversalSettlementRecord(
      settlementKey: current.settlementKey,
      cycleId: current.cycleId,
      module: current.module,
      subjectId: current.subjectId,
      beneficiaryAvoraId: current.beneficiaryAvoraId,
      policyVersion: current.policyVersion,
      status: retryableFailure
          ? AvoraUniversalSettlementStatus.failedRetryable
          : AvoraUniversalSettlementStatus.pendingReview,
      reason: retryableFailure
          ? AvoraUniversalSettlementReason.dispatchFailedRetryable
          : AvoraUniversalSettlementReason.reviewRequired,
      eligibleMetricUnits: current.eligibleMetricUnits,
      rewardValueType: current.rewardValueType,
      rewardUnits: current.rewardUnits,
      destinationKey: current.destinationKey,
      updatedAtUtc: serverNowUtc,
      ledgerReferenceId: ledgerReferenceId,
    );
  }

  /// The user never has to press Claim for normal earned-cycle settlement.
  static bool manualClaimRequired() => false;

  /// App being closed/offline must not prevent settlement.
  static bool userAppMustBeOpenForSettlement() => false;

  /// Client cannot finalize or directly credit a reward.
  static bool clientCanFinalizeSettlement() => false;

  /// Backend/server worker should dispatch as soon as cycle finalizes.
  static bool automaticBackendDispatchRequired() => true;

  /// Existing Salary/Gift/Event/etc. engines remain authoritative for
  /// calculation and actual ledger/wallet mutation.
  static bool downstreamModuleSettlementRemainsAuthoritative() => true;

  static bool supportsIdempotentRetry() => true;

  static bool historicalCyclePolicyCanBeRewritten() => false;
}
