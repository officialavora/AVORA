import 'avora_relationship.dart';

enum AvoraRelationshipRecoveryStatus {
  eligible,
  coolingDown,
  active,
  completed,
  expired,
  cancelled,
  notEligible,
}

class AvoraRelationshipArchive {
  final String priorRelationshipId;

  final AvoraRelationshipType type;

  final String userAId;
  final String userBId;

  final int archivedPeakLevel;
  final int archivedEligiblePoints;

  final DateTime endedAt;

  final bool endedNormally;

  const AvoraRelationshipArchive({
    required this.priorRelationshipId,
    required this.type,
    required this.userAId,
    required this.userBId,
    required this.archivedPeakLevel,
    required this.archivedEligiblePoints,
    required this.endedAt,
    this.endedNormally = true,
  })  : assert(archivedPeakLevel >= 0),
        assert(archivedEligiblePoints >= 0);

  bool matchesPair({
    required String firstUserId,
    required String secondUserId,
  }) {
    return (userAId == firstUserId && userBId == secondUserId) ||
        (userAId == secondUserId && userBId == firstUserId);
  }
}

class AvoraRelationshipRecoveryConfig {
  final bool enabled;

  /// Example: 1000 = 10% of archived eligible points.
  /// 10000 = 100%.
  final int requiredRecoveryBps;

  final int minimumRecoveryPoints;
  final int? maximumRecoveryPoints;

  final Duration cooldownAfterBreakup;
  final Duration recoveryValidityWindow;

  final bool requireVerifiedUsers;

  const AvoraRelationshipRecoveryConfig({
    this.enabled = true,
    this.requiredRecoveryBps = 1000,
    this.minimumRecoveryPoints = 1000,
    this.maximumRecoveryPoints,
    this.cooldownAfterBreakup = const Duration(days: 1),
    this.recoveryValidityWindow = const Duration(days: 90),
    this.requireVerifiedUsers = true,
  })  : assert(
          requiredRecoveryBps >= 0 && requiredRecoveryBps <= 10000,
        ),
        assert(minimumRecoveryPoints >= 0),
        assert(
          maximumRecoveryPoints == null ||
              maximumRecoveryPoints >= minimumRecoveryPoints,
        );
}

class AvoraRelationshipRecoveryPlan {
  final String id;

  final String reconnectRelationshipId;
  final String priorRelationshipId;

  final AvoraRelationshipType type;

  final String userAId;
  final String userBId;

  final int archivedPeakLevel;
  final int archivedEligiblePoints;

  final int requiredRecoveryPoints;
  final int earnedRecoveryPoints;

  final DateTime createdAt;
  final DateTime expiresAt;

  final AvoraRelationshipRecoveryStatus status;

  final DateTime? completedAt;

  const AvoraRelationshipRecoveryPlan({
    required this.id,
    required this.reconnectRelationshipId,
    required this.priorRelationshipId,
    required this.type,
    required this.userAId,
    required this.userBId,
    required this.archivedPeakLevel,
    required this.archivedEligiblePoints,
    required this.requiredRecoveryPoints,
    required this.earnedRecoveryPoints,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    this.completedAt,
  })  : assert(archivedPeakLevel >= 0),
        assert(archivedEligiblePoints >= 0),
        assert(requiredRecoveryPoints >= 0),
        assert(earnedRecoveryPoints >= 0);

  int get remainingRecoveryPoints {
    final remaining = requiredRecoveryPoints - earnedRecoveryPoints;

    return remaining > 0 ? remaining : 0;
  }

  bool get isComplete => status == AvoraRelationshipRecoveryStatus.completed;

  double get progressRatio {
    if (requiredRecoveryPoints == 0) {
      return 1;
    }

    final ratio = earnedRecoveryPoints / requiredRecoveryPoints;

    return ratio > 1 ? 1 : ratio;
  }
}

enum AvoraRelationshipRecoveryDenyReason {
  none,
  recoveryDisabled,
  pairMismatch,
  relationshipTypeMismatch,
  reconnectNotActive,
  usersNotVerified,
  blocked,
  stillCoolingDown,
  archiveExpired,
  invalidArchive,
}

class AvoraRelationshipRecoveryEligibility {
  final bool eligible;

  final AvoraRelationshipRecoveryStatus status;

  final AvoraRelationshipRecoveryDenyReason reason;

  final int requiredRecoveryPoints;

  const AvoraRelationshipRecoveryEligibility({
    required this.eligible,
    required this.status,
    required this.reason,
    required this.requiredRecoveryPoints,
  });
}

class AvoraRelationshipRecoveryEngine {
  const AvoraRelationshipRecoveryEngine._();

  static AvoraRelationshipRecoveryEligibility evaluate({
    required AvoraRelationshipArchive archive,
    required AvoraRelationshipRecord reconnectRelationship,
    required AvoraRelationshipRecoveryConfig config,
    required bool userAVerified,
    required bool userBVerified,
    required bool blockedEitherDirection,
    required DateTime now,
  }) {
    AvoraRelationshipRecoveryEligibility deny(
      AvoraRelationshipRecoveryStatus status,
      AvoraRelationshipRecoveryDenyReason reason,
    ) {
      return AvoraRelationshipRecoveryEligibility(
        eligible: false,
        status: status,
        reason: reason,
        requiredRecoveryPoints: 0,
      );
    }

    if (!config.enabled) {
      return deny(
        AvoraRelationshipRecoveryStatus.notEligible,
        AvoraRelationshipRecoveryDenyReason.recoveryDisabled,
      );
    }

    if (!archive.matchesPair(
      firstUserId: reconnectRelationship.userAId,
      secondUserId: reconnectRelationship.userBId,
    )) {
      return deny(
        AvoraRelationshipRecoveryStatus.notEligible,
        AvoraRelationshipRecoveryDenyReason.pairMismatch,
      );
    }

    if (archive.type != reconnectRelationship.type) {
      return deny(
        AvoraRelationshipRecoveryStatus.notEligible,
        AvoraRelationshipRecoveryDenyReason.relationshipTypeMismatch,
      );
    }

    if (!reconnectRelationship.isActive) {
      return deny(
        AvoraRelationshipRecoveryStatus.notEligible,
        AvoraRelationshipRecoveryDenyReason.reconnectNotActive,
      );
    }

    if (config.requireVerifiedUsers && (!userAVerified || !userBVerified)) {
      return deny(
        AvoraRelationshipRecoveryStatus.notEligible,
        AvoraRelationshipRecoveryDenyReason.usersNotVerified,
      );
    }

    if (blockedEitherDirection) {
      return deny(
        AvoraRelationshipRecoveryStatus.notEligible,
        AvoraRelationshipRecoveryDenyReason.blocked,
      );
    }

    final cooldownEnds = archive.endedAt.add(config.cooldownAfterBreakup);

    if (now.isBefore(cooldownEnds)) {
      return deny(
        AvoraRelationshipRecoveryStatus.coolingDown,
        AvoraRelationshipRecoveryDenyReason.stillCoolingDown,
      );
    }

    final recoveryExpires = archive.endedAt.add(config.recoveryValidityWindow);

    if (now.isAfter(recoveryExpires)) {
      return deny(
        AvoraRelationshipRecoveryStatus.expired,
        AvoraRelationshipRecoveryDenyReason.archiveExpired,
      );
    }

    if (archive.archivedEligiblePoints <= 0 || archive.archivedPeakLevel <= 0) {
      return deny(
        AvoraRelationshipRecoveryStatus.notEligible,
        AvoraRelationshipRecoveryDenyReason.invalidArchive,
      );
    }

    var required =
        (archive.archivedEligiblePoints * config.requiredRecoveryBps) ~/ 10000;

    if (required < config.minimumRecoveryPoints) {
      required = config.minimumRecoveryPoints;
    }

    final maximum = config.maximumRecoveryPoints;

    if (maximum != null && required > maximum) {
      required = maximum;
    }

    return AvoraRelationshipRecoveryEligibility(
      eligible: true,
      status: AvoraRelationshipRecoveryStatus.eligible,
      reason: AvoraRelationshipRecoveryDenyReason.none,
      requiredRecoveryPoints: required,
    );
  }

  static AvoraRelationshipRecoveryPlan createPlan({
    required String planId,
    required AvoraRelationshipArchive archive,
    required AvoraRelationshipRecord reconnectRelationship,
    required int requiredRecoveryPoints,
    required DateTime now,
    required Duration validityWindow,
  }) {
    return AvoraRelationshipRecoveryPlan(
      id: planId,
      reconnectRelationshipId: reconnectRelationship.id,
      priorRelationshipId: archive.priorRelationshipId,
      type: archive.type,
      userAId: archive.userAId,
      userBId: archive.userBId,
      archivedPeakLevel: archive.archivedPeakLevel,
      archivedEligiblePoints: archive.archivedEligiblePoints,
      requiredRecoveryPoints: requiredRecoveryPoints,
      earnedRecoveryPoints: 0,
      createdAt: now,
      expiresAt: now.add(validityWindow),
      status: AvoraRelationshipRecoveryStatus.active,
    );
  }

  static AvoraRelationshipRecoveryPlan applyEligiblePoints({
    required AvoraRelationshipRecoveryPlan plan,
    required int newlyEligiblePoints,
    required DateTime now,
  }) {
    if (plan.status != AvoraRelationshipRecoveryStatus.active) {
      return plan;
    }

    if (now.isAfter(plan.expiresAt)) {
      return _copy(
        plan,
        status: AvoraRelationshipRecoveryStatus.expired,
      );
    }

    if (newlyEligiblePoints <= 0) {
      return plan;
    }

    final earned = plan.earnedRecoveryPoints + newlyEligiblePoints;

    if (earned >= plan.requiredRecoveryPoints) {
      return _copy(
        plan,
        earnedRecoveryPoints: plan.requiredRecoveryPoints,
        status: AvoraRelationshipRecoveryStatus.completed,
        completedAt: now,
      );
    }

    return _copy(
      plan,
      earnedRecoveryPoints: earned,
    );
  }

  /// Recovery can restore only what the pair legitimately
  /// earned before breakup. It cannot grant a higher level.
  static int restoredLevel({
    required AvoraRelationshipRecoveryPlan plan,
  }) {
    return plan.isComplete ? plan.archivedPeakLevel : 0;
  }

  static int restoredEligiblePoints({
    required AvoraRelationshipRecoveryPlan plan,
  }) {
    return plan.isComplete ? plan.archivedEligiblePoints : 0;
  }

  static AvoraRelationshipRecoveryPlan _copy(
    AvoraRelationshipRecoveryPlan plan, {
    int? earnedRecoveryPoints,
    AvoraRelationshipRecoveryStatus? status,
    DateTime? completedAt,
  }) {
    return AvoraRelationshipRecoveryPlan(
      id: plan.id,
      reconnectRelationshipId: plan.reconnectRelationshipId,
      priorRelationshipId: plan.priorRelationshipId,
      type: plan.type,
      userAId: plan.userAId,
      userBId: plan.userBId,
      archivedPeakLevel: plan.archivedPeakLevel,
      archivedEligiblePoints: plan.archivedEligiblePoints,
      requiredRecoveryPoints: plan.requiredRecoveryPoints,
      earnedRecoveryPoints: earnedRecoveryPoints ?? plan.earnedRecoveryPoints,
      createdAt: plan.createdAt,
      expiresAt: plan.expiresAt,
      status: status ?? plan.status,
      completedAt: completedAt ?? plan.completedAt,
    );
  }
}
