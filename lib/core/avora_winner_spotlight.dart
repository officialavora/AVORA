import 'avora_leaderboard.dart';

enum AvoraWinnerSpotlightCategory {
  topSender,
  topReceiver,
  bestCouple,
  topRecharge,
  topRoom,
  topFamily,
  topAgency,
  topGame,
  topInvite,
  eventWinner,
  custom,
}

enum AvoraWinnerSpotlightPresentationMode {
  sequential,
  combined,
}

enum AvoraWinnerSpotlightStatus {
  active,
  paused,
  revoked,
}

class AvoraWinnerSpotlightConfig {
  final bool enabled;

  final AvoraWinnerSpotlightPresentationMode presentationMode;

  /// Used when multiple categories are shown together.
  final int maxCombinedCards;

  const AvoraWinnerSpotlightConfig({
    this.enabled = true,
    this.presentationMode = AvoraWinnerSpotlightPresentationMode.sequential,
    this.maxCombinedCards = 3,
  }) : assert(maxCombinedCards > 0);
}

class AvoraWinnerSpotlightDefinition {
  final String id;

  final AvoraWinnerSpotlightCategory category;

  /// Uses the shared server-authoritative leaderboard engine.
  final AvoraLeaderboardMetric metric;

  /// Example:
  /// lastWeek = completed weekly winner
  /// thisWeek = live/current weekly top
  final AvoraLeaderboardPeriod period;

  final AvoraWinnerSpotlightStatus status;

  /// Higher value is shown first when priorities differ.
  final int priority;

  /// Used for deterministic category rotation.
  final int rotationOrder;

  /// Usually 1 for Top Sender/Best Couple etc.
  /// Can be larger later for Top 3 presentations.
  final int winnerCount;

  final int minimumScore;

  /// Example for Best Couple:
  /// require CP relationship level >= configured milestone.
  final int minimumEligibilityLevel;

  final bool requireVerifiedWinner;

  final bool dismissible;

  /// Avoid showing the same campaign too frequently.
  final Duration cooldown;

  /// Null means no hard impression limit.
  final int? maxImpressionsPerUser;

  final DateTime startsAt;

  /// Null means active until manually paused/revoked.
  final DateTime? endsAt;

  const AvoraWinnerSpotlightDefinition({
    required this.id,
    required this.category,
    required this.metric,
    required this.period,
    required this.startsAt,
    this.status = AvoraWinnerSpotlightStatus.active,
    this.priority = 0,
    this.rotationOrder = 0,
    this.winnerCount = 1,
    this.minimumScore = 0,
    this.minimumEligibilityLevel = 0,
    this.requireVerifiedWinner = true,
    this.dismissible = true,
    this.cooldown = const Duration(hours: 12),
    this.maxImpressionsPerUser,
    this.endsAt,
  })  : assert(winnerCount > 0),
        assert(minimumScore >= 0),
        assert(minimumEligibilityLevel >= 0),
        assert(
          maxImpressionsPerUser == null || maxImpressionsPerUser > 0,
        );

  bool isActiveAt(DateTime now) {
    if (status != AvoraWinnerSpotlightStatus.active) {
      return false;
    }

    if (now.isBefore(startsAt)) {
      return false;
    }

    final end = endsAt;

    if (end != null && now.isAfter(end)) {
      return false;
    }

    return true;
  }
}

class AvoraWinnerEntityPresentation {
  /// User ID, CP pair ID, room ID, agency ID, etc.
  final String entityId;

  final String entityType;

  final String displayName;

  /// One member for a user winner.
  /// Two members can be used for Best Couple.
  final List<String> memberUserIds;

  /// One or more DP/profile-photo references.
  final List<String> profilePhotoRefs;

  /// Optional vanity IDs shown in UI.
  final List<String> vanityIds;

  final String? countryCode;

  /// Profile, CP page, room, agency, event, etc.
  final String? deepLink;

  /// Server-authoritative verification result.
  final bool verified;

  /// CP level, creator level, event eligibility level, etc.
  final int eligibilityLevel;

  const AvoraWinnerEntityPresentation({
    required this.entityId,
    required this.entityType,
    required this.displayName,
    required this.memberUserIds,
    required this.profilePhotoRefs,
    this.vanityIds = const [],
    this.countryCode,
    this.deepLink,
    this.verified = false,
    this.eligibilityLevel = 0,
  }) : assert(eligibilityLevel >= 0);
}

class AvoraWinnerSpotlightUserHistory {
  final String definitionId;

  final int impressions;

  final DateTime? lastShownAt;

  final bool dismissed;

  const AvoraWinnerSpotlightUserHistory({
    required this.definitionId,
    this.impressions = 0,
    this.lastShownAt,
    this.dismissed = false,
  }) : assert(impressions >= 0);
}

class AvoraWinnerSpotlightCard {
  final String definitionId;

  final AvoraWinnerSpotlightCategory category;

  final AvoraLeaderboardPeriod period;

  final int rank;

  final int score;

  final AvoraWinnerEntityPresentation winner;

  const AvoraWinnerSpotlightCard({
    required this.definitionId,
    required this.category,
    required this.period,
    required this.rank,
    required this.score,
    required this.winner,
  });
}

class AvoraWinnerSpotlightSelection {
  final AvoraWinnerSpotlightPresentationMode presentationMode;

  final List<AvoraWinnerSpotlightCard> cards;

  const AvoraWinnerSpotlightSelection({
    required this.presentationMode,
    required this.cards,
  });
}

class AvoraWinnerSpotlightEngine {
  const AvoraWinnerSpotlightEngine._();

  static bool canShowDefinitionToUser({
    required AvoraWinnerSpotlightDefinition definition,
    required DateTime now,
    AvoraWinnerSpotlightUserHistory? history,
  }) {
    if (!definition.isActiveAt(now)) {
      return false;
    }

    if (history == null) {
      return true;
    }

    if (definition.dismissible && history.dismissed) {
      return false;
    }

    final maxImpressions = definition.maxImpressionsPerUser;

    if (maxImpressions != null && history.impressions >= maxImpressions) {
      return false;
    }

    final lastShownAt = history.lastShownAt;

    if (lastShownAt != null) {
      final elapsed = now.difference(lastShownAt);

      if (elapsed < definition.cooldown) {
        return false;
      }
    }

    return true;
  }

  static List<AvoraWinnerSpotlightCard> eligibleCards({
    required List<AvoraWinnerSpotlightDefinition> definitions,
    required List<AvoraScoreRecord> scoreRecords,
    required Map<String, AvoraWinnerEntityPresentation> presentationsByEntityId,
    required Map<String, AvoraWinnerSpotlightUserHistory> historyByDefinitionId,
    required DateTime now,
  }) {
    final cards = <_RankedSpotlightCard>[];

    for (final definition in definitions) {
      final history = historyByDefinitionId[definition.id];

      if (!canShowDefinitionToUser(
        definition: definition,
        now: now,
        history: history,
      )) {
        continue;
      }

      final leaderboard = AvoraLeaderboardEngine.build(
        records: scoreRecords,
        config: AvoraLeaderboardConfig(
          metric: definition.metric,
          topLimit: definition.winnerCount,
        ),
        period: definition.period,
        now: now,
      );

      for (final entry in leaderboard) {
        if (entry.score < definition.minimumScore) {
          continue;
        }

        final presentation = presentationsByEntityId[entry.entityId];

        if (presentation == null) {
          continue;
        }

        if (definition.requireVerifiedWinner && !presentation.verified) {
          continue;
        }

        if (presentation.eligibilityLevel <
            definition.minimumEligibilityLevel) {
          continue;
        }

        cards.add(
          _RankedSpotlightCard(
            priority: definition.priority,
            rotationOrder: definition.rotationOrder,
            card: AvoraWinnerSpotlightCard(
              definitionId: definition.id,
              category: definition.category,
              period: definition.period,
              rank: entry.rank,
              score: entry.score,
              winner: presentation,
            ),
          ),
        );
      }
    }

    cards.sort((a, b) {
      final priorityCompare = b.priority.compareTo(a.priority);

      if (priorityCompare != 0) {
        return priorityCompare;
      }

      final rotationCompare = a.rotationOrder.compareTo(b.rotationOrder);

      if (rotationCompare != 0) {
        return rotationCompare;
      }

      final rankCompare = a.card.rank.compareTo(b.card.rank);

      if (rankCompare != 0) {
        return rankCompare;
      }

      return a.card.definitionId.compareTo(
        b.card.definitionId,
      );
    });

    return cards.map((item) => item.card).toList(growable: false);
  }

  static AvoraWinnerSpotlightSelection select({
    required AvoraWinnerSpotlightConfig config,
    required List<AvoraWinnerSpotlightDefinition> definitions,
    required List<AvoraScoreRecord> scoreRecords,
    required Map<String, AvoraWinnerEntityPresentation> presentationsByEntityId,
    required Map<String, AvoraWinnerSpotlightUserHistory> historyByDefinitionId,
    required DateTime now,

    /// Used to rotate sequential launches:
    /// Sender -> CP -> Recharge -> Sender...
    String? lastShownDefinitionId,
  }) {
    if (!config.enabled) {
      return AvoraWinnerSpotlightSelection(
        presentationMode: config.presentationMode,
        cards: const [],
      );
    }

    final eligible = eligibleCards(
      definitions: definitions,
      scoreRecords: scoreRecords,
      presentationsByEntityId: presentationsByEntityId,
      historyByDefinitionId: historyByDefinitionId,
      now: now,
    );

    if (eligible.isEmpty) {
      return AvoraWinnerSpotlightSelection(
        presentationMode: config.presentationMode,
        cards: const [],
      );
    }

    switch (config.presentationMode) {
      case AvoraWinnerSpotlightPresentationMode.combined:
        final uniqueDefinitions = <String, AvoraWinnerSpotlightCard>{};

        for (final card in eligible) {
          uniqueDefinitions.putIfAbsent(
            card.definitionId,
            () => card,
          );
        }

        return AvoraWinnerSpotlightSelection(
          presentationMode: config.presentationMode,
          cards: uniqueDefinitions.values
              .take(config.maxCombinedCards)
              .toList(growable: false),
        );

      case AvoraWinnerSpotlightPresentationMode.sequential:
        final uniqueDefinitions = <AvoraWinnerSpotlightCard>[];

        final seen = <String>{};

        for (final card in eligible) {
          if (seen.add(card.definitionId)) {
            uniqueDefinitions.add(card);
          }
        }

        if (lastShownDefinitionId == null) {
          return AvoraWinnerSpotlightSelection(
            presentationMode: config.presentationMode,
            cards: [uniqueDefinitions.first],
          );
        }

        final lastIndex = uniqueDefinitions.indexWhere(
          (card) => card.definitionId == lastShownDefinitionId,
        );

        final nextIndex =
            lastIndex < 0 ? 0 : (lastIndex + 1) % uniqueDefinitions.length;

        return AvoraWinnerSpotlightSelection(
          presentationMode: config.presentationMode,
          cards: [uniqueDefinitions[nextIndex]],
        );
    }
  }
}

class _RankedSpotlightCard {
  final int priority;
  final int rotationOrder;
  final AvoraWinnerSpotlightCard card;

  const _RankedSpotlightCard({
    required this.priority,
    required this.rotationOrder,
    required this.card,
  });
}
