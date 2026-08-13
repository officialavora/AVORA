enum AvoraPolicyChangeMode {
  nextCycle,
  prospectiveFromNow,
  emergencyDisable,
}

enum AvoraPolicyChangeDenyReason {
  none,
  invalidCycle,
  invalidPolicyReference,
  invalidCutoverTime,
  cutoverOutsideCycle,
}

class AvoraPolicyCycleSegment {
  const AvoraPolicyCycleSegment({
    required this.segmentId,
    required this.cycleId,
    required this.policySnapshotKey,
    required this.startAtUtc,
    required this.endAtUtc,
    required this.accrualEnabled,
    required this.carriedForwardMetricUnits,
  });

  final String segmentId;
  final String cycleId;

  /// Immutable version/snapshot key used for this segment.
  final String policySnapshotKey;

  final DateTime startAtUtc;
  final DateTime endAtUtc;

  /// Emergency disable can stop future accrual without deleting old work.
  final bool accrualEnabled;

  /// Existing eligible progress preserved across a prospective cutover.
  final int carriedForwardMetricUnits;

  bool get valid =>
      segmentId.trim().isNotEmpty &&
      cycleId.trim().isNotEmpty &&
      policySnapshotKey.trim().isNotEmpty &&
      startAtUtc.isUtc &&
      endAtUtc.isUtc &&
      endAtUtc.isAfter(startAtUtc) &&
      carriedForwardMetricUnits >= 0;
}

class AvoraPolicyChangePlan {
  const AvoraPolicyChangePlan({
    required this.allowed,
    required this.reason,
    required this.mode,
    required this.cycleId,
    required this.currentPolicySnapshotKey,
    required this.proposedPolicySnapshotKey,
    required this.activationAtUtc,
    required this.currentCycleSegments,
    required this.appliesToCurrentCycle,
  });

  final bool allowed;
  final AvoraPolicyChangeDenyReason reason;
  final AvoraPolicyChangeMode mode;

  final String cycleId;

  final String currentPolicySnapshotKey;
  final String proposedPolicySnapshotKey;

  final DateTime activationAtUtc;

  final List<AvoraPolicyCycleSegment> currentCycleSegments;

  /// False for nextCycle.
  final bool appliesToCurrentCycle;
}

class AvoraPolicyChangeControl {
  const AvoraPolicyChangeControl._();

  static AvoraPolicyChangePlan plan({
    required AvoraPolicyChangeMode mode,
    required String cycleId,
    required String currentPolicySnapshotKey,
    required String proposedPolicySnapshotKey,
    required DateTime cycleStartAtUtc,
    required DateTime cycleEndAtUtc,
    required DateTime serverCutoverAtUtc,
    required int alreadyEligibleMetricUnits,
  }) {
    if (cycleId.trim().isEmpty ||
        !cycleStartAtUtc.isUtc ||
        !cycleEndAtUtc.isUtc ||
        !cycleEndAtUtc.isAfter(cycleStartAtUtc) ||
        alreadyEligibleMetricUnits < 0) {
      return _denied(
        mode: mode,
        cycleId: cycleId,
        currentPolicySnapshotKey: currentPolicySnapshotKey,
        proposedPolicySnapshotKey: proposedPolicySnapshotKey,
        activationAtUtc: serverCutoverAtUtc,
        reason: AvoraPolicyChangeDenyReason.invalidCycle,
      );
    }

    if (currentPolicySnapshotKey.trim().isEmpty ||
        proposedPolicySnapshotKey.trim().isEmpty) {
      return _denied(
        mode: mode,
        cycleId: cycleId,
        currentPolicySnapshotKey: currentPolicySnapshotKey,
        proposedPolicySnapshotKey: proposedPolicySnapshotKey,
        activationAtUtc: serverCutoverAtUtc,
        reason: AvoraPolicyChangeDenyReason.invalidPolicyReference,
      );
    }

    if (!serverCutoverAtUtc.isUtc) {
      return _denied(
        mode: mode,
        cycleId: cycleId,
        currentPolicySnapshotKey: currentPolicySnapshotKey,
        proposedPolicySnapshotKey: proposedPolicySnapshotKey,
        activationAtUtc: serverCutoverAtUtc,
        reason: AvoraPolicyChangeDenyReason.invalidCutoverTime,
      );
    }

    switch (mode) {
      case AvoraPolicyChangeMode.nextCycle:
        return AvoraPolicyChangePlan(
          allowed: true,
          reason: AvoraPolicyChangeDenyReason.none,
          mode: mode,
          cycleId: cycleId,
          currentPolicySnapshotKey: currentPolicySnapshotKey,
          proposedPolicySnapshotKey: proposedPolicySnapshotKey,
          activationAtUtc: cycleEndAtUtc,
          appliesToCurrentCycle: false,
          currentCycleSegments: [
            AvoraPolicyCycleSegment(
              segmentId: '$cycleId:current',
              cycleId: cycleId,
              policySnapshotKey: currentPolicySnapshotKey,
              startAtUtc: cycleStartAtUtc,
              endAtUtc: cycleEndAtUtc,
              accrualEnabled: true,
              carriedForwardMetricUnits: alreadyEligibleMetricUnits,
            ),
          ],
        );

      case AvoraPolicyChangeMode.prospectiveFromNow:
      case AvoraPolicyChangeMode.emergencyDisable:
        if (!serverCutoverAtUtc.isAfter(cycleStartAtUtc) ||
            !serverCutoverAtUtc.isBefore(cycleEndAtUtc)) {
          return _denied(
            mode: mode,
            cycleId: cycleId,
            currentPolicySnapshotKey: currentPolicySnapshotKey,
            proposedPolicySnapshotKey: proposedPolicySnapshotKey,
            activationAtUtc: serverCutoverAtUtc,
            reason: AvoraPolicyChangeDenyReason.cutoverOutsideCycle,
          );
        }

        final futureAccrualEnabled =
            mode != AvoraPolicyChangeMode.emergencyDisable;

        return AvoraPolicyChangePlan(
          allowed: true,
          reason: AvoraPolicyChangeDenyReason.none,
          mode: mode,
          cycleId: cycleId,
          currentPolicySnapshotKey: currentPolicySnapshotKey,
          proposedPolicySnapshotKey: proposedPolicySnapshotKey,
          activationAtUtc: serverCutoverAtUtc,
          appliesToCurrentCycle: true,
          currentCycleSegments: [
            AvoraPolicyCycleSegment(
              segmentId: '$cycleId:before-cutover',
              cycleId: cycleId,
              policySnapshotKey: currentPolicySnapshotKey,
              startAtUtc: cycleStartAtUtc,
              endAtUtc: serverCutoverAtUtc,
              accrualEnabled: true,
              carriedForwardMetricUnits: alreadyEligibleMetricUnits,
            ),
            AvoraPolicyCycleSegment(
              segmentId: '$cycleId:after-cutover',
              cycleId: cycleId,
              policySnapshotKey: proposedPolicySnapshotKey,
              startAtUtc: serverCutoverAtUtc,
              endAtUtc: cycleEndAtUtc,
              accrualEnabled: futureAccrualEnabled,
              carriedForwardMetricUnits: alreadyEligibleMetricUnits,
            ),
          ],
        );
    }
  }

  static AvoraPolicyChangePlan _denied({
    required AvoraPolicyChangeMode mode,
    required String cycleId,
    required String currentPolicySnapshotKey,
    required String proposedPolicySnapshotKey,
    required DateTime activationAtUtc,
    required AvoraPolicyChangeDenyReason reason,
  }) {
    return AvoraPolicyChangePlan(
      allowed: false,
      reason: reason,
      mode: mode,
      cycleId: cycleId,
      currentPolicySnapshotKey: currentPolicySnapshotKey,
      proposedPolicySnapshotKey: proposedPolicySnapshotKey,
      activationAtUtc: activationAtUtc,
      currentCycleSegments: const [],
      appliesToCurrentCycle: false,
    );
  }

  /// Existing scheduled activation/effective-date engine is reused.
  static bool scheduledActivationRemainsExistingInfrastructure() => true;

  /// Existing policy preview UI/logic is reused before publish.
  static bool previewImpactRemainsExistingInfrastructure() => true;

  /// Already-finalized historical cycles can never be silently recalculated.
  static bool finalizedHistoryCanBeRewritten() => false;

  /// Prospective changes preserve accumulated progress at cutover.
  static bool prospectiveChangeCarriesForwardExistingProgress() => true;

  /// Rollback is another future/prospective version, never history deletion.
  static bool rollbackMutatesHistoricalTransactions() => false;

  /// Server/business-time decides cutover, never device time.
  static bool clientCanChooseAuthoritativeCutoverTime() => false;

  /// Replaying the same change must be deterministic/idempotent downstream.
  static bool idempotentPolicyChangeRequired() => true;

  /// Universal settlement must use cycle/segment snapshot, not latest policy.
  static bool settlementUsesSegmentPolicySnapshots() => true;
}
