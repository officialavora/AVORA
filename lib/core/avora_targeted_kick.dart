import 'avora_kick_abuse.dart';

enum AvoraTargetedKickLevel {
  normal,
  warning,
  cooldown,
  blocked,
}

class AvoraTargetedKickDecision {
  final AvoraTargetedKickLevel level;
  final bool allowKickAgainstTarget;
  final bool requiresHumanReview;
  final bool storeEvidence;
  final int targetedKicks;
  final DateTime? cooldownUntil;

  const AvoraTargetedKickDecision({
    required this.level,
    required this.allowKickAgainstTarget,
    required this.requiresHumanReview,
    required this.storeEvidence,
    required this.targetedKicks,
    this.cooldownUntil,
  });
}

class AvoraTargetedKickPolicy {
  const AvoraTargetedKickPolicy._();

  static AvoraTargetedKickDecision evaluate({
    required String actorUserId,
    required String targetUserId,
    required String roomId,
    required List<AvoraKickEvent> events,
    required DateTime now,
  }) {
    final relevant = events.where((event) {
      return event.actorUserId == actorUserId &&
          event.targetUserId == targetUserId &&
          event.roomId == roomId &&
          !event.occurredAt.isAfter(now);
    }).toList();

    int countWithin(Duration window) {
      final cutoff = now.subtract(window);

      return relevant.where((event) {
        return !event.occurredAt.isBefore(cutoff);
      }).length;
    }

    final kicks10m = countWithin(const Duration(minutes: 10));
    final kicks20m = countWithin(const Duration(minutes: 20));
    final kicks60m = countWithin(const Duration(minutes: 60));

    if (kicks60m >= 8) {
      return AvoraTargetedKickDecision(
        level: AvoraTargetedKickLevel.blocked,
        allowKickAgainstTarget: false,
        requiresHumanReview: true,
        storeEvidence: true,
        targetedKicks: kicks60m,
        cooldownUntil: now.add(const Duration(hours: 1)),
      );
    }

    if (kicks20m >= 5) {
      return AvoraTargetedKickDecision(
        level: AvoraTargetedKickLevel.cooldown,
        allowKickAgainstTarget: false,
        requiresHumanReview: false,
        storeEvidence: true,
        targetedKicks: kicks20m,
        cooldownUntil: now.add(const Duration(minutes: 10)),
      );
    }

    if (kicks10m >= 3) {
      return AvoraTargetedKickDecision(
        level: AvoraTargetedKickLevel.warning,
        allowKickAgainstTarget: true,
        requiresHumanReview: false,
        storeEvidence: true,
        targetedKicks: kicks10m,
      );
    }

    return AvoraTargetedKickDecision(
      level: AvoraTargetedKickLevel.normal,
      allowKickAgainstTarget: true,
      requiresHumanReview: false,
      storeEvidence: false,
      targetedKicks: kicks10m,
    );
  }
}
