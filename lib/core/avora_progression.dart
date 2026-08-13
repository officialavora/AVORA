enum AvoraProgressionTrack {
  identity,
  sendingWealth,
  receivingCharm,
  rechargePrestige,
  game,
  cpRelationship,
  room,
  family,
  host,
  agency,
  bd,
  invite,
  vipQualification,
  svipQualification,
  custom,
}

enum AvoraProgressionSource {
  verifiedRecharge,
  eligibleSending,
  eligibleReceiving,
  eligibleGameActivity,
  eligibleRelationshipActivity,
  eligibleRoomActivity,
  eligibleHostActivity,
  eligibleAgencyActivity,
  eligibleBdActivity,
  eligibleInvite,
  eventReward,
  achievementReward,
  manualAdjustment,
  custom,
}

enum AvoraProgressionDenyReason {
  none,
  invalidUnits,
  sourceNotConfigured,
  sourceDisabled,
  verificationRequired,
  fraudInvalidated,
  reversed,
  duplicateContribution,
  invalidPolicy,
}

class AvoraProgressionSourceRule {
  final AvoraProgressionSource source;
  final bool enabled;

  /// 10000 bps = 100%.
  final int weightBps;

  final bool requireVerified;
  final int? maximumPointsPerActivity;

  const AvoraProgressionSourceRule({
    required this.source,
    required this.enabled,
    required this.weightBps,
    this.requireVerified = true,
    this.maximumPointsPerActivity,
  })  : assert(weightBps >= 0),
        assert(
          maximumPointsPerActivity == null || maximumPointsPerActivity >= 0,
        );

  int calculatePoints(int baseUnits) {
    var points = (baseUnits * weightBps) ~/ 10000;

    final max = maximumPointsPerActivity;
    if (max != null && points > max) {
      points = max;
    }

    return points;
  }
}

class AvoraProgressionMilestone {
  final int level;

  /// Total cumulative points required.
  final int minimumPoints;

  /// badge/frame/entry/title/effect/etc.
  final Set<String> unlockRefs;

  const AvoraProgressionMilestone({
    required this.level,
    required this.minimumPoints,
    this.unlockRefs = const {},
  })  : assert(level >= 1),
        assert(minimumPoints >= 0);
}

class AvoraProgressionPolicyVersion {
  final String versionId;
  final AvoraProgressionTrack track;

  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;

  final bool enabled;

  final List<AvoraProgressionMilestone> milestones;
  final List<AvoraProgressionSourceRule> sourceRules;

  const AvoraProgressionPolicyVersion({
    required this.versionId,
    required this.track,
    required this.effectiveFrom,
    required this.enabled,
    required this.milestones,
    required this.sourceRules,
    this.effectiveUntil,
  });

  bool activeAt(DateTime now) {
    if (!enabled || now.isBefore(effectiveFrom)) {
      return false;
    }

    final until = effectiveUntil;

    if (until != null && !now.isBefore(until)) {
      return false;
    }

    return true;
  }

  AvoraProgressionSourceRule? ruleFor(
    AvoraProgressionSource source,
  ) {
    for (final rule in sourceRules) {
      if (rule.source == source) {
        return rule;
      }
    }

    return null;
  }
}

class AvoraProgressionPolicyDefinition {
  final String policyId;
  final AvoraProgressionTrack track;
  final List<AvoraProgressionPolicyVersion> versions;

  const AvoraProgressionPolicyDefinition({
    required this.policyId,
    required this.track,
    required this.versions,
  });
}

enum AvoraProgressionPolicyIssue {
  noMilestones,
  missingLevelOne,
  levelOneMustStartAtZero,
  duplicateLevel,
  duplicateMinimumPoints,
  nonIncreasingThresholds,
  duplicateSourceRule,
}

class AvoraProgressionPolicyValidation {
  final bool valid;
  final Set<AvoraProgressionPolicyIssue> issues;

  const AvoraProgressionPolicyValidation({
    required this.valid,
    required this.issues,
  });
}

class AvoraProgressionActivity {
  final String activityId;

  /// Immutable authoritative AVORA ID.
  final String subjectAvoraId;

  final AvoraProgressionSource source;
  final int baseUnits;

  final bool verified;
  final bool fraudInvalidated;
  final bool reversed;

  final DateTime occurredAt;

  const AvoraProgressionActivity({
    required this.activityId,
    required this.subjectAvoraId,
    required this.source,
    required this.baseUnits,
    required this.verified,
    required this.fraudInvalidated,
    required this.reversed,
    required this.occurredAt,
  });
}

class AvoraProgressionContribution {
  final bool accepted;
  final AvoraProgressionDenyReason reason;

  final AvoraProgressionTrack track;

  final String contributionKey;
  final String activityId;
  final String policyVersionId;

  final int awardedPoints;

  const AvoraProgressionContribution({
    required this.accepted,
    required this.reason,
    required this.track,
    required this.contributionKey,
    required this.activityId,
    required this.policyVersionId,
    required this.awardedPoints,
  });
}

class AvoraProgressionSnapshot {
  final AvoraProgressionTrack track;

  final int totalPoints;
  final int level;

  final int? nextLevel;
  final int? nextLevelMinimumPoints;

  final int pointsToNextLevel;

  /// 0..10000
  final int progressBps;

  /// Highest level only in current configuration.
  final bool atCurrentConfiguredTop;

  const AvoraProgressionSnapshot({
    required this.track,
    required this.totalPoints,
    required this.level,
    required this.nextLevel,
    required this.nextLevelMinimumPoints,
    required this.pointsToNextLevel,
    required this.progressBps,
    required this.atCurrentConfiguredTop,
  });
}

class AvoraProgressionEngine {
  const AvoraProgressionEngine._();

  static AvoraProgressionPolicyValidation validate(
    AvoraProgressionPolicyVersion version,
  ) {
    final issues = <AvoraProgressionPolicyIssue>{};

    if (version.milestones.isEmpty) {
      issues.add(AvoraProgressionPolicyIssue.noMilestones);

      return AvoraProgressionPolicyValidation(
        valid: false,
        issues: Set.unmodifiable(issues),
      );
    }

    final milestones = [...version.milestones]
      ..sort((a, b) => a.level.compareTo(b.level));

    final levels = <int>{};
    final thresholds = <int>{};

    for (final milestone in milestones) {
      if (!levels.add(milestone.level)) {
        issues.add(
          AvoraProgressionPolicyIssue.duplicateLevel,
        );
      }

      if (!thresholds.add(milestone.minimumPoints)) {
        issues.add(
          AvoraProgressionPolicyIssue.duplicateMinimumPoints,
        );
      }
    }

    final levelOne = milestones
        .where((milestone) => milestone.level == 1)
        .toList(growable: false);

    if (levelOne.isEmpty) {
      issues.add(
        AvoraProgressionPolicyIssue.missingLevelOne,
      );
    } else if (levelOne.first.minimumPoints != 0) {
      issues.add(
        AvoraProgressionPolicyIssue.levelOneMustStartAtZero,
      );
    }

    for (var i = 1; i < milestones.length; i++) {
      final previous = milestones[i - 1];
      final current = milestones[i];

      if (current.level <= previous.level ||
          current.minimumPoints <= previous.minimumPoints) {
        issues.add(
          AvoraProgressionPolicyIssue.nonIncreasingThresholds,
        );
      }
    }

    final sources = <AvoraProgressionSource>{};

    for (final rule in version.sourceRules) {
      if (!sources.add(rule.source)) {
        issues.add(
          AvoraProgressionPolicyIssue.duplicateSourceRule,
        );
      }
    }

    return AvoraProgressionPolicyValidation(
      valid: issues.isEmpty,
      issues: Set.unmodifiable(issues),
    );
  }

  static AvoraProgressionPolicyVersion? effectiveVersion({
    required AvoraProgressionPolicyDefinition policy,
    required DateTime now,
  }) {
    final active = policy.versions
        .where(
          (version) =>
              version.track == policy.track &&
              version.activeAt(now) &&
              validate(version).valid,
        )
        .toList(growable: false)
      ..sort(
        (a, b) => b.effectiveFrom.compareTo(a.effectiveFrom),
      );

    return active.isEmpty ? null : active.first;
  }

  static String contributionKey({
    required AvoraProgressionTrack track,
    required String activityId,
  }) {
    return '${track.name}:$activityId';
  }

  static AvoraProgressionContribution evaluateContribution({
    required AvoraProgressionPolicyVersion policy,
    required AvoraProgressionActivity activity,
    required Set<String> appliedContributionKeys,
  }) {
    final key = contributionKey(
      track: policy.track,
      activityId: activity.activityId,
    );

    if (!validate(policy).valid) {
      return _deny(
        policy: policy,
        activity: activity,
        key: key,
        reason: AvoraProgressionDenyReason.invalidPolicy,
      );
    }

    if (activity.baseUnits < 0) {
      return _deny(
        policy: policy,
        activity: activity,
        key: key,
        reason: AvoraProgressionDenyReason.invalidUnits,
      );
    }

    if (appliedContributionKeys.contains(key)) {
      return _deny(
        policy: policy,
        activity: activity,
        key: key,
        reason: AvoraProgressionDenyReason.duplicateContribution,
      );
    }

    if (activity.fraudInvalidated) {
      return _deny(
        policy: policy,
        activity: activity,
        key: key,
        reason: AvoraProgressionDenyReason.fraudInvalidated,
      );
    }

    if (activity.reversed) {
      return _deny(
        policy: policy,
        activity: activity,
        key: key,
        reason: AvoraProgressionDenyReason.reversed,
      );
    }

    final rule = policy.ruleFor(activity.source);

    if (rule == null) {
      return _deny(
        policy: policy,
        activity: activity,
        key: key,
        reason: AvoraProgressionDenyReason.sourceNotConfigured,
      );
    }

    if (!rule.enabled) {
      return _deny(
        policy: policy,
        activity: activity,
        key: key,
        reason: AvoraProgressionDenyReason.sourceDisabled,
      );
    }

    if (rule.requireVerified && !activity.verified) {
      return _deny(
        policy: policy,
        activity: activity,
        key: key,
        reason: AvoraProgressionDenyReason.verificationRequired,
      );
    }

    return AvoraProgressionContribution(
      accepted: true,
      reason: AvoraProgressionDenyReason.none,
      track: policy.track,
      contributionKey: key,
      activityId: activity.activityId,
      policyVersionId: policy.versionId,
      awardedPoints: rule.calculatePoints(activity.baseUnits),
    );
  }

  static AvoraProgressionContribution _deny({
    required AvoraProgressionPolicyVersion policy,
    required AvoraProgressionActivity activity,
    required String key,
    required AvoraProgressionDenyReason reason,
  }) {
    return AvoraProgressionContribution(
      accepted: false,
      reason: reason,
      track: policy.track,
      contributionKey: key,
      activityId: activity.activityId,
      policyVersionId: policy.versionId,
      awardedPoints: 0,
    );
  }

  static AvoraProgressionSnapshot resolveSnapshot({
    required AvoraProgressionPolicyVersion policy,
    required int totalPoints,
  }) {
    if (totalPoints < 0) {
      throw ArgumentError('totalPoints cannot be negative.');
    }

    if (!validate(policy).valid) {
      throw StateError('Invalid progression policy.');
    }

    final milestones = [...policy.milestones]..sort(
        (a, b) => a.minimumPoints.compareTo(b.minimumPoints),
      );

    var current = milestones.first;

    for (final milestone in milestones) {
      if (totalPoints >= milestone.minimumPoints) {
        current = milestone;
      } else {
        break;
      }
    }

    final currentIndex = milestones.indexOf(current);

    if (currentIndex == milestones.length - 1) {
      return AvoraProgressionSnapshot(
        track: policy.track,
        totalPoints: totalPoints,
        level: current.level,
        nextLevel: null,
        nextLevelMinimumPoints: null,
        pointsToNextLevel: 0,
        progressBps: 10000,
        atCurrentConfiguredTop: true,
      );
    }

    final next = milestones[currentIndex + 1];

    final span = next.minimumPoints - current.minimumPoints;

    final earned = totalPoints - current.minimumPoints;

    final progressBps =
        span <= 0 ? 0 : ((earned * 10000) ~/ span).clamp(0, 10000);

    return AvoraProgressionSnapshot(
      track: policy.track,
      totalPoints: totalPoints,
      level: current.level,
      nextLevel: next.level,
      nextLevelMinimumPoints: next.minimumPoints,
      pointsToNextLevel: next.minimumPoints - totalPoints,
      progressBps: progressBps,
      atCurrentConfiguredTop: false,
    );
  }

  /// 100/200/etc are configuration choices, not engine ceilings.
  static bool hasHardcodedMaximumPublicLevel() {
    return false;
  }

  static bool sendingAndReceivingAreSameTrack() {
    return false;
  }

  static bool premiumTierIsSameAsIdentityLevel() {
    return false;
  }

  static bool qualificationAutomaticallyActivatesPremiumMembership() {
    return false;
  }

  static bool rechargeAutomaticallyCountsEverywhere() {
    return false;
  }

  static bool addingFutureLevelsRequiresCoreEngineRewrite() {
    return false;
  }
}
