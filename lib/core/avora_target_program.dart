enum AvoraTargetSubjectType {
  userId,
  room,
  host,
  agency,
  bd,
  family,
  seller,
  merchant,
  custom,
}

enum AvoraTargetCadence {
  daily,
  weekly,
  fifteenDays,
  monthly,
  custom,
}

enum AvoraTargetProgramStatus {
  draft,
  active,
  paused,
  ended,
}

enum AvoraTargetCarryPolicy {
  /// AVORA preferred behavior:
  /// settle completed target and carry valid remainder.
  carryUnsettledRemainder,

  /// Some special programs may intentionally reset.
  resetAtPeriodEnd,
}

enum AvoraTargetSettlementMode {
  /// Pay only the highest newly reached milestone.
  highestReachedOnly,

  /// Pay every newly reached milestone.
  cumulativeNewMilestones,
}

enum AvoraTargetPercentageBase {
  milestoneTarget,
  periodEligibleUnits,
  externalRewardBase,
}

class AvoraTargetMilestone {
  final String id;

  /// Server-authoritative target units.
  /// Example only: 500000, 1000000, 1500000.
  final int targetUnits;

  /// Fixed salary/reward units.
  final int fixedRewardUnits;

  /// 100 = 1%, 500 = 5%, 10000 = 100%.
  final int rewardPercentBps;

  final AvoraTargetPercentageBase percentageBase;

  final bool enabled;

  const AvoraTargetMilestone({
    required this.id,
    required this.targetUnits,
    this.fixedRewardUnits = 0,
    this.rewardPercentBps = 0,
    this.percentageBase = AvoraTargetPercentageBase.milestoneTarget,
    this.enabled = true,
  })  : assert(targetUnits > 0),
        assert(fixedRewardUnits >= 0),
        assert(
          rewardPercentBps >= 0 && rewardPercentBps <= 10000,
        );
}

class AvoraTargetProgram {
  final String id;

  final String name;

  final AvoraTargetSubjectType subjectType;

  final AvoraTargetCadence cadence;

  final AvoraTargetProgramStatus status;

  final AvoraTargetCarryPolicy carryPolicy;

  final AvoraTargetSettlementMode settlementMode;

  /// Example: salary_usd_units, reward_points,
  /// diamonds, promo_coins, etc.
  final String rewardValueType;

  final List<AvoraTargetMilestone> milestones;

  const AvoraTargetProgram({
    required this.id,
    required this.name,
    required this.subjectType,
    required this.cadence,
    required this.status,
    required this.carryPolicy,
    required this.settlementMode,
    required this.rewardValueType,
    required this.milestones,
  });
}

class AvoraTargetProgressState {
  final String programId;

  final String subjectId;

  /// Highest target already settled/paid.
  final int settledThroughUnits;

  /// Genuine unpaid remainder carried from previous period.
  final int carryUnits;

  const AvoraTargetProgressState({
    required this.programId,
    required this.subjectId,
    this.settledThroughUnits = 0,
    this.carryUnits = 0,
  })  : assert(settledThroughUnits >= 0),
        assert(carryUnits >= 0);
}

class AvoraTargetMilestoneReward {
  final String milestoneId;

  final int targetUnits;

  final int fixedRewardUnits;

  final int percentageRewardUnits;

  final int totalRewardUnits;

  const AvoraTargetMilestoneReward({
    required this.milestoneId,
    required this.targetUnits,
    required this.fixedRewardUnits,
    required this.percentageRewardUnits,
    required this.totalRewardUnits,
  });
}

class AvoraTargetNextProgress {
  final int previousMilestoneUnits;

  final int nextMilestoneUnits;

  /// Size of the next segment.
  final int segmentRequiredUnits;

  /// Valid progress already made inside this segment.
  final int segmentEarnedUnits;

  final int remainingUnits;

  const AvoraTargetNextProgress({
    required this.previousMilestoneUnits,
    required this.nextMilestoneUnits,
    required this.segmentRequiredUnits,
    required this.segmentEarnedUnits,
    required this.remainingUnits,
  });
}

class AvoraTargetSettlementResult {
  final int periodEligibleUnits;

  /// settled-through + carry-in + current period.
  final int availableCumulativeUnits;

  final List<AvoraTargetMilestone> newlyReachedMilestones;

  final List<AvoraTargetMilestoneReward> rewards;

  final AvoraTargetProgressState nextState;

  final AvoraTargetNextProgress? nextProgress;

  const AvoraTargetSettlementResult({
    required this.periodEligibleUnits,
    required this.availableCumulativeUnits,
    required this.newlyReachedMilestones,
    required this.rewards,
    required this.nextState,
    required this.nextProgress,
  });
}

class AvoraTargetProgramEngine {
  const AvoraTargetProgramEngine._();

  static List<AvoraTargetMilestone> _sortedEnabled(
    AvoraTargetProgram program,
  ) {
    final result = program.milestones
        .where((milestone) => milestone.enabled)
        .toList(growable: true);

    result.sort(
      (a, b) => a.targetUnits.compareTo(b.targetUnits),
    );

    return result;
  }

  static int _percentageReward({
    required AvoraTargetMilestone milestone,
    required int periodEligibleUnits,
    required int externalRewardBaseUnits,
  }) {
    int base;

    switch (milestone.percentageBase) {
      case AvoraTargetPercentageBase.milestoneTarget:
        base = milestone.targetUnits;

      case AvoraTargetPercentageBase.periodEligibleUnits:
        base = periodEligibleUnits;

      case AvoraTargetPercentageBase.externalRewardBase:
        base = externalRewardBaseUnits;
    }

    return (base * milestone.rewardPercentBps) ~/ 10000;
  }

  static AvoraTargetNextProgress? nextProgress({
    required AvoraTargetProgram program,
    required int settledThroughUnits,
    required int carryUnits,
  }) {
    final milestones = _sortedEnabled(program);

    AvoraTargetMilestone? next;

    for (final milestone in milestones) {
      if (milestone.targetUnits > settledThroughUnits) {
        next = milestone;
        break;
      }
    }

    if (next == null) {
      return null;
    }

    final previous = settledThroughUnits;

    final segmentRequired = next.targetUnits - previous;

    final earned = carryUnits > segmentRequired ? segmentRequired : carryUnits;

    final remaining = segmentRequired - earned;

    return AvoraTargetNextProgress(
      previousMilestoneUnits: previous,
      nextMilestoneUnits: next.targetUnits,
      segmentRequiredUnits: segmentRequired,
      segmentEarnedUnits: earned,
      remainingUnits: remaining,
    );
  }

  static AvoraTargetSettlementResult settlePeriod({
    required AvoraTargetProgram program,
    required AvoraTargetProgressState state,

    /// Only valid/server-eligible activity belongs here.
    required int periodEligibleUnits,

    /// Used only by milestones configured with
    /// externalRewardBase.
    int externalRewardBaseUnits = 0,
  }) {
    if (periodEligibleUnits < 0) {
      throw ArgumentError.value(
        periodEligibleUnits,
        'periodEligibleUnits',
        'must not be negative',
      );
    }

    if (externalRewardBaseUnits < 0) {
      throw ArgumentError.value(
        externalRewardBaseUnits,
        'externalRewardBaseUnits',
        'must not be negative',
      );
    }

    final milestones = _sortedEnabled(program);

    final available =
        state.settledThroughUnits + state.carryUnits + periodEligibleUnits;

    final newlyReached = milestones
        .where(
          (milestone) =>
              milestone.targetUnits > state.settledThroughUnits &&
              milestone.targetUnits <= available,
        )
        .toList(growable: false);

    List<AvoraTargetMilestone> payable;

    switch (program.settlementMode) {
      case AvoraTargetSettlementMode.highestReachedOnly:
        payable = newlyReached.isEmpty ? const [] : [newlyReached.last];

      case AvoraTargetSettlementMode.cumulativeNewMilestones:
        payable = newlyReached;
    }

    final rewards = payable.map((milestone) {
      final percentageReward = _percentageReward(
        milestone: milestone,
        periodEligibleUnits: periodEligibleUnits,
        externalRewardBaseUnits: externalRewardBaseUnits,
      );

      return AvoraTargetMilestoneReward(
        milestoneId: milestone.id,
        targetUnits: milestone.targetUnits,
        fixedRewardUnits: milestone.fixedRewardUnits,
        percentageRewardUnits: percentageReward,
        totalRewardUnits: milestone.fixedRewardUnits + percentageReward,
      );
    }).toList(growable: false);

    final highestReachedUnits = newlyReached.isEmpty
        ? state.settledThroughUnits
        : newlyReached.last.targetUnits;

    late AvoraTargetProgressState nextState;

    switch (program.carryPolicy) {
      case AvoraTargetCarryPolicy.carryUnsettledRemainder:
        final carryOut = available - highestReachedUnits;

        nextState = AvoraTargetProgressState(
          programId: state.programId,
          subjectId: state.subjectId,
          settledThroughUnits: highestReachedUnits,
          carryUnits: carryOut,
        );

      case AvoraTargetCarryPolicy.resetAtPeriodEnd:
        nextState = AvoraTargetProgressState(
          programId: state.programId,
          subjectId: state.subjectId,
          settledThroughUnits: 0,
          carryUnits: 0,
        );
    }

    return AvoraTargetSettlementResult(
      periodEligibleUnits: periodEligibleUnits,
      availableCumulativeUnits: available,
      newlyReachedMilestones: newlyReached,
      rewards: rewards,
      nextState: nextState,
      nextProgress: nextProgress(
        program: program,
        settledThroughUnits: nextState.settledThroughUnits,
        carryUnits: nextState.carryUnits,
      ),
    );
  }
}
