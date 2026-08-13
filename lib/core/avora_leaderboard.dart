enum AvoraLeaderboardMetric {
  sending,
  receiving,
  recharge,
  cp,
  agency,
  family,
  relation,
  room,
  game,
  invite,
  host,
  bd,
}

enum AvoraLeaderboardPeriod {
  today,
  yesterday,
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  allTime,
}

class AvoraLeaderboardEntry {
  final String entityId;

  /// User, room, family, agency, CP pair, etc.
  final String entityType;

  final int score;

  final int rank;

  const AvoraLeaderboardEntry({
    required this.entityId,
    required this.entityType,
    required this.score,
    required this.rank,
  })  : assert(score >= 0),
        assert(rank > 0);
}

class AvoraLeaderboardConfig {
  final AvoraLeaderboardMetric metric;

  /// Examples: 5, 10, 50, 100.
  final int topLimit;

  /// Score updates must already pass verification/fraud rules.
  final bool requireVerifiedEligibility;

  const AvoraLeaderboardConfig({
    required this.metric,
    this.topLimit = 100,
    this.requireVerifiedEligibility = true,
  }) : assert(topLimit > 0);
}

class AvoraScoreRecord {
  final String entityId;
  final String entityType;

  final AvoraLeaderboardMetric metric;

  final int score;

  /// Server timestamp of the eligible score event.
  final DateTime occurredAt;

  const AvoraScoreRecord({
    required this.entityId,
    required this.entityType,
    required this.metric,
    required this.score,
    required this.occurredAt,
  }) : assert(score >= 0);
}

class AvoraLeaderboardTimeRange {
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// All-Time has no visible date range.
  final bool lifetime;

  const AvoraLeaderboardTimeRange({
    required this.startsAt,
    required this.endsAt,
    required this.lifetime,
  });
}

class AvoraLeaderboardPeriodResolver {
  const AvoraLeaderboardPeriodResolver._();

  static AvoraLeaderboardTimeRange resolve({
    required AvoraLeaderboardPeriod period,
    required DateTime now,
  }) {
    final dayStart = DateTime(
      now.year,
      now.month,
      now.day,
    );

    /// Monday = 1 in Dart.
    final weekStart = dayStart.subtract(
      Duration(days: dayStart.weekday - DateTime.monday),
    );

    final monthStart = DateTime(
      now.year,
      now.month,
      1,
    );

    switch (period) {
      case AvoraLeaderboardPeriod.today:
        return AvoraLeaderboardTimeRange(
          startsAt: dayStart,
          endsAt: dayStart.add(const Duration(days: 1)),
          lifetime: false,
        );

      case AvoraLeaderboardPeriod.yesterday:
        final start = dayStart.subtract(
          const Duration(days: 1),
        );

        return AvoraLeaderboardTimeRange(
          startsAt: start,
          endsAt: dayStart,
          lifetime: false,
        );

      case AvoraLeaderboardPeriod.thisWeek:
        return AvoraLeaderboardTimeRange(
          startsAt: weekStart,
          endsAt: weekStart.add(
            const Duration(days: 7),
          ),
          lifetime: false,
        );

      case AvoraLeaderboardPeriod.lastWeek:
        final start = weekStart.subtract(
          const Duration(days: 7),
        );

        return AvoraLeaderboardTimeRange(
          startsAt: start,
          endsAt: weekStart,
          lifetime: false,
        );

      case AvoraLeaderboardPeriod.thisMonth:
        final nextMonth = now.month == 12
            ? DateTime(now.year + 1, 1, 1)
            : DateTime(now.year, now.month + 1, 1);

        return AvoraLeaderboardTimeRange(
          startsAt: monthStart,
          endsAt: nextMonth,
          lifetime: false,
        );

      case AvoraLeaderboardPeriod.lastMonth:
        final start = now.month == 1
            ? DateTime(now.year - 1, 12, 1)
            : DateTime(now.year, now.month - 1, 1);

        return AvoraLeaderboardTimeRange(
          startsAt: start,
          endsAt: monthStart,
          lifetime: false,
        );

      case AvoraLeaderboardPeriod.allTime:
        return const AvoraLeaderboardTimeRange(
          startsAt: null,
          endsAt: null,
          lifetime: true,
        );
    }
  }
}

class AvoraLeaderboardEngine {
  const AvoraLeaderboardEngine._();

  static List<AvoraLeaderboardEntry> build({
    required List<AvoraScoreRecord> records,
    required AvoraLeaderboardConfig config,
    required AvoraLeaderboardPeriod period,
    required DateTime now,
  }) {
    final range = AvoraLeaderboardPeriodResolver.resolve(
      period: period,
      now: now,
    );

    final totals = <String, int>{};
    final types = <String, String>{};

    for (final record in records) {
      if (record.metric != config.metric) {
        continue;
      }

      if (!range.lifetime) {
        final start = range.startsAt!;
        final end = range.endsAt!;

        if (record.occurredAt.isBefore(start) ||
            !record.occurredAt.isBefore(end)) {
          continue;
        }
      }

      totals.update(
        record.entityId,
        (value) => value + record.score,
        ifAbsent: () => record.score,
      );

      types[record.entityId] = record.entityType;
    }

    final sorted = totals.entries.toList()
      ..sort((a, b) {
        final scoreCompare = b.value.compareTo(a.value);

        if (scoreCompare != 0) {
          return scoreCompare;
        }

        return a.key.compareTo(b.key);
      });

    final limited = sorted.take(config.topLimit).toList();

    return List.generate(
      limited.length,
      (index) {
        final item = limited[index];

        return AvoraLeaderboardEntry(
          entityId: item.key,
          entityType: types[item.key] ?? 'unknown',
          score: item.value,
          rank: index + 1,
        );
      },
      growable: false,
    );
  }
}
