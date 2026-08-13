enum AvoraEventCompetitionTrack {
  sending,
  receiving,
  invitation,
  recharge,
  gamer,
}

enum AvoraEventRankingRule {
  topN,
  threshold,
  topNWithThreshold,
}

enum AvoraEventGameMetric {
  eligibleSpend,
  wins,
  score,
  rounds,
  eventPoints,
}

class AvoraEventCompetitionDefinition {
  final String id;
  final String eventId;

  final AvoraEventCompetitionTrack track;

  final AvoraEventRankingRule rankingRule;

  /// Used when rankingRule includes Top-N.
  final int? topN;

  /// Minimum eligible score required for reward/ranking.
  final int minScore;

  /// Track can have its own active window inside the parent event.
  final DateTime startsAt;
  final DateTime endsAt;

  /// Reward definition IDs belonging to this track.
  final List<String> rewardIds;

  /// Gift-based tracks can use separate Standard/Lucky weights.
  /// 10000 basis points = 100%.
  final int standardGiftWeightBps;
  final int luckyGiftWeightBps;

  /// Competitive event rewards should normally reject self-gift farming.
  final bool allowSelfGift;

  /// Used only when track == gamer.
  final AvoraEventGameMetric? gameMetric;

  final bool enabled;

  AvoraEventCompetitionDefinition({
    required this.id,
    required this.eventId,
    required this.track,
    required this.rankingRule,
    required this.startsAt,
    required this.endsAt,
    this.topN,
    this.minScore = 0,
    this.rewardIds = const [],
    this.standardGiftWeightBps = 10000,
    this.luckyGiftWeightBps = 1000,
    this.allowSelfGift = false,
    this.gameMetric,
    this.enabled = true,
  })  : assert(
          !endsAt.isBefore(startsAt),
          'Competition end must not be before start.',
        ),
        assert(minScore >= 0),
        assert(
          standardGiftWeightBps >= 0 && standardGiftWeightBps <= 10000,
        ),
        assert(
          luckyGiftWeightBps >= 0 && luckyGiftWeightBps <= 10000,
        ),
        assert(
          rankingRule == AvoraEventRankingRule.threshold ||
              (topN != null && topN > 0),
          'Top-N ranking requires topN > 0.',
        ),
        assert(
          track != AvoraEventCompetitionTrack.gamer || gameMetric != null,
          'Gamer track requires a game metric.',
        );

  bool isActiveAt(DateTime time) {
    if (!enabled) {
      return false;
    }

    return !time.isBefore(startsAt) && !time.isAfter(endsAt);
  }

  bool get isGiftTrack =>
      track == AvoraEventCompetitionTrack.sending ||
      track == AvoraEventCompetitionTrack.receiving;

  bool get isInvitationTrack => track == AvoraEventCompetitionTrack.invitation;

  bool get isRechargeTrack => track == AvoraEventCompetitionTrack.recharge;

  bool get isGamerTrack => track == AvoraEventCompetitionTrack.gamer;
}
