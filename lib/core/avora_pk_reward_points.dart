import 'avora_pk_competition.dart';

enum AvoraPkRewardPointOutcomeType {
  none,
  win,
  loss,
  draw,
  forfeit,
}

/// Versioned admin-controlled PK reward policy.
///
/// This does NOT replace AVORA PK competition scoring.
/// Existing AvoraPkUserMatchOutcome remains authoritative for
/// winner/loser/draw/forfeit validity and competition pointDelta.
class AvoraPkRewardPointRule {
  const AvoraPkRewardPointRule({
    required this.ruleId,
    required this.version,
    required this.active,
    required this.participationPoints,
    required this.winPoints,
    required this.lossPoints,
    required this.drawPoints,
    required this.forfeitPoints,
    this.winStreakBonusPerStep = 0,
    this.maxWinStreakBonus,
    this.multiplierBasisPoints = 10000,
    this.maxPointsPerPk,
    this.dailyPointsCap,
    this.countryCode = '',
    this.roomId = '',
    this.eventKey = '',
    required this.effectiveFromUtc,
    this.effectiveUntilUtc,
    required this.configuredByAvoraId,
    required this.reasonCode,
  });

  final String ruleId;
  final int version;
  final bool active;

  /// Added to valid completed win/loss/draw outcomes.
  /// Forfeit intentionally does not automatically receive participation points.
  final int participationPoints;

  final int winPoints;
  final int lossPoints;
  final int drawPoints;

  /// Recommended production default is zero.
  final int forfeitPoints;

  /// Example:
  /// winStreak=1 -> 0 bonus steps
  /// winStreak=2 -> 1 bonus step
  /// winStreak=3 -> 2 bonus steps
  final int winStreakBonusPerStep;
  final int? maxWinStreakBonus;

  /// 10000 = 1.00x
  /// 15000 = 1.50x
  /// 20000 = 2.00x
  final int multiplierBasisPoints;

  final int? maxPointsPerPk;
  final int? dailyPointsCap;

  /// Empty scope means global.
  final String countryCode;
  final String roomId;
  final String eventKey;

  final DateTime effectiveFromUtc;
  final DateTime? effectiveUntilUtc;

  /// Immutable configuration audit identity.
  final String configuredByAvoraId;
  final String reasonCode;

  bool get valid {
    if (ruleId.trim().isEmpty ||
        version <= 0 ||
        participationPoints < 0 ||
        winPoints < 0 ||
        lossPoints < 0 ||
        drawPoints < 0 ||
        forfeitPoints < 0 ||
        winStreakBonusPerStep < 0 ||
        multiplierBasisPoints < 0 ||
        configuredByAvoraId.trim().isEmpty ||
        reasonCode.trim().isEmpty) {
      return false;
    }

    final streakCap = maxWinStreakBonus;
    if (streakCap != null && streakCap < 0) {
      return false;
    }

    final pkCap = maxPointsPerPk;
    if (pkCap != null && pkCap < 0) {
      return false;
    }

    final dailyCap = dailyPointsCap;
    if (dailyCap != null && dailyCap < 0) {
      return false;
    }

    final until = effectiveUntilUtc;
    if (until != null && !until.toUtc().isAfter(effectiveFromUtc.toUtc())) {
      return false;
    }

    return true;
  }

  bool appliesTo({
    required String actualCountryCode,
    required String actualRoomId,
    required String actualEventKey,
    required DateTime atUtc,
  }) {
    if (!valid || !active) {
      return false;
    }

    final at = atUtc.toUtc();

    if (at.isBefore(effectiveFromUtc.toUtc())) {
      return false;
    }

    final until = effectiveUntilUtc;
    if (until != null && !at.isBefore(until.toUtc())) {
      return false;
    }

    final configuredCountry = countryCode.trim().toUpperCase();
    final actualCountry = actualCountryCode.trim().toUpperCase();

    if (configuredCountry.isNotEmpty && configuredCountry != actualCountry) {
      return false;
    }

    final configuredRoom = roomId.trim();
    final actualRoom = actualRoomId.trim();

    if (configuredRoom.isNotEmpty && configuredRoom != actualRoom) {
      return false;
    }

    final configuredEvent = eventKey.trim();
    final actualEvent = actualEventKey.trim();

    if (configuredEvent.isNotEmpty && configuredEvent != actualEvent) {
      return false;
    }

    return true;
  }

  int specificityScore({
    required String actualCountryCode,
    required String actualRoomId,
    required String actualEventKey,
  }) {
    var score = 0;

    final configuredCountry = countryCode.trim().toUpperCase();
    if (configuredCountry.isNotEmpty &&
        configuredCountry == actualCountryCode.trim().toUpperCase()) {
      score += 1;
    }

    final configuredRoom = roomId.trim();
    if (configuredRoom.isNotEmpty && configuredRoom == actualRoomId.trim()) {
      score += 2;
    }

    final configuredEvent = eventKey.trim();
    if (configuredEvent.isNotEmpty &&
        configuredEvent == actualEventKey.trim()) {
      score += 4;
    }

    return score;
  }
}

class AvoraPkRewardPointResult {
  const AvoraPkRewardPointResult({
    required this.userAvoraId,
    required this.ruleMatched,
    required this.eligible,
    required this.outcomeType,
    required this.ruleId,
    required this.ruleVersion,
    required this.participationPoints,
    required this.outcomePoints,
    required this.streakBonusPoints,
    required this.multiplierBasisPoints,
    required this.pointsBeforeCaps,
    required this.points,
    required this.perPkCapApplied,
    required this.dailyCapApplied,
    required this.pointsAlreadyEarnedToday,
    required this.competitionPointDelta,
  });

  final String userAvoraId;

  final bool ruleMatched;
  final bool eligible;
  final AvoraPkRewardPointOutcomeType outcomeType;

  /// Immutable policy snapshot.
  final String ruleId;
  final int ruleVersion;

  final int participationPoints;
  final int outcomePoints;
  final int streakBonusPoints;
  final int multiplierBasisPoints;

  final int pointsBeforeCaps;
  final int points;

  final bool perPkCapApplied;
  final bool dailyCapApplied;

  final int pointsAlreadyEarnedToday;

  /// Existing PK competition score delta remains separate and authoritative.
  final int competitionPointDelta;
}

class AvoraPkRewardPointEngine {
  const AvoraPkRewardPointEngine._();

  static AvoraPkRewardPointRule? resolveRule({
    required List<AvoraPkRewardPointRule> rules,
    required String countryCode,
    required String roomId,
    required String eventKey,
    required DateTime atUtc,
  }) {
    final candidates = rules
        .where(
          (rule) => rule.appliesTo(
            actualCountryCode: countryCode,
            actualRoomId: roomId,
            actualEventKey: eventKey,
            atUtc: atUtc,
          ),
        )
        .toList(growable: false);

    if (candidates.isEmpty) {
      return null;
    }

    final sorted = [...candidates];

    sorted.sort((left, right) {
      final rightScore = right.specificityScore(
        actualCountryCode: countryCode,
        actualRoomId: roomId,
        actualEventKey: eventKey,
      );

      final leftScore = left.specificityScore(
        actualCountryCode: countryCode,
        actualRoomId: roomId,
        actualEventKey: eventKey,
      );

      final specificityCompare = rightScore.compareTo(leftScore);

      if (specificityCompare != 0) {
        return specificityCompare;
      }

      final effectiveCompare = right.effectiveFromUtc
          .toUtc()
          .compareTo(left.effectiveFromUtc.toUtc());

      if (effectiveCompare != 0) {
        return effectiveCompare;
      }

      final versionCompare = right.version.compareTo(left.version);

      if (versionCompare != 0) {
        return versionCompare;
      }

      return right.ruleId.compareTo(left.ruleId);
    });

    return sorted.first;
  }

  static AvoraPkRewardPointResult calculate({
    required AvoraPkUserMatchOutcome outcome,
    required int winStreak,
    required String countryCode,
    required String roomId,
    required String eventKey,
    required List<AvoraPkRewardPointRule> rules,
    required DateTime evaluatedAtUtc,
    int pointsAlreadyEarnedToday = 0,
  }) {
    final rule = resolveRule(
      rules: rules,
      countryCode: countryCode,
      roomId: roomId,
      eventKey: eventKey,
      atUtc: evaluatedAtUtc,
    );

    if (rule == null) {
      return _zero(
        outcome: outcome,
        ruleMatched: false,
        competitionPointDelta: outcome.pointDelta,
        pointsAlreadyEarnedToday: pointsAlreadyEarnedToday,
      );
    }

    final resolvedType = _resolveOutcomeType(outcome);

    /// Invalid, contradictory, merely-started, or cancelled PK does not
    /// generate reward points.
    if (!outcome.valid || resolvedType == AvoraPkRewardPointOutcomeType.none) {
      return _zero(
        outcome: outcome,
        ruleMatched: true,
        ruleId: rule.ruleId,
        ruleVersion: rule.version,
        competitionPointDelta: outcome.pointDelta,
        pointsAlreadyEarnedToday: pointsAlreadyEarnedToday,
      );
    }

    var participation = 0;
    var outcomePoints = 0;
    var streakBonus = 0;

    switch (resolvedType) {
      case AvoraPkRewardPointOutcomeType.win:
        participation = rule.participationPoints;
        outcomePoints = rule.winPoints;

        final bonusSteps = winStreak > 1 ? winStreak - 1 : 0;

        streakBonus = bonusSteps * rule.winStreakBonusPerStep;

        final streakCap = rule.maxWinStreakBonus;
        if (streakCap != null && streakBonus > streakCap) {
          streakBonus = streakCap;
        }

      case AvoraPkRewardPointOutcomeType.loss:
        participation = rule.participationPoints;
        outcomePoints = rule.lossPoints;

      case AvoraPkRewardPointOutcomeType.draw:
        participation = rule.participationPoints;
        outcomePoints = rule.drawPoints;

      case AvoraPkRewardPointOutcomeType.forfeit:

        /// Avoid automatically rewarding participation for forfeiting.
        participation = 0;
        outcomePoints = rule.forfeitPoints;

      case AvoraPkRewardPointOutcomeType.none:
        break;
    }

    final raw = participation + outcomePoints + streakBonus;

    final multiplied = raw * rule.multiplierBasisPoints ~/ 10000;

    var finalPoints = multiplied;
    var perPkCapApplied = false;
    var dailyCapApplied = false;

    final pkCap = rule.maxPointsPerPk;

    if (pkCap != null && finalPoints > pkCap) {
      finalPoints = pkCap;
      perPkCapApplied = true;
    }

    final dailyCap = rule.dailyPointsCap;

    if (dailyCap != null) {
      final normalizedAlready =
          pointsAlreadyEarnedToday < 0 ? 0 : pointsAlreadyEarnedToday;

      final remaining = dailyCap - normalizedAlready;

      if (remaining <= 0) {
        if (finalPoints > 0) {
          dailyCapApplied = true;
        }
        finalPoints = 0;
      } else if (finalPoints > remaining) {
        finalPoints = remaining;
        dailyCapApplied = true;
      }
    }

    return AvoraPkRewardPointResult(
      userAvoraId: outcome.userAvoraId,
      ruleMatched: true,
      eligible: true,
      outcomeType: resolvedType,
      ruleId: rule.ruleId.trim(),
      ruleVersion: rule.version,
      participationPoints: participation,
      outcomePoints: outcomePoints,
      streakBonusPoints: streakBonus,
      multiplierBasisPoints: rule.multiplierBasisPoints,
      pointsBeforeCaps: multiplied,
      points: finalPoints,
      perPkCapApplied: perPkCapApplied,
      dailyCapApplied: dailyCapApplied,
      pointsAlreadyEarnedToday:
          pointsAlreadyEarnedToday < 0 ? 0 : pointsAlreadyEarnedToday,
      competitionPointDelta: outcome.pointDelta,
    );
  }

  static AvoraPkRewardPointOutcomeType _resolveOutcomeType(
    AvoraPkUserMatchOutcome outcome,
  ) {
    if (outcome.forfeited) {
      if (outcome.won || outcome.drew) {
        return AvoraPkRewardPointOutcomeType.none;
      }

      return AvoraPkRewardPointOutcomeType.forfeit;
    }

    var trueCount = 0;

    if (outcome.won) {
      trueCount++;
    }
    if (outcome.lost) {
      trueCount++;
    }
    if (outcome.drew) {
      trueCount++;
    }

    if (trueCount != 1) {
      return AvoraPkRewardPointOutcomeType.none;
    }

    if (outcome.won) {
      return AvoraPkRewardPointOutcomeType.win;
    }

    if (outcome.lost) {
      return AvoraPkRewardPointOutcomeType.loss;
    }

    return AvoraPkRewardPointOutcomeType.draw;
  }

  static AvoraPkRewardPointResult _zero({
    required AvoraPkUserMatchOutcome outcome,
    required bool ruleMatched,
    String ruleId = '',
    int ruleVersion = 0,
    required int competitionPointDelta,
    required int pointsAlreadyEarnedToday,
  }) {
    return AvoraPkRewardPointResult(
      userAvoraId: outcome.userAvoraId,
      ruleMatched: ruleMatched,
      eligible: false,
      outcomeType: AvoraPkRewardPointOutcomeType.none,
      ruleId: ruleId,
      ruleVersion: ruleVersion,
      participationPoints: 0,
      outcomePoints: 0,
      streakBonusPoints: 0,
      multiplierBasisPoints: 10000,
      pointsBeforeCaps: 0,
      points: 0,
      perPkCapApplied: false,
      dailyCapApplied: false,
      pointsAlreadyEarnedToday:
          pointsAlreadyEarnedToday < 0 ? 0 : pointsAlreadyEarnedToday,
      competitionPointDelta: competitionPointDelta,
    );
  }

  static bool existingPkCompetitionOutcomeRemainsAuthoritative() => true;

  static bool rewardPointsRewriteCompetitionPointDelta() => false;

  static bool startedOrCancelledPkCanEarnRewardPoints() => false;

  static bool historicalPkRewardCanBeRetroactivelyRepriced() => false;

  static bool pkRewardCanOverrideSafetyOrValidityChecks() => false;

  static bool pkRewardLayerDirectlyCreditsWallet() => false;
}
