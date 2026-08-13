enum AvoraNewcomerGraceMode {
  none,
  firstCycle,
  firstNDays,
  explicitUntil,
}

enum AvoraHierarchicalQualificationLevel {
  agencyOwner,
  bd,
  admin,
  superAdmin,
  manager,
  custom,
}

enum AvoraHierarchicalQualificationDenyReason {
  invalidPolicy,
  invalidSnapshot,
  timeRequirementNotMet,
  distinctTargetAchieversNotMet,
  qualifyingChildCountNotMet,
  aggregateMinimumNotMet,
}

class AvoraHierarchicalQualificationPolicy {
  const AvoraHierarchicalQualificationPolicy({
    required this.policyId,
    required this.version,
    required this.cycleId,
    required this.level,
    required this.currencyCode,
    required this.effectiveFromUtc,
    this.effectiveUntilUtc,
    this.enabled = true,
    this.timeRequirementEnabled = false,
    this.requiredValidDays = 0,
    this.requiredMinutesPerValidDay = 0,
    this.newcomerGraceMode = AvoraNewcomerGraceMode.none,
    this.newcomerGraceDays = 0,
    this.newcomerGraceUntilUtc,
    this.minimumDistinctVerifiedTargetAchievers = 0,
    this.minimumQualifyingChildCount = 0,
    this.perChildMinimumValueMinor = 0,
    this.aggregateMinimumValueMinor,
    this.requireEveryCountedChildMeetsFloor = true,
  });

  final String policyId;
  final int version;

  /// Existing reward/salary cycle ID.
  final String cycleId;

  final AvoraHierarchicalQualificationLevel level;

  /// Example: USD. Monetary values are stored in minor units.
  final String currencyCode;

  final DateTime effectiveFromUtc;
  final DateTime? effectiveUntilUtc;

  final bool enabled;

  /// Owner can completely disable attendance/time requirements.
  final bool timeRequirementEnabled;

  /// Number of valid working days required during the cycle.
  final int requiredValidDays;

  /// Example: 120 = two valid hours per required day.
  final int requiredMinutesPerValidDay;

  final AvoraNewcomerGraceMode newcomerGraceMode;

  /// Used only with firstNDays.
  final int newcomerGraceDays;

  /// Used only with explicitUntil.
  final DateTime? newcomerGraceUntilUtc;

  /// Example Agency Owner policy: 5 verified target achievers.
  final int minimumDistinctVerifiedTargetAchievers;

  /// Example BD policy: minimum 5 qualifying agencies.
  final int minimumQualifyingChildCount;

  /// Example: every counted agency must individually achieve USD 100.
  final int perChildMinimumValueMinor;

  /// Optional additional total minimum.
  final int? aggregateMinimumValueMinor;

  /// If true, overperformance by one child cannot compensate for another
  /// child being below its individual minimum floor.
  final bool requireEveryCountedChildMeetsFloor;

  String get snapshotKey => '$policyId:v$version';

  bool get valid {
    if (policyId.trim().isEmpty ||
        cycleId.trim().isEmpty ||
        currencyCode.trim().isEmpty ||
        version <= 0 ||
        !effectiveFromUtc.isUtc ||
        requiredValidDays < 0 ||
        requiredMinutesPerValidDay < 0 ||
        minimumDistinctVerifiedTargetAchievers < 0 ||
        minimumQualifyingChildCount < 0 ||
        perChildMinimumValueMinor < 0 ||
        (aggregateMinimumValueMinor != null &&
            aggregateMinimumValueMinor! < 0)) {
      return false;
    }

    if (effectiveUntilUtc != null) {
      if (!effectiveUntilUtc!.isUtc ||
          !effectiveUntilUtc!.isAfter(effectiveFromUtc)) {
        return false;
      }
    }

    if (newcomerGraceMode == AvoraNewcomerGraceMode.firstNDays &&
        newcomerGraceDays <= 0) {
      return false;
    }

    if (newcomerGraceMode == AvoraNewcomerGraceMode.explicitUntil &&
        (newcomerGraceUntilUtc == null || !newcomerGraceUntilUtc!.isUtc)) {
      return false;
    }

    return true;
  }
}

class AvoraQualificationDaySnapshot {
  const AvoraQualificationDaySnapshot({
    required this.dayKey,
    required this.validByExistingTargetRules,
    required this.activeMinutes,
    required this.serverVerified,
  });

  /// Stable business-day key produced by existing business-time logic.
  final String dayKey;

  /// Existing Target/Activity engine remains authoritative for base validity.
  final bool validByExistingTargetRules;

  final int activeMinutes;

  /// Client cannot invent attendance.
  final bool serverVerified;
}

class AvoraQualificationChildSnapshot {
  const AvoraQualificationChildSnapshot({
    required this.entityId,
    required this.verified,
    required this.eligibleActivity,
    required this.targetAchieved,
    required this.qualifyingValueMinor,
  });

  /// Immutable AVORA ID, Agency ID, BD scope ID, etc.
  final String entityId;

  /// Verified identity/entity requirement.
  final bool verified;

  /// False for refunded/reversed/fraud-blocked/non-qualifying activity.
  final bool eligibleActivity;

  /// Whether this child/user completed an accepted target.
  final bool targetAchieved;

  /// Server-finalized economic work for this cycle.
  final int qualifyingValueMinor;
}

class AvoraHierarchicalQualificationSnapshot {
  const AvoraHierarchicalQualificationSnapshot({
    required this.subjectId,
    required this.joinedAtUtc,
    required this.isFirstEligibleCycle,
    required this.days,
    required this.children,
  });

  final String subjectId;
  final DateTime joinedAtUtc;

  /// Supplied by existing membership/role/cycle logic.
  final bool isFirstEligibleCycle;

  final List<AvoraQualificationDaySnapshot> days;

  /// Agency members, child agencies, child BDs, etc.
  final List<AvoraQualificationChildSnapshot> children;
}

class AvoraHierarchicalQualificationResult {
  const AvoraHierarchicalQualificationResult({
    required this.eligible,
    required this.denyReasons,
    required this.policySnapshotKey,
    required this.timeRequirementWaivedForNewcomer,
    required this.validDaysMeetingTimeRequirement,
    required this.distinctVerifiedTargetAchievers,
    required this.qualifyingChildCount,
    required this.aggregateQualifyingValueMinor,
    required this.qualifyingChildEntityIds,
  });

  final bool eligible;

  final Set<AvoraHierarchicalQualificationDenyReason> denyReasons;

  final String policySnapshotKey;

  final bool timeRequirementWaivedForNewcomer;

  final int validDaysMeetingTimeRequirement;

  final int distinctVerifiedTargetAchievers;

  final int qualifyingChildCount;

  final int aggregateQualifyingValueMinor;

  final Set<String> qualifyingChildEntityIds;
}

class AvoraHierarchicalQualificationEngine {
  const AvoraHierarchicalQualificationEngine._();

  static bool newcomerGraceApplies({
    required AvoraHierarchicalQualificationPolicy policy,
    required AvoraHierarchicalQualificationSnapshot snapshot,
    required DateTime serverNowUtc,
  }) {
    switch (policy.newcomerGraceMode) {
      case AvoraNewcomerGraceMode.none:
        return false;

      case AvoraNewcomerGraceMode.firstCycle:
        return snapshot.isFirstEligibleCycle;

      case AvoraNewcomerGraceMode.firstNDays:
        if (!snapshot.joinedAtUtc.isUtc || !serverNowUtc.isUtc) {
          return false;
        }

        final graceEnd = snapshot.joinedAtUtc.add(
          Duration(days: policy.newcomerGraceDays),
        );

        return serverNowUtc.isBefore(graceEnd);

      case AvoraNewcomerGraceMode.explicitUntil:
        final until = policy.newcomerGraceUntilUtc;
        if (until == null || !serverNowUtc.isUtc) {
          return false;
        }

        return !serverNowUtc.isAfter(until);
    }
  }

  static AvoraHierarchicalQualificationResult evaluate({
    required AvoraHierarchicalQualificationPolicy policy,
    required AvoraHierarchicalQualificationSnapshot snapshot,
    required DateTime serverNowUtc,
  }) {
    final reasons = <AvoraHierarchicalQualificationDenyReason>{};

    if (!policy.valid || !policy.enabled || !serverNowUtc.isUtc) {
      reasons.add(
        AvoraHierarchicalQualificationDenyReason.invalidPolicy,
      );
    }

    if (snapshot.subjectId.trim().isEmpty ||
        !snapshot.joinedAtUtc.isUtc ||
        snapshot.children.any(
          (child) =>
              child.entityId.trim().isEmpty || child.qualifyingValueMinor < 0,
        ) ||
        snapshot.days.any(
          (day) => day.dayKey.trim().isEmpty || day.activeMinutes < 0,
        )) {
      reasons.add(
        AvoraHierarchicalQualificationDenyReason.invalidSnapshot,
      );
    }

    final grace = newcomerGraceApplies(
      policy: policy,
      snapshot: snapshot,
      serverNowUtc: serverNowUtc,
    );

    final validDays = snapshot.days.where((day) {
      if (!day.serverVerified || !day.validByExistingTargetRules) {
        return false;
      }

      if (!policy.timeRequirementEnabled || grace) {
        return true;
      }

      return day.activeMinutes >= policy.requiredMinutesPerValidDay;
    }).length;

    final timePassed = !policy.timeRequirementEnabled ||
        grace ||
        validDays >= policy.requiredValidDays;

    if (!timePassed) {
      reasons.add(
        AvoraHierarchicalQualificationDenyReason.timeRequirementNotMet,
      );
    }

    final eligibleChildren = snapshot.children.where(
      (child) => child.verified && child.eligibleActivity,
    );

    final targetAchieverIds = eligibleChildren
        .where((child) => child.targetAchieved)
        .map((child) => child.entityId)
        .toSet();

    if (targetAchieverIds.length <
        policy.minimumDistinctVerifiedTargetAchievers) {
      reasons.add(
        AvoraHierarchicalQualificationDenyReason.distinctTargetAchieversNotMet,
      );
    }

    final childrenMeetingIndividualFloor = eligibleChildren.where(
      (child) =>
          policy.perChildMinimumValueMinor <= 0 ||
          child.qualifyingValueMinor >= policy.perChildMinimumValueMinor,
    );

    final countedChildren = policy.requireEveryCountedChildMeetsFloor
        ? childrenMeetingIndividualFloor
        : eligibleChildren;

    final qualifyingChildIds =
        countedChildren.map((child) => child.entityId).toSet();

    if (qualifyingChildIds.length < policy.minimumQualifyingChildCount) {
      reasons.add(
        AvoraHierarchicalQualificationDenyReason.qualifyingChildCountNotMet,
      );
    }

    /// Aggregate is calculated independently.
    /// It can never repair a failed per-child count/floor requirement.
    final aggregateValue = eligibleChildren.fold<int>(
      0,
      (total, child) => total + child.qualifyingValueMinor,
    );

    final aggregateMinimum = policy.aggregateMinimumValueMinor;

    if (aggregateMinimum != null && aggregateValue < aggregateMinimum) {
      reasons.add(
        AvoraHierarchicalQualificationDenyReason.aggregateMinimumNotMet,
      );
    }

    return AvoraHierarchicalQualificationResult(
      eligible: reasons.isEmpty,
      denyReasons: Set.unmodifiable(reasons),
      policySnapshotKey: policy.snapshotKey,
      timeRequirementWaivedForNewcomer: grace,
      validDaysMeetingTimeRequirement: validDays,
      distinctVerifiedTargetAchievers: targetAchieverIds.length,
      qualifyingChildCount: qualifyingChildIds.length,
      aggregateQualifyingValueMinor: aggregateValue,
      qualifyingChildEntityIds: Set.unmodifiable(qualifyingChildIds),
    );
  }

  /// Existing Target Program remains authoritative for target completion.
  static bool targetEngineRemainsAuthoritative() => true;

  /// Existing Activity Time system remains authoritative for raw activity.
  static bool activityTimeEngineRemainsAuthoritative() => true;

  /// Refund/reversal/fraud filtering must happen before activity reaches here.
  static bool onlyVerifiedEligibleActivityCanQualify() => true;

  /// Parent title/hierarchy alone never creates salary eligibility.
  static bool hierarchyAloneCreatesSalary() => false;

  /// When per-child floor is enabled, one strong child cannot compensate
  /// for another child that fails its individual minimum.
  static bool crossChildCompensationAllowedWhenFloorRequired() => false;

  /// This layer decides qualification only; it never credits money/Coins.
  static bool directlyMutatesLedger() => false;

  /// Eligible result must flow into the shared cycle-end settlement system.
  static bool universalAutoSettlementHandoffRequired() => true;

  /// Running policy changes use versioned/effective-dated snapshots.
  static bool historicalQualificationCanBeSilentlyRewritten() => false;

  static bool clientCanSelfQualify() => false;
}
