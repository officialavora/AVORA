enum AvoraRelationshipType {
  cp,
  friendHand,
}

enum AvoraRelationshipStatus {
  pending,
  active,
  declined,
  ended,
  blocked,
}

class AvoraRelationshipRecord {
  final String id;

  final AvoraRelationshipType type;

  /// Immutable AVORA IDs.
  final String userAId;
  final String userBId;

  /// User who initiated the formal relationship request.
  final String requestedByUserId;

  final AvoraRelationshipStatus status;

  final DateTime requestedAt;
  final DateTime? activatedAt;
  final DateTime? endedAt;

  final String? endedByUserId;
  final String? endReason;

  const AvoraRelationshipRecord({
    required this.id,
    required this.type,
    required this.userAId,
    required this.userBId,
    required this.requestedByUserId,
    required this.status,
    required this.requestedAt,
    this.activatedAt,
    this.endedAt,
    this.endedByUserId,
    this.endReason,
  });

  bool containsUser(String userId) {
    return userAId == userId || userBId == userId;
  }

  String? otherUser(String userId) {
    if (userAId == userId) {
      return userBId;
    }

    if (userBId == userId) {
      return userAId;
    }

    return null;
  }

  bool get isActive => status == AvoraRelationshipStatus.active;

  AvoraRelationshipRecord accept({
    required String acceptedByUserId,
    required DateTime acceptedAt,
  }) {
    final other = otherUser(requestedByUserId);

    if (status != AvoraRelationshipStatus.pending ||
        other == null ||
        acceptedByUserId != other) {
      return this;
    }

    return AvoraRelationshipRecord(
      id: id,
      type: type,
      userAId: userAId,
      userBId: userBId,
      requestedByUserId: requestedByUserId,
      status: AvoraRelationshipStatus.active,
      requestedAt: requestedAt,
      activatedAt: acceptedAt,
    );
  }

  AvoraRelationshipRecord decline({
    required String declinedByUserId,
  }) {
    final other = otherUser(requestedByUserId);

    if (status != AvoraRelationshipStatus.pending ||
        other == null ||
        declinedByUserId != other) {
      return this;
    }

    return AvoraRelationshipRecord(
      id: id,
      type: type,
      userAId: userAId,
      userBId: userBId,
      requestedByUserId: requestedByUserId,
      status: AvoraRelationshipStatus.declined,
      requestedAt: requestedAt,
    );
  }

  AvoraRelationshipRecord end({
    required String endedByUserId,
    required DateTime endedAt,
    String? reason,
  }) {
    if (!containsUser(endedByUserId) || !isActive) {
      return this;
    }

    return AvoraRelationshipRecord(
      id: id,
      type: type,
      userAId: userAId,
      userBId: userBId,
      requestedByUserId: requestedByUserId,
      status: AvoraRelationshipStatus.ended,
      requestedAt: requestedAt,
      activatedAt: activatedAt,
      endedAt: endedAt,
      endedByUserId: endedByUserId,
      endReason: reason,
    );
  }
}

class AvoraRelationshipAffinity {
  final String userAId;
  final String userBId;

  /// Generic pair affinity can exist before
  /// a formal CP/Friend-Hand relationship is accepted.
  final int totalPoints;

  const AvoraRelationshipAffinity({
    required this.userAId,
    required this.userBId,
    required this.totalPoints,
  }) : assert(totalPoints >= 0);
}

class AvoraRelationshipGiftSignal {
  final String senderUserId;
  final String receiverUserId;

  /// Eligible confirmed gift economic/score units.
  final int giftUnits;

  final bool senderVerified;
  final bool receiverVerified;

  final bool selfGift;
  final bool refunded;
  final bool reversed;
  final bool promotionalOnly;
  final bool suspiciousCircularActivity;
  final bool validGift;

  const AvoraRelationshipGiftSignal({
    required this.senderUserId,
    required this.receiverUserId,
    required this.giftUnits,
    required this.senderVerified,
    required this.receiverVerified,
    this.selfGift = false,
    this.refunded = false,
    this.reversed = false,
    this.promotionalOnly = false,
    this.suspiciousCircularActivity = false,
    this.validGift = true,
  }) : assert(giftUnits >= 0);
}

class AvoraRelationshipScoringConfig {
  /// 10000 = 100% of eligible gift units.
  final int giftWeightBps;

  final bool requireVerifiedUsers;

  const AvoraRelationshipScoringConfig({
    this.giftWeightBps = 10000,
    this.requireVerifiedUsers = true,
  }) : assert(
          giftWeightBps >= 0 && giftWeightBps <= 10000,
        );
}

class AvoraRelationshipScoreDecision {
  final bool eligible;

  final int awardedPoints;

  final String reason;

  const AvoraRelationshipScoreDecision({
    required this.eligible,
    required this.awardedPoints,
    required this.reason,
  });
}

class AvoraRelationshipScoringPolicy {
  const AvoraRelationshipScoringPolicy._();

  static AvoraRelationshipScoreDecision evaluateGift({
    required AvoraRelationshipGiftSignal signal,
    AvoraRelationshipScoringConfig config =
        const AvoraRelationshipScoringConfig(),
  }) {
    if (!signal.validGift) {
      return const AvoraRelationshipScoreDecision(
        eligible: false,
        awardedPoints: 0,
        reason: 'invalid_gift',
      );
    }

    if (signal.selfGift || signal.senderUserId == signal.receiverUserId) {
      return const AvoraRelationshipScoreDecision(
        eligible: false,
        awardedPoints: 0,
        reason: 'self_gift_excluded',
      );
    }

    if (signal.refunded || signal.reversed) {
      return const AvoraRelationshipScoreDecision(
        eligible: false,
        awardedPoints: 0,
        reason: 'reversed_or_refunded',
      );
    }

    if (signal.promotionalOnly) {
      return const AvoraRelationshipScoreDecision(
        eligible: false,
        awardedPoints: 0,
        reason: 'promo_only_excluded',
      );
    }

    if (signal.suspiciousCircularActivity) {
      return const AvoraRelationshipScoreDecision(
        eligible: false,
        awardedPoints: 0,
        reason: 'circular_activity_excluded',
      );
    }

    if (config.requireVerifiedUsers &&
        (!signal.senderVerified || !signal.receiverVerified)) {
      return const AvoraRelationshipScoreDecision(
        eligible: false,
        awardedPoints: 0,
        reason: 'verified_users_required',
      );
    }

    final points = (signal.giftUnits * config.giftWeightBps) ~/ 10000;

    return AvoraRelationshipScoreDecision(
      eligible: true,
      awardedPoints: points,
      reason: 'eligible',
    );
  }
}

class AvoraRelationshipLevelThreshold {
  final int level;

  /// Minimum lifetime eligible relation points.
  final int minimumPoints;

  const AvoraRelationshipLevelThreshold({
    required this.level,
    required this.minimumPoints,
  })  : assert(level > 0),
        assert(minimumPoints >= 0);
}

class AvoraRelationshipLevelResult {
  final int level;
  final int totalPoints;

  final int? nextLevel;
  final int? nextLevelMinimumPoints;

  const AvoraRelationshipLevelResult({
    required this.level,
    required this.totalPoints,
    required this.nextLevel,
    required this.nextLevelMinimumPoints,
  });
}

class AvoraRelationshipLevelEngine {
  const AvoraRelationshipLevelEngine._();

  static AvoraRelationshipLevelResult resolve({
    required int totalPoints,
    required List<AvoraRelationshipLevelThreshold> thresholds,
  }) {
    assert(totalPoints >= 0);

    final sorted = [...thresholds]..sort(
        (a, b) => a.minimumPoints.compareTo(b.minimumPoints),
      );

    var currentLevel = 0;
    AvoraRelationshipLevelThreshold? next;

    for (final threshold in sorted) {
      if (totalPoints >= threshold.minimumPoints) {
        currentLevel = threshold.level;
      } else {
        next = threshold;
        break;
      }
    }

    return AvoraRelationshipLevelResult(
      level: currentLevel,
      totalPoints: totalPoints,
      nextLevel: next?.level,
      nextLevelMinimumPoints: next?.minimumPoints,
    );
  }
}

class AvoraRelationshipPolicy {
  const AvoraRelationshipPolicy._();

  static bool canCreateRequest({
    required String requesterUserId,
    required String targetUserId,
    required bool blockedEitherDirection,
    required bool requesterVerified,
    required bool targetVerified,
  }) {
    if (requesterUserId == targetUserId) {
      return false;
    }

    if (blockedEitherDirection) {
      return false;
    }

    return requesterVerified && targetVerified;
  }

  /// Eligible gifting can build affinity,
  /// but never silently activates a formal CP/Friend-Hand.
  static bool giftAutomaticallyCreatesFormalRelationship() {
    return false;
  }
}
