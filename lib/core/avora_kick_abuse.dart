enum AvoraKickProtectionLevel {
  normal,
  warning,
  cooldown,
  blocked,
  escalated,
}

class AvoraKickEvent {
  final String id;
  final String roomId;

  final String actorUserId;
  final String targetUserId;

  final DateTime occurredAt;
  final String? reason;

  const AvoraKickEvent({
    required this.id,
    required this.roomId,
    required this.actorUserId,
    required this.targetUserId,
    required this.occurredAt,
    this.reason,
  });
}

class AvoraKickProtectionDecision {
  final AvoraKickProtectionLevel level;

  final bool allowKick;
  final bool requiresHumanReview;
  final bool storeEvidence;

  final int kicksInWindow;
  final DateTime? cooldownUntil;

  const AvoraKickProtectionDecision({
    required this.level,
    required this.allowKick,
    required this.requiresHumanReview,
    required this.storeEvidence,
    required this.kicksInWindow,
    this.cooldownUntil,
  });
}

class AvoraKickAbusePolicy {
  const AvoraKickAbusePolicy._();

  static AvoraKickProtectionDecision evaluate({
    required String actorUserId,
    required String roomId,
    required List<AvoraKickEvent> events,
    required DateTime now,
  }) {
    final relevant = events.where((event) {
      return event.actorUserId == actorUserId &&
          event.roomId == roomId &&
          !event.occurredAt.isAfter(now);
    }).toList();

    int countWithin(Duration window) {
      final cutoff = now.subtract(window);

      return relevant.where((event) {
        return !event.occurredAt.isBefore(cutoff);
      }).length;
    }

    final kicks2m = countWithin(const Duration(minutes: 2));
    final kicks5m = countWithin(const Duration(minutes: 5));
    final kicks10m = countWithin(const Duration(minutes: 10));
    final kicks30m = countWithin(const Duration(minutes: 30));

    if (kicks30m >= 35) {
      return AvoraKickProtectionDecision(
        level: AvoraKickProtectionLevel.escalated,
        allowKick: false,
        requiresHumanReview: true,
        storeEvidence: true,
        kicksInWindow: kicks30m,
        cooldownUntil: now.add(const Duration(hours: 6)),
      );
    }

    if (kicks10m >= 20) {
      return AvoraKickProtectionDecision(
        level: AvoraKickProtectionLevel.blocked,
        allowKick: false,
        requiresHumanReview: true,
        storeEvidence: true,
        kicksInWindow: kicks10m,
        cooldownUntil: now.add(const Duration(minutes: 30)),
      );
    }

    if (kicks5m >= 12) {
      return AvoraKickProtectionDecision(
        level: AvoraKickProtectionLevel.cooldown,
        allowKick: false,
        requiresHumanReview: false,
        storeEvidence: true,
        kicksInWindow: kicks5m,
        cooldownUntil: now.add(const Duration(minutes: 5)),
      );
    }

    if (kicks2m >= 6) {
      return AvoraKickProtectionDecision(
        level: AvoraKickProtectionLevel.warning,
        allowKick: true,
        requiresHumanReview: false,
        storeEvidence: true,
        kicksInWindow: kicks2m,
      );
    }

    return AvoraKickProtectionDecision(
      level: AvoraKickProtectionLevel.normal,
      allowKick: true,
      requiresHumanReview: false,
      storeEvidence: false,
      kicksInWindow: kicks2m,
    );
  }
}
