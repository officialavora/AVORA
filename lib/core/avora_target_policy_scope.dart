import 'avora_target_program.dart';

enum AvoraTargetPolicyScopeType {
  global,
  country,
  region,
}

enum AvoraTargetPolicyAssignmentStatus {
  active,
  paused,
  revoked,
}

enum AvoraCompensationStackingPolicy {
  /// AVORA default:
  /// the same economic units cannot be paid twice.
  exclusiveEconomicValue,

  /// Only for programs deliberately configured to stack
  /// genuinely separate benefits.
  explicitStackingAllowed,
}

enum AvoraEconomicRewardFamily {
  immediateReceiverReward,
  targetSalary,
  roomReward,
  hostReward,
  agencyReward,
  bdReward,
  eventReward,
  custom,
}

class AvoraTargetPolicyAssignment {
  final String id;

  /// Logical policy family such as:
  /// host_salary, room_reward, id_target.
  final String policyKey;

  final String programId;

  final AvoraTargetPolicyScopeType scopeType;

  /// Required for country scope.
  final String? countryCode;

  /// Optional future region identifier.
  final String? regionCode;

  /// Manager/staff assignment responsible for this config.
  final String? managerUserId;

  final AvoraTargetPolicyAssignmentStatus status;

  final AvoraCompensationStackingPolicy stackingPolicy;

  final DateTime effectiveFrom;

  final DateTime? effectiveUntil;

  const AvoraTargetPolicyAssignment({
    required this.id,
    required this.policyKey,
    required this.programId,
    required this.scopeType,
    required this.status,
    required this.stackingPolicy,
    required this.effectiveFrom,
    this.countryCode,
    this.regionCode,
    this.managerUserId,
    this.effectiveUntil,
  });

  bool activeAt(DateTime at) {
    if (status != AvoraTargetPolicyAssignmentStatus.active) {
      return false;
    }

    if (at.isBefore(effectiveFrom)) {
      return false;
    }

    final until = effectiveUntil;

    if (until != null && !at.isBefore(until)) {
      return false;
    }

    return true;
  }

  bool matchesCountry(String code) {
    if (scopeType == AvoraTargetPolicyScopeType.global) {
      return true;
    }

    if (scopeType != AvoraTargetPolicyScopeType.country) {
      return false;
    }

    final configured = countryCode;

    if (configured == null) {
      return false;
    }

    return configured.trim().toUpperCase() == code.trim().toUpperCase();
  }
}

class AvoraEconomicTargetEvent {
  final String id;

  final String sourceType;

  /// Sender/actor who caused the event.
  final String actorUserId;

  /// Receiver/host/room owner/etc. whose policy controls
  /// compensation for this target event.
  final String beneficiaryId;

  final AvoraTargetSubjectType beneficiaryType;

  /// Authoritative beneficiary country at event time.
  final String beneficiaryCountryCode;

  final int eligibleUnits;

  final DateTime occurredAt;

  /// Event can count only after normal fraud/refund/
  /// verification/source eligibility checks have passed.
  final bool eligible;

  const AvoraEconomicTargetEvent({
    required this.id,
    required this.sourceType,
    required this.actorUserId,
    required this.beneficiaryId,
    required this.beneficiaryType,
    required this.beneficiaryCountryCode,
    required this.eligibleUnits,
    required this.occurredAt,
    this.eligible = true,
  }) : assert(eligibleUnits >= 0);
}

class AvoraPolicyStampedTargetEvent {
  final AvoraEconomicTargetEvent event;

  /// Immutable snapshot references used for later settlement.
  final String policyAssignmentId;
  final String programId;
  final String policyKey;

  final AvoraTargetCadence cadence;

  final AvoraCompensationStackingPolicy stackingPolicy;

  const AvoraPolicyStampedTargetEvent({
    required this.event,
    required this.policyAssignmentId,
    required this.programId,
    required this.policyKey,
    required this.cadence,
    required this.stackingPolicy,
  });
}

class AvoraEconomicSettlementRecord {
  final String id;

  final String economicEventId;

  final String policyAssignmentId;

  final AvoraEconomicRewardFamily rewardFamily;

  /// Economic units consumed by this compensation.
  final int consumedEligibleUnits;

  final int rewardUnits;

  final DateTime settledAt;

  const AvoraEconomicSettlementRecord({
    required this.id,
    required this.economicEventId,
    required this.policyAssignmentId,
    required this.rewardFamily,
    required this.consumedEligibleUnits,
    required this.rewardUnits,
    required this.settledAt,
  })  : assert(consumedEligibleUnits >= 0),
        assert(rewardUnits >= 0);
}

class AvoraEconomicProgressAllocation {
  /// Analytics/target progress before compensation consumption.
  final int grossProgressUnits;

  /// Units still legally/economically available for payout.
  final int payableProgressUnits;

  final int alreadyConsumedUnits;

  const AvoraEconomicProgressAllocation({
    required this.grossProgressUnits,
    required this.payableProgressUnits,
    required this.alreadyConsumedUnits,
  });
}

enum AvoraPolicyStampDenyReason {
  none,
  eventIneligible,
  noApplicablePolicy,
  programNotFound,
}

class AvoraPolicyStampDecision {
  final bool allowed;

  final AvoraPolicyStampDenyReason reason;

  final AvoraPolicyStampedTargetEvent? stampedEvent;

  const AvoraPolicyStampDecision({
    required this.allowed,
    required this.reason,
    required this.stampedEvent,
  });
}

class AvoraTargetPolicyScopeEngine {
  const AvoraTargetPolicyScopeEngine._();

  static AvoraTargetPolicyAssignment? resolveAssignment({
    required String policyKey,
    required String beneficiaryCountryCode,
    required DateTime at,
    required List<AvoraTargetPolicyAssignment> assignments,
  }) {
    final candidates = assignments
        .where(
          (assignment) =>
              assignment.policyKey == policyKey && assignment.activeAt(at),
        )
        .toList(growable: false);

    /// Country-specific policy always beats global fallback.
    for (final assignment in candidates) {
      if (assignment.scopeType == AvoraTargetPolicyScopeType.country &&
          assignment.matchesCountry(
            beneficiaryCountryCode,
          )) {
        return assignment;
      }
    }

    for (final assignment in candidates) {
      if (assignment.scopeType == AvoraTargetPolicyScopeType.global) {
        return assignment;
      }
    }

    return null;
  }

  static AvoraPolicyStampDecision stampEvent({
    required AvoraEconomicTargetEvent event,
    required String policyKey,
    required List<AvoraTargetPolicyAssignment> assignments,
    required Map<String, AvoraTargetProgram> programsById,
  }) {
    if (!event.eligible) {
      return const AvoraPolicyStampDecision(
        allowed: false,
        reason: AvoraPolicyStampDenyReason.eventIneligible,
        stampedEvent: null,
      );
    }

    final assignment = resolveAssignment(
      policyKey: policyKey,
      beneficiaryCountryCode: event.beneficiaryCountryCode,
      at: event.occurredAt,
      assignments: assignments,
    );

    if (assignment == null) {
      return const AvoraPolicyStampDecision(
        allowed: false,
        reason: AvoraPolicyStampDenyReason.noApplicablePolicy,
        stampedEvent: null,
      );
    }

    final program = programsById[assignment.programId];

    if (program == null) {
      return const AvoraPolicyStampDecision(
        allowed: false,
        reason: AvoraPolicyStampDenyReason.programNotFound,
        stampedEvent: null,
      );
    }

    return AvoraPolicyStampDecision(
      allowed: true,
      reason: AvoraPolicyStampDenyReason.none,
      stampedEvent: AvoraPolicyStampedTargetEvent(
        event: event,
        policyAssignmentId: assignment.id,
        programId: assignment.programId,
        policyKey: assignment.policyKey,
        cadence: program.cadence,
        stackingPolicy: assignment.stackingPolicy,
      ),
    );
  }

  static AvoraEconomicProgressAllocation allocateProgress({
    required AvoraPolicyStampedTargetEvent stampedEvent,
    required List<AvoraEconomicSettlementRecord> existingSettlements,
  }) {
    final gross = stampedEvent.event.eligibleUnits;

    if (stampedEvent.stackingPolicy ==
        AvoraCompensationStackingPolicy.explicitStackingAllowed) {
      return AvoraEconomicProgressAllocation(
        grossProgressUnits: gross,
        payableProgressUnits: gross,
        alreadyConsumedUnits: 0,
      );
    }

    final consumed = existingSettlements
        .where(
          (settlement) => settlement.economicEventId == stampedEvent.event.id,
        )
        .fold<int>(
          0,
          (sum, settlement) => sum + settlement.consumedEligibleUnits,
        );

    final cappedConsumed = consumed > gross ? gross : consumed;

    final payable = gross - cappedConsumed;

    return AvoraEconomicProgressAllocation(
      grossProgressUnits: gross,
      payableProgressUnits: payable,
      alreadyConsumedUnits: cappedConsumed,
    );
  }

  static bool duplicateSettlementExists({
    required String economicEventId,
    required AvoraEconomicRewardFamily rewardFamily,
    required List<AvoraEconomicSettlementRecord> existingSettlements,
  }) {
    return existingSettlements.any(
      (settlement) =>
          settlement.economicEventId == economicEventId &&
          settlement.rewardFamily == rewardFamily,
    );
  }

  /// Sender country must never override the beneficiary
  /// policy that was stamped onto the economic event.
  static bool senderCountryCanChangeStampedPolicy() {
    return false;
  }
}
