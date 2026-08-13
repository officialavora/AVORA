import 'avora_target_policy_scope.dart';
import 'avora_target_program.dart';

enum AvoraSalaryPreviewRowStatus {
  payable,
  held,
  excluded,
  noPolicy,
  alreadySettled,
}

enum AvoraSalaryHoldReason {
  none,
  noApplicablePolicy,
  programNotFound,
  programInactive,
  identityNotVerified,
  riskHold,
  payoutHold,
  insufficientValidWorkTime,
  noEligibleWork,
  excludedByPolicy,
  alreadySettled,
}

enum AvoraSalarySettlementExecutionStatus {
  pending,
  paid,
  failed,
  reversed,
}

class AvoraSalarySettlementPeriod {
  final String id;

  final String policyKey;

  final DateTime startsAt;

  /// End is normally exclusive for work/activity collection.
  final DateTime endsAt;

  /// Used to resolve the effective country/scope policy snapshot.
  final DateTime policyEffectiveAt;

  const AvoraSalarySettlementPeriod({
    required this.id,
    required this.policyKey,
    required this.startsAt,
    required this.endsAt,
    required this.policyEffectiveAt,
  });
}

class AvoraSalaryProgramRule {
  final String programId;

  final int minimumValidWorkMinutes;

  final bool requireVerifiedIdentity;
  final bool requireRiskClear;
  final bool requirePayoutClear;

  const AvoraSalaryProgramRule({
    required this.programId,
    this.minimumValidWorkMinutes = 0,
    this.requireVerifiedIdentity = true,
    this.requireRiskClear = true,
    this.requirePayoutClear = true,
  }) : assert(minimumValidWorkMinutes >= 0);
}

class AvoraSalaryCandidate {
  final String subjectId;

  final AvoraTargetSubjectType subjectType;

  final String countryCode;

  /// Server-authoritative valid working time.
  final int validWorkMinutes;

  /// Analytics/target work before economic-consumption deduction.
  final int grossEligibleTargetUnits;

  /// Salary-payable units after anti-double-benefit,
  /// refund/fraud/reversal and settlement-consumption rules.
  final int payableEligibleTargetUnits;

  /// Existing carry/settlement state from prior period.
  final AvoraTargetProgressState progressState;

  final bool identityVerified;

  final bool riskHold;

  final bool payoutHold;

  final bool excludedByPolicy;

  final String? exclusionReason;

  const AvoraSalaryCandidate({
    required this.subjectId,
    required this.subjectType,
    required this.countryCode,
    required this.validWorkMinutes,
    required this.grossEligibleTargetUnits,
    required this.payableEligibleTargetUnits,
    required this.progressState,
    this.identityVerified = true,
    this.riskHold = false,
    this.payoutHold = false,
    this.excludedByPolicy = false,
    this.exclusionReason,
  })  : assert(validWorkMinutes >= 0),
        assert(grossEligibleTargetUnits >= 0),
        assert(payableEligibleTargetUnits >= 0),
        assert(
          payableEligibleTargetUnits <= grossEligibleTargetUnits,
        );
}

class AvoraSalarySettlementRecord {
  final String settlementKey;

  final String periodId;

  final String subjectId;

  final String policyAssignmentId;

  final String programId;

  final int rewardUnits;

  final String rewardValueType;

  final AvoraSalarySettlementExecutionStatus status;

  final DateTime? paidAt;

  final String? payoutReferenceId;

  final String? failureReason;

  const AvoraSalarySettlementRecord({
    required this.settlementKey,
    required this.periodId,
    required this.subjectId,
    required this.policyAssignmentId,
    required this.programId,
    required this.rewardUnits,
    required this.rewardValueType,
    required this.status,
    this.paidAt,
    this.payoutReferenceId,
    this.failureReason,
  }) : assert(rewardUnits >= 0);
}

class AvoraSalaryPreviewRow {
  final String subjectId;

  final AvoraTargetSubjectType subjectType;

  final String countryCode;

  final String? policyAssignmentId;

  final String? programId;

  final AvoraTargetCadence? cadence;

  final String? rewardValueType;

  final int validWorkMinutes;

  final int grossEligibleTargetUnits;

  final int payableEligibleTargetUnits;

  final int carryInUnits;

  final int settledThroughBeforeUnits;

  final List<String> newlyReachedMilestoneIds;

  final int payableRewardUnits;

  final int nextCarryUnits;

  final int nextSettledThroughUnits;

  final int? nextTargetUnits;

  final int? nextTargetRemainingUnits;

  final String? settlementKey;

  final AvoraSalaryPreviewRowStatus status;

  final AvoraSalaryHoldReason holdReason;

  final String? exclusionReason;

  const AvoraSalaryPreviewRow({
    required this.subjectId,
    required this.subjectType,
    required this.countryCode,
    required this.policyAssignmentId,
    required this.programId,
    required this.cadence,
    required this.rewardValueType,
    required this.validWorkMinutes,
    required this.grossEligibleTargetUnits,
    required this.payableEligibleTargetUnits,
    required this.carryInUnits,
    required this.settledThroughBeforeUnits,
    required this.newlyReachedMilestoneIds,
    required this.payableRewardUnits,
    required this.nextCarryUnits,
    required this.nextSettledThroughUnits,
    required this.nextTargetUnits,
    required this.nextTargetRemainingUnits,
    required this.settlementKey,
    required this.status,
    required this.holdReason,
    this.exclusionReason,
  });
}

class AvoraSalaryCountryProgramSummary {
  final String countryCode;

  final String programId;

  final String rewardValueType;

  final int totalSubjects;

  final int payableSubjects;

  final int heldSubjects;

  final int excludedSubjects;

  final int alreadySettledSubjects;

  final int totalValidWorkMinutes;

  final int grossEligibleTargetUnits;

  final int payableEligibleTargetUnits;

  final int totalPayableRewardUnits;

  const AvoraSalaryCountryProgramSummary({
    required this.countryCode,
    required this.programId,
    required this.rewardValueType,
    required this.totalSubjects,
    required this.payableSubjects,
    required this.heldSubjects,
    required this.excludedSubjects,
    required this.alreadySettledSubjects,
    required this.totalValidWorkMinutes,
    required this.grossEligibleTargetUnits,
    required this.payableEligibleTargetUnits,
    required this.totalPayableRewardUnits,
  });
}

class AvoraSalarySettlementAction {
  final String settlementKey;

  final String periodId;

  final String subjectId;

  final String countryCode;

  final String policyAssignmentId;

  final String programId;

  final String rewardValueType;

  final int rewardUnits;

  final AvoraTargetProgressState nextProgressState;

  final List<String> reachedMilestoneIds;

  const AvoraSalarySettlementAction({
    required this.settlementKey,
    required this.periodId,
    required this.subjectId,
    required this.countryCode,
    required this.policyAssignmentId,
    required this.programId,
    required this.rewardValueType,
    required this.rewardUnits,
    required this.nextProgressState,
    required this.reachedMilestoneIds,
  });
}

class AvoraSalarySettlementBatch {
  final int batchNumber;

  final List<AvoraSalarySettlementAction> actions;

  const AvoraSalarySettlementBatch({
    required this.batchNumber,
    required this.actions,
  });
}

class AvoraOneClickSalaryPreview {
  final String periodId;

  final List<AvoraSalaryPreviewRow> rows;

  final List<AvoraSalaryCountryProgramSummary> summaries;

  final List<AvoraSalarySettlementAction> pendingActions;

  final List<AvoraSalarySettlementBatch> pendingBatches;

  final int totalSubjects;

  final int payableSubjects;

  final int heldSubjects;

  final int excludedSubjects;

  final int alreadySettledSubjects;

  const AvoraOneClickSalaryPreview({
    required this.periodId,
    required this.rows,
    required this.summaries,
    required this.pendingActions,
    required this.pendingBatches,
    required this.totalSubjects,
    required this.payableSubjects,
    required this.heldSubjects,
    required this.excludedSubjects,
    required this.alreadySettledSubjects,
  });

  bool get nothingToPay => pendingActions.isEmpty;
}

class AvoraBulkSalarySettlementEngine {
  const AvoraBulkSalarySettlementEngine._();

  static String settlementKey({
    required String periodId,
    required String policyAssignmentId,
    required String programId,
    required String subjectId,
  }) {
    return '$periodId|$policyAssignmentId|$programId|$subjectId';
  }

  static bool _alreadyPaid({
    required String key,
    required List<AvoraSalarySettlementRecord> existingSettlements,
  }) {
    return existingSettlements.any(
      (record) =>
          record.settlementKey == key &&
          record.status == AvoraSalarySettlementExecutionStatus.paid,
    );
  }

  static AvoraSalaryProgramRule _ruleFor({
    required String programId,
    required Map<String, AvoraSalaryProgramRule> rulesByProgramId,
  }) {
    return rulesByProgramId[programId] ??
        AvoraSalaryProgramRule(
          programId: programId,
        );
  }

  static AvoraSalaryPreviewRow _nonPayableRow({
    required AvoraSalaryCandidate candidate,
    required AvoraSalaryPreviewRowStatus status,
    required AvoraSalaryHoldReason reason,
    String? assignmentId,
    String? programId,
    AvoraTargetCadence? cadence,
    String? rewardValueType,
    String? key,
  }) {
    return AvoraSalaryPreviewRow(
      subjectId: candidate.subjectId,
      subjectType: candidate.subjectType,
      countryCode: candidate.countryCode,
      policyAssignmentId: assignmentId,
      programId: programId,
      cadence: cadence,
      rewardValueType: rewardValueType,
      validWorkMinutes: candidate.validWorkMinutes,
      grossEligibleTargetUnits: candidate.grossEligibleTargetUnits,
      payableEligibleTargetUnits: candidate.payableEligibleTargetUnits,
      carryInUnits: candidate.progressState.carryUnits,
      settledThroughBeforeUnits: candidate.progressState.settledThroughUnits,
      newlyReachedMilestoneIds: const [],
      payableRewardUnits: 0,
      nextCarryUnits: candidate.progressState.carryUnits,
      nextSettledThroughUnits: candidate.progressState.settledThroughUnits,
      nextTargetUnits: null,
      nextTargetRemainingUnits: null,
      settlementKey: key,
      status: status,
      holdReason: reason,
      exclusionReason: candidate.exclusionReason,
    );
  }

  static AvoraSalaryPreviewRow buildCandidateRow({
    required AvoraSalarySettlementPeriod period,
    required AvoraSalaryCandidate candidate,
    required List<AvoraTargetPolicyAssignment> assignments,
    required Map<String, AvoraTargetProgram> programsById,
    required Map<String, AvoraSalaryProgramRule> rulesByProgramId,
    required List<AvoraSalarySettlementRecord> existingSettlements,
  }) {
    final assignment = AvoraTargetPolicyScopeEngine.resolveAssignment(
      policyKey: period.policyKey,
      beneficiaryCountryCode: candidate.countryCode,
      at: period.policyEffectiveAt,
      assignments: assignments,
    );

    if (assignment == null) {
      return _nonPayableRow(
        candidate: candidate,
        status: AvoraSalaryPreviewRowStatus.noPolicy,
        reason: AvoraSalaryHoldReason.noApplicablePolicy,
      );
    }

    final program = programsById[assignment.programId];

    if (program == null) {
      return _nonPayableRow(
        candidate: candidate,
        status: AvoraSalaryPreviewRowStatus.noPolicy,
        reason: AvoraSalaryHoldReason.programNotFound,
        assignmentId: assignment.id,
        programId: assignment.programId,
      );
    }

    final key = settlementKey(
      periodId: period.id,
      policyAssignmentId: assignment.id,
      programId: program.id,
      subjectId: candidate.subjectId,
    );

    if (_alreadyPaid(
      key: key,
      existingSettlements: existingSettlements,
    )) {
      return _nonPayableRow(
        candidate: candidate,
        status: AvoraSalaryPreviewRowStatus.alreadySettled,
        reason: AvoraSalaryHoldReason.alreadySettled,
        assignmentId: assignment.id,
        programId: program.id,
        cadence: program.cadence,
        rewardValueType: program.rewardValueType,
        key: key,
      );
    }

    if (program.status != AvoraTargetProgramStatus.active) {
      return _nonPayableRow(
        candidate: candidate,
        status: AvoraSalaryPreviewRowStatus.held,
        reason: AvoraSalaryHoldReason.programInactive,
        assignmentId: assignment.id,
        programId: program.id,
        cadence: program.cadence,
        rewardValueType: program.rewardValueType,
        key: key,
      );
    }

    final rule = _ruleFor(
      programId: program.id,
      rulesByProgramId: rulesByProgramId,
    );

    if (candidate.excludedByPolicy) {
      return _nonPayableRow(
        candidate: candidate,
        status: AvoraSalaryPreviewRowStatus.excluded,
        reason: AvoraSalaryHoldReason.excludedByPolicy,
        assignmentId: assignment.id,
        programId: program.id,
        cadence: program.cadence,
        rewardValueType: program.rewardValueType,
        key: key,
      );
    }

    if (rule.requireVerifiedIdentity && !candidate.identityVerified) {
      return _nonPayableRow(
        candidate: candidate,
        status: AvoraSalaryPreviewRowStatus.held,
        reason: AvoraSalaryHoldReason.identityNotVerified,
        assignmentId: assignment.id,
        programId: program.id,
        cadence: program.cadence,
        rewardValueType: program.rewardValueType,
        key: key,
      );
    }

    if (rule.requireRiskClear && candidate.riskHold) {
      return _nonPayableRow(
        candidate: candidate,
        status: AvoraSalaryPreviewRowStatus.held,
        reason: AvoraSalaryHoldReason.riskHold,
        assignmentId: assignment.id,
        programId: program.id,
        cadence: program.cadence,
        rewardValueType: program.rewardValueType,
        key: key,
      );
    }

    if (rule.requirePayoutClear && candidate.payoutHold) {
      return _nonPayableRow(
        candidate: candidate,
        status: AvoraSalaryPreviewRowStatus.held,
        reason: AvoraSalaryHoldReason.payoutHold,
        assignmentId: assignment.id,
        programId: program.id,
        cadence: program.cadence,
        rewardValueType: program.rewardValueType,
        key: key,
      );
    }

    if (candidate.validWorkMinutes < rule.minimumValidWorkMinutes) {
      return _nonPayableRow(
        candidate: candidate,
        status: AvoraSalaryPreviewRowStatus.excluded,
        reason: AvoraSalaryHoldReason.insufficientValidWorkTime,
        assignmentId: assignment.id,
        programId: program.id,
        cadence: program.cadence,
        rewardValueType: program.rewardValueType,
        key: key,
      );
    }

    if (candidate.payableEligibleTargetUnits == 0 &&
        candidate.progressState.carryUnits == 0) {
      return _nonPayableRow(
        candidate: candidate,
        status: AvoraSalaryPreviewRowStatus.excluded,
        reason: AvoraSalaryHoldReason.noEligibleWork,
        assignmentId: assignment.id,
        programId: program.id,
        cadence: program.cadence,
        rewardValueType: program.rewardValueType,
        key: key,
      );
    }

    final settlement = AvoraTargetProgramEngine.settlePeriod(
      program: program,
      state: candidate.progressState,
      periodEligibleUnits: candidate.payableEligibleTargetUnits,
    );

    final rewardUnits = settlement.rewards.fold<int>(
      0,
      (sum, reward) => sum + reward.totalRewardUnits,
    );

    final reachedIds = settlement.newlyReachedMilestones
        .map((milestone) => milestone.id)
        .toList(growable: false);

    final reachedSomething = reachedIds.isNotEmpty;

    if (!reachedSomething) {
      return AvoraSalaryPreviewRow(
        subjectId: candidate.subjectId,
        subjectType: candidate.subjectType,
        countryCode: candidate.countryCode,
        policyAssignmentId: assignment.id,
        programId: program.id,
        cadence: program.cadence,
        rewardValueType: program.rewardValueType,
        validWorkMinutes: candidate.validWorkMinutes,
        grossEligibleTargetUnits: candidate.grossEligibleTargetUnits,
        payableEligibleTargetUnits: candidate.payableEligibleTargetUnits,
        carryInUnits: candidate.progressState.carryUnits,
        settledThroughBeforeUnits: candidate.progressState.settledThroughUnits,
        newlyReachedMilestoneIds: const [],
        payableRewardUnits: 0,
        nextCarryUnits: settlement.nextState.carryUnits,
        nextSettledThroughUnits: settlement.nextState.settledThroughUnits,
        nextTargetUnits: settlement.nextProgress?.nextMilestoneUnits,
        nextTargetRemainingUnits: settlement.nextProgress?.remainingUnits,
        settlementKey: key,
        status: AvoraSalaryPreviewRowStatus.excluded,
        holdReason: AvoraSalaryHoldReason.noEligibleWork,
      );
    }

    return AvoraSalaryPreviewRow(
      subjectId: candidate.subjectId,
      subjectType: candidate.subjectType,
      countryCode: candidate.countryCode,
      policyAssignmentId: assignment.id,
      programId: program.id,
      cadence: program.cadence,
      rewardValueType: program.rewardValueType,
      validWorkMinutes: candidate.validWorkMinutes,
      grossEligibleTargetUnits: candidate.grossEligibleTargetUnits,
      payableEligibleTargetUnits: candidate.payableEligibleTargetUnits,
      carryInUnits: candidate.progressState.carryUnits,
      settledThroughBeforeUnits: candidate.progressState.settledThroughUnits,
      newlyReachedMilestoneIds: reachedIds,
      payableRewardUnits: rewardUnits,
      nextCarryUnits: settlement.nextState.carryUnits,
      nextSettledThroughUnits: settlement.nextState.settledThroughUnits,
      nextTargetUnits: settlement.nextProgress?.nextMilestoneUnits,
      nextTargetRemainingUnits: settlement.nextProgress?.remainingUnits,
      settlementKey: key,
      status: AvoraSalaryPreviewRowStatus.payable,
      holdReason: AvoraSalaryHoldReason.none,
    );
  }

  static List<AvoraSalarySettlementAction> _actionsFromRows({
    required String periodId,
    required List<AvoraSalaryPreviewRow> rows,
  }) {
    final actions = <AvoraSalarySettlementAction>[];

    for (final row in rows) {
      if (row.status != AvoraSalaryPreviewRowStatus.payable ||
          row.settlementKey == null ||
          row.policyAssignmentId == null ||
          row.programId == null ||
          row.rewardValueType == null) {
        continue;
      }

      actions.add(
        AvoraSalarySettlementAction(
          settlementKey: row.settlementKey!,
          periodId: periodId,
          subjectId: row.subjectId,
          countryCode: row.countryCode,
          policyAssignmentId: row.policyAssignmentId!,
          programId: row.programId!,
          rewardValueType: row.rewardValueType!,
          rewardUnits: row.payableRewardUnits,
          nextProgressState: AvoraTargetProgressState(
            programId: row.programId!,
            subjectId: row.subjectId,
            settledThroughUnits: row.nextSettledThroughUnits,
            carryUnits: row.nextCarryUnits,
          ),
          reachedMilestoneIds: List.unmodifiable(row.newlyReachedMilestoneIds),
        ),
      );
    }

    return List.unmodifiable(actions);
  }

  static List<AvoraSalarySettlementBatch> buildBatches({
    required List<AvoraSalarySettlementAction> actions,
    int batchSize = 500,
  }) {
    if (batchSize <= 0) {
      throw ArgumentError.value(
        batchSize,
        'batchSize',
        'must be greater than zero',
      );
    }

    final batches = <AvoraSalarySettlementBatch>[];

    for (var start = 0; start < actions.length; start += batchSize) {
      final end = start + batchSize > actions.length
          ? actions.length
          : start + batchSize;

      batches.add(
        AvoraSalarySettlementBatch(
          batchNumber: batches.length + 1,
          actions: List.unmodifiable(
            actions.sublist(start, end),
          ),
        ),
      );
    }

    return List.unmodifiable(batches);
  }

  static List<AvoraSalaryCountryProgramSummary> _buildSummaries(
    List<AvoraSalaryPreviewRow> rows,
  ) {
    final groups = <String, List<AvoraSalaryPreviewRow>>{};

    for (final row in rows) {
      final programId = row.programId ?? 'NO_POLICY';
      final valueType = row.rewardValueType ?? 'NONE';

      final key = '${row.countryCode}|$programId|$valueType';

      groups.putIfAbsent(key, () => []).add(row);
    }

    final result = <AvoraSalaryCountryProgramSummary>[];

    for (final entry in groups.entries) {
      final group = entry.value;

      final first = group.first;

      result.add(
        AvoraSalaryCountryProgramSummary(
          countryCode: first.countryCode,
          programId: first.programId ?? 'NO_POLICY',
          rewardValueType: first.rewardValueType ?? 'NONE',
          totalSubjects: group.length,
          payableSubjects: group
              .where(
                (row) => row.status == AvoraSalaryPreviewRowStatus.payable,
              )
              .length,
          heldSubjects: group
              .where(
                (row) => row.status == AvoraSalaryPreviewRowStatus.held,
              )
              .length,
          excludedSubjects: group
              .where(
                (row) =>
                    row.status == AvoraSalaryPreviewRowStatus.excluded ||
                    row.status == AvoraSalaryPreviewRowStatus.noPolicy,
              )
              .length,
          alreadySettledSubjects: group
              .where(
                (row) =>
                    row.status == AvoraSalaryPreviewRowStatus.alreadySettled,
              )
              .length,
          totalValidWorkMinutes: group.fold<int>(
            0,
            (sum, row) => sum + row.validWorkMinutes,
          ),
          grossEligibleTargetUnits: group.fold<int>(
            0,
            (sum, row) => sum + row.grossEligibleTargetUnits,
          ),
          payableEligibleTargetUnits: group.fold<int>(
            0,
            (sum, row) => sum + row.payableEligibleTargetUnits,
          ),
          totalPayableRewardUnits: group.fold<int>(
            0,
            (sum, row) => sum + row.payableRewardUnits,
          ),
        ),
      );
    }

    result.sort((a, b) {
      final countryCompare = a.countryCode.compareTo(b.countryCode);

      if (countryCompare != 0) {
        return countryCompare;
      }

      return a.programId.compareTo(b.programId);
    });

    return List.unmodifiable(result);
  }

  static AvoraOneClickSalaryPreview buildPreview({
    required AvoraSalarySettlementPeriod period,
    required List<AvoraSalaryCandidate> candidates,
    required List<AvoraTargetPolicyAssignment> assignments,
    required Map<String, AvoraTargetProgram> programsById,
    required Map<String, AvoraSalaryProgramRule> rulesByProgramId,
    required List<AvoraSalarySettlementRecord> existingSettlements,
    int batchSize = 500,
  }) {
    final rows = candidates
        .map(
          (candidate) => buildCandidateRow(
            period: period,
            candidate: candidate,
            assignments: assignments,
            programsById: programsById,
            rulesByProgramId: rulesByProgramId,
            existingSettlements: existingSettlements,
          ),
        )
        .toList(growable: false);

    final actions = _actionsFromRows(
      periodId: period.id,
      rows: rows,
    );

    final batches = buildBatches(
      actions: actions,
      batchSize: batchSize,
    );

    return AvoraOneClickSalaryPreview(
      periodId: period.id,
      rows: List.unmodifiable(rows),
      summaries: _buildSummaries(rows),
      pendingActions: actions,
      pendingBatches: batches,
      totalSubjects: rows.length,
      payableSubjects: rows
          .where(
            (row) => row.status == AvoraSalaryPreviewRowStatus.payable,
          )
          .length,
      heldSubjects: rows
          .where(
            (row) => row.status == AvoraSalaryPreviewRowStatus.held,
          )
          .length,
      excludedSubjects: rows
          .where(
            (row) =>
                row.status == AvoraSalaryPreviewRowStatus.excluded ||
                row.status == AvoraSalaryPreviewRowStatus.noPolicy,
          )
          .length,
      alreadySettledSubjects: rows
          .where(
            (row) => row.status == AvoraSalaryPreviewRowStatus.alreadySettled,
          )
          .length,
    );
  }

  /// Owner never calculates one user at a time.
  static bool requiresManualPerUserSalaryCalculation() {
    return false;
  }

  /// One operator approval can dispatch all pending batches.
  static bool supportsOneClickPayAll() {
    return true;
  }

  /// Paid settlement keys are skipped on retry.
  static bool supportsIdempotentRetry() {
    return true;
  }

  /// Country/cadence comes from authoritative policy assignment.
  static bool operatorMustChooseCadencePerUser() {
    return false;
  }
}
