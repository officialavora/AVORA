import 'avora_game_round_policy_binding.dart';

class AvoraGameOwnerFinancialSnapshot {
  const AvoraGameOwnerFinancialSnapshot({
    required this.roundId,
    required this.gameId,
    required this.policyVersion,
    required this.winningSelectionId,
    required this.totalBetCoins,
    required this.totalPayoutCoins,
    required this.netRetainedCoins,
    required this.selectionExposure,
    required this.playerFinancials,
    required this.createdAtUtc,
  });

  final String roundId;
  final String gameId;
  final String policyVersion;
  final String winningSelectionId;
  final int totalBetCoins;
  final int totalPayoutCoins;
  final int netRetainedCoins;

  /// Kept generic here so RTP monitoring does not depend on
  /// another optional financial-snapshot module.
  final List<Object> selectionExposure;
  final List<Object> playerFinancials;

  final DateTime createdAtUtc;
}

enum AvoraGameRtpRiskLevel {
  normal,
  caution,
  high,
  critical,
}

class AvoraGameRtpComplianceDecision {
  const AvoraGameRtpComplianceDecision({
    required this.riskLevel,
    required this.targetReturnBasisPoints,
    required this.actualReturnBasisPoints,
    required this.totalBetCoins,
    required this.totalPayoutCoins,
    required this.requiresOwnerReview,
    required this.blockNewUnsafeConfiguration,
    required this.reason,
  });

  final AvoraGameRtpRiskLevel riskLevel;
  final int targetReturnBasisPoints;
  final int actualReturnBasisPoints;
  final int totalBetCoins;
  final int totalPayoutCoins;
  final bool requiresOwnerReview;
  final bool blockNewUnsafeConfiguration;
  final String reason;
}

class AvoraGameRtpComplianceGuard {
  const AvoraGameRtpComplianceGuard({
    this.cautionDriftBasisPoints = 500,
    this.highDriftBasisPoints = 1000,
    this.criticalDriftBasisPoints = 1500,
  });

  final int cautionDriftBasisPoints;
  final int highDriftBasisPoints;
  final int criticalDriftBasisPoints;

  AvoraGameRtpComplianceDecision evaluate({
    required int totalBetCoins,
    required int totalPayoutCoins,
    required int targetReturnBasisPoints,
  }) {
    if (totalBetCoins < 0 ||
        totalPayoutCoins < 0 ||
        targetReturnBasisPoints < 0 ||
        targetReturnBasisPoints > 10000) {
      throw ArgumentError('invalid_rtp_compliance_input');
    }

    if (totalBetCoins == 0) {
      return AvoraGameRtpComplianceDecision(
        riskLevel: AvoraGameRtpRiskLevel.normal,
        targetReturnBasisPoints: targetReturnBasisPoints,
        actualReturnBasisPoints: 0,
        totalBetCoins: 0,
        totalPayoutCoins: totalPayoutCoins,
        requiresOwnerReview: false,
        blockNewUnsafeConfiguration: false,
        reason: 'insufficient_volume_for_rtp_evaluation',
      );
    }

    final actualReturnBasisPoints = (totalPayoutCoins * 10000) ~/ totalBetCoins;

    final drift = actualReturnBasisPoints - targetReturnBasisPoints;

    final absoluteDrift = drift.abs();

    if (absoluteDrift >= criticalDriftBasisPoints) {
      return AvoraGameRtpComplianceDecision(
        riskLevel: AvoraGameRtpRiskLevel.critical,
        targetReturnBasisPoints: targetReturnBasisPoints,
        actualReturnBasisPoints: actualReturnBasisPoints,
        totalBetCoins: totalBetCoins,
        totalPayoutCoins: totalPayoutCoins,
        requiresOwnerReview: true,
        blockNewUnsafeConfiguration: true,
        reason: drift > 0
            ? 'critical_rtp_over_return'
            : 'critical_rtp_under_return',
      );
    }

    if (absoluteDrift >= highDriftBasisPoints) {
      return AvoraGameRtpComplianceDecision(
        riskLevel: AvoraGameRtpRiskLevel.high,
        targetReturnBasisPoints: targetReturnBasisPoints,
        actualReturnBasisPoints: actualReturnBasisPoints,
        totalBetCoins: totalBetCoins,
        totalPayoutCoins: totalPayoutCoins,
        requiresOwnerReview: true,
        blockNewUnsafeConfiguration: false,
        reason: drift > 0 ? 'high_rtp_over_return' : 'high_rtp_under_return',
      );
    }

    if (absoluteDrift >= cautionDriftBasisPoints) {
      return AvoraGameRtpComplianceDecision(
        riskLevel: AvoraGameRtpRiskLevel.caution,
        targetReturnBasisPoints: targetReturnBasisPoints,
        actualReturnBasisPoints: actualReturnBasisPoints,
        totalBetCoins: totalBetCoins,
        totalPayoutCoins: totalPayoutCoins,
        requiresOwnerReview: false,
        blockNewUnsafeConfiguration: false,
        reason:
            drift > 0 ? 'caution_rtp_over_return' : 'caution_rtp_under_return',
      );
    }

    return AvoraGameRtpComplianceDecision(
      riskLevel: AvoraGameRtpRiskLevel.normal,
      targetReturnBasisPoints: targetReturnBasisPoints,
      actualReturnBasisPoints: actualReturnBasisPoints,
      totalBetCoins: totalBetCoins,
      totalPayoutCoins: totalPayoutCoins,
      requiresOwnerReview: false,
      blockNewUnsafeConfiguration: false,
      reason: 'rtp_within_expected_range',
    );
  }

  static bool rtpGuardMustNotChooseGameResults() => true;

  static bool rtpGuardMustNotRigIndividualRounds() => true;

  static bool rtpGuardMayBlockUnsafeFutureConfiguration() => true;

  static bool ownerMustSeeMaterialRtpDrift() => true;

  static bool futureGamesMustUseSameRtpComplianceGuard() => true;
}

class AvoraGameRollingExposure {
  const AvoraGameRollingExposure({
    required this.gameId,
    required this.roundCount,
    required this.totalBetCoins,
    required this.totalPayoutCoins,
    required this.actualReturnBasisPoints,
    required this.targetReturnBasisPoints,
  });

  final String gameId;
  final int roundCount;
  final int totalBetCoins;
  final int totalPayoutCoins;
  final int actualReturnBasisPoints;
  final int targetReturnBasisPoints;
}

class AvoraGameRollingExposureMonitor {
  const AvoraGameRollingExposureMonitor();

  AvoraGameRollingExposure build({
    required String gameId,
    required Iterable<AvoraGameOwnerFinancialSnapshot> snapshots,
    required Iterable<AvoraGameRoundPolicyBinding> bindings,
  }) {
    final filteredSnapshots = snapshots
        .where((snapshot) => snapshot.gameId == gameId)
        .toList(growable: false);

    if (filteredSnapshots.isEmpty) {
      return AvoraGameRollingExposure(
        gameId: gameId,
        roundCount: 0,
        totalBetCoins: 0,
        totalPayoutCoins: 0,
        actualReturnBasisPoints: 0,
        targetReturnBasisPoints: 0,
      );
    }

    final bindingByRound = <String, AvoraGameRoundPolicyBinding>{
      for (final binding in bindings) binding.roundId: binding,
    };

    var totalBetCoins = 0;
    var totalPayoutCoins = 0;
    var weightedTargetNumerator = 0;

    for (final snapshot in filteredSnapshots) {
      final binding = bindingByRound[snapshot.roundId];

      if (binding == null) {
        throw StateError(
          'missing_round_policy_binding:${snapshot.roundId}',
        );
      }

      totalBetCoins += snapshot.totalBetCoins;
      totalPayoutCoins += snapshot.totalPayoutCoins;

      weightedTargetNumerator +=
          snapshot.totalBetCoins * binding.targetReturnBasisPoints;
    }

    final actualReturnBasisPoints =
        totalBetCoins == 0 ? 0 : (totalPayoutCoins * 10000) ~/ totalBetCoins;

    final targetReturnBasisPoints =
        totalBetCoins == 0 ? 0 : weightedTargetNumerator ~/ totalBetCoins;

    return AvoraGameRollingExposure(
      gameId: gameId,
      roundCount: filteredSnapshots.length,
      totalBetCoins: totalBetCoins,
      totalPayoutCoins: totalPayoutCoins,
      actualReturnBasisPoints: actualReturnBasisPoints,
      targetReturnBasisPoints: targetReturnBasisPoints,
    );
  }

  static bool rollingExposureMustUseCommittedRoundData() => true;

  static bool weightedTargetMustRespectHistoricalPolicyVersions() => true;

  static bool missingPolicyBindingMustFailClosed() => true;

  static bool ownerMustSeeRollingGameExposure() => true;

  static bool futureGamesMustUseSameExposureMonitor() => true;
}
