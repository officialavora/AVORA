enum AvoraRecoveryIncidentStatus {
  detected,
  investigating,
  frozen,
  approved,
  executing,
  partiallyCompleted,
  completed,
  cancelled,
}

enum AvoraIncidentScopeType {
  global,
  country,
  region,
  feature,
  user,
  room,
  custom,
}

enum AvoraRecoveryDomain {
  walletBalance,
  targetProgress,
  identityLevel,
  roomLevel,
  relationshipLevel,
  leaderboardScore,
  premiumEntitlement,
  rewardGrant,
  custom,
}

enum AvoraRecoveryActionType {
  compensatingLedgerEntry,
  replaceDerivedValue,
  revokeEntitlement,
  revokeRewardGrant,
  custom,
}

enum AvoraRecoveryActionStatus {
  pending,
  applied,
  skippedAlreadyApplied,
  failed,
}

class AvoraIncident {
  final String id;

  final String title;

  final AvoraRecoveryIncidentStatus status;

  final AvoraIncidentScopeType scopeType;

  /// Country/region/feature/user/room identifier where relevant.
  final String? scopeValue;

  /// Exact affected time window.
  final DateTime startsAt;
  final DateTime endsAt;

  /// Rule/version/signature identifying invalid activity.
  final String detectionRuleId;

  final String? softwareVersion;
  final String? policyVersion;

  final String openedByUserId;
  final DateTime openedAt;

  final String? approvedByUserId;
  final DateTime? approvedAt;

  const AvoraIncident({
    required this.id,
    required this.title,
    required this.status,
    required this.scopeType,
    required this.startsAt,
    required this.endsAt,
    required this.detectionRuleId,
    required this.openedByUserId,
    required this.openedAt,
    this.scopeValue,
    this.softwareVersion,
    this.policyVersion,
    this.approvedByUserId,
    this.approvedAt,
  });

  bool containsTime(DateTime time) {
    return !time.isBefore(startsAt) && !time.isAfter(endsAt);
  }

  bool get approvedForExecution {
    return approvedByUserId != null &&
        approvedAt != null &&
        (status == AvoraRecoveryIncidentStatus.approved ||
            status == AvoraRecoveryIncidentStatus.executing ||
            status == AvoraRecoveryIncidentStatus.partiallyCompleted);
  }
}

class AvoraIncidentAffectedEvent {
  final String incidentId;

  final String economicEventId;

  final String subjectId;

  final AvoraRecoveryDomain domain;

  /// Invalid value contributed by this source event.
  final int invalidUnits;

  const AvoraIncidentAffectedEvent({
    required this.incidentId,
    required this.economicEventId,
    required this.subjectId,
    required this.domain,
    required this.invalidUnits,
  }) : assert(invalidUnits >= 0);
}

class AvoraAuthoritativeStateCorrection {
  final String incidentId;

  final String subjectId;

  final AvoraRecoveryDomain domain;

  /// Observed state before repair.
  final int beforeValue;

  /// Value recomputed from valid authoritative history.
  final int correctedValue;

  final List<String> sourceEventIds;

  const AvoraAuthoritativeStateCorrection({
    required this.incidentId,
    required this.subjectId,
    required this.domain,
    required this.beforeValue,
    required this.correctedValue,
    required this.sourceEventIds,
  })  : assert(beforeValue >= 0),
        assert(correctedValue >= 0);

  int get delta => correctedValue - beforeValue;
}

class AvoraRecoveryAction {
  /// Stable idempotency key.
  final String actionKey;

  final String incidentId;

  final String subjectId;

  final AvoraRecoveryDomain domain;

  final AvoraRecoveryActionType type;

  final int beforeValue;
  final int correctedValue;

  final List<String> sourceEventIds;

  const AvoraRecoveryAction({
    required this.actionKey,
    required this.incidentId,
    required this.subjectId,
    required this.domain,
    required this.type,
    required this.beforeValue,
    required this.correctedValue,
    required this.sourceEventIds,
  });

  int get delta => correctedValue - beforeValue;
}

class AvoraRecoveryExecutionRecord {
  final String actionKey;

  final String incidentId;

  final AvoraRecoveryActionStatus status;

  final DateTime executedAt;

  final String executedByUserId;

  final String? reversalLedgerEntryId;

  final String? failureReason;

  const AvoraRecoveryExecutionRecord({
    required this.actionKey,
    required this.incidentId,
    required this.status,
    required this.executedAt,
    required this.executedByUserId,
    this.reversalLedgerEntryId,
    this.failureReason,
  });
}

class AvoraRecoveryPlan {
  final String incidentId;

  final DateTime generatedAt;

  final List<AvoraRecoveryAction> actions;

  final int affectedSubjects;

  final int totalAbsoluteCorrectionUnits;

  const AvoraRecoveryPlan({
    required this.incidentId,
    required this.generatedAt,
    required this.actions,
    required this.affectedSubjects,
    required this.totalAbsoluteCorrectionUnits,
  });
}

class AvoraRecoveryExecutionPreview {
  final int pendingActions;

  final int alreadyAppliedActions;

  final int affectedSubjects;

  final int totalAbsoluteCorrectionUnits;

  const AvoraRecoveryExecutionPreview({
    required this.pendingActions,
    required this.alreadyAppliedActions,
    required this.affectedSubjects,
    required this.totalAbsoluteCorrectionUnits,
  });
}

class AvoraBalanceRecoveryAllocation {
  final int invalidCreditUnits;

  /// Amount recoverable from currently available invalid value.
  final int immediateRecoveryUnits;

  /// Unrecovered invalid value tracked as recoverable liability/debt.
  final int deferredRecoveryUnits;

  const AvoraBalanceRecoveryAllocation({
    required this.invalidCreditUnits,
    required this.immediateRecoveryUnits,
    required this.deferredRecoveryUnits,
  });
}

class AvoraIncidentRecoveryEngine {
  const AvoraIncidentRecoveryEngine._();

  static String actionKey({
    required String incidentId,
    required String subjectId,
    required AvoraRecoveryDomain domain,
  }) {
    return '$incidentId|$subjectId|${domain.name}';
  }

  static AvoraRecoveryPlan buildPlan({
    required String incidentId,
    required DateTime generatedAt,
    required List<AvoraAuthoritativeStateCorrection> corrections,
  }) {
    final actions = <AvoraRecoveryAction>[];

    for (final correction in corrections) {
      if (correction.incidentId != incidentId) {
        continue;
      }

      if (correction.beforeValue == correction.correctedValue) {
        continue;
      }

      final type = switch (correction.domain) {
        AvoraRecoveryDomain.walletBalance =>
          AvoraRecoveryActionType.compensatingLedgerEntry,
        AvoraRecoveryDomain.premiumEntitlement =>
          AvoraRecoveryActionType.revokeEntitlement,
        AvoraRecoveryDomain.rewardGrant =>
          AvoraRecoveryActionType.revokeRewardGrant,
        _ => AvoraRecoveryActionType.replaceDerivedValue,
      };

      actions.add(
        AvoraRecoveryAction(
          actionKey: actionKey(
            incidentId: incidentId,
            subjectId: correction.subjectId,
            domain: correction.domain,
          ),
          incidentId: incidentId,
          subjectId: correction.subjectId,
          domain: correction.domain,
          type: type,
          beforeValue: correction.beforeValue,
          correctedValue: correction.correctedValue,
          sourceEventIds: List.unmodifiable(
            correction.sourceEventIds,
          ),
        ),
      );
    }

    final subjects = actions.map((action) => action.subjectId).toSet();

    final total = actions.fold<int>(
      0,
      (sum, action) => sum + action.delta.abs(),
    );

    return AvoraRecoveryPlan(
      incidentId: incidentId,
      generatedAt: generatedAt,
      actions: List.unmodifiable(actions),
      affectedSubjects: subjects.length,
      totalAbsoluteCorrectionUnits: total,
    );
  }

  static AvoraRecoveryExecutionPreview preview({
    required AvoraRecoveryPlan plan,
    required List<AvoraRecoveryExecutionRecord> existingExecutions,
  }) {
    final appliedKeys = existingExecutions
        .where(
          (record) =>
              record.incidentId == plan.incidentId &&
              record.status == AvoraRecoveryActionStatus.applied,
        )
        .map((record) => record.actionKey)
        .toSet();

    final alreadyApplied = plan.actions
        .where(
          (action) => appliedKeys.contains(action.actionKey),
        )
        .length;

    return AvoraRecoveryExecutionPreview(
      pendingActions: plan.actions.length - alreadyApplied,
      alreadyAppliedActions: alreadyApplied,
      affectedSubjects: plan.affectedSubjects,
      totalAbsoluteCorrectionUnits: plan.totalAbsoluteCorrectionUnits,
    );
  }

  static bool canExecute({
    required AvoraIncident incident,
    required AvoraRecoveryPlan plan,
  }) {
    return incident.id == plan.incidentId && incident.approvedForExecution;
  }

  static List<AvoraRecoveryAction> pendingActions({
    required AvoraRecoveryPlan plan,
    required List<AvoraRecoveryExecutionRecord> existingExecutions,
  }) {
    final appliedKeys = existingExecutions
        .where(
          (record) =>
              record.incidentId == plan.incidentId &&
              record.status == AvoraRecoveryActionStatus.applied,
        )
        .map((record) => record.actionKey)
        .toSet();

    return plan.actions
        .where(
          (action) => !appliedKeys.contains(action.actionKey),
        )
        .toList(growable: false);
  }

  /// If invalid credited value was already spent, do not blindly
  /// seize unrelated legitimate balance or force impossible values.
  static AvoraBalanceRecoveryAllocation allocateBalanceRecovery({
    required int invalidCreditUnits,
    required int currentlyRecoverableUnits,
  }) {
    if (invalidCreditUnits < 0 || currentlyRecoverableUnits < 0) {
      throw ArgumentError(
        'Recovery values must not be negative.',
      );
    }

    final immediate = currentlyRecoverableUnits > invalidCreditUnits
        ? invalidCreditUnits
        : currentlyRecoverableUnits;

    return AvoraBalanceRecoveryAllocation(
      invalidCreditUnits: invalidCreditUnits,
      immediateRecoveryUnits: immediate,
      deferredRecoveryUnits: invalidCreditUnits - immediate,
    );
  }

  /// Historical events are never deleted or rewritten.
  static bool deletesOriginalEconomicHistory() {
    return false;
  }

  /// A retry with the same stable action keys must not double-apply.
  static bool isIdempotentByActionKey() {
    return true;
  }
}
