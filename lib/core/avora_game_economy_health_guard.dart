import 'avora_game_economy_policy.dart';
import 'avora_game_financial_analytics.dart';

enum AvoraGameEconomyHealth {
  healthy,
  warning,
  critical,
}

class AvoraGameEconomyHealthResult {
  const AvoraGameEconomyHealthResult({
    required this.health,
    required this.reason,
    required this.configuredReturnPercent,
    required this.actualReturnPercent,
    required this.platformGrossResult,
    required this.pauseRecommended,
  });

  final AvoraGameEconomyHealth health;
  final String reason;

  final double configuredReturnPercent;
  final double actualReturnPercent;

  final int platformGrossResult;
  final bool pauseRecommended;
}

class AvoraGameEconomyHealthGuard {
  const AvoraGameEconomyHealthGuard();

  AvoraGameEconomyHealthResult evaluate({
    required AvoraGameEconomyPolicy policy,
    required AvoraGameFinancialSnapshot snapshot,
    double warningDeviationPercent = 5,
    double criticalDeviationPercent = 10,
  }) {
    policy.validate();

    if (warningDeviationPercent < 0 ||
        criticalDeviationPercent < warningDeviationPercent) {
      throw ArgumentError('invalid_health_thresholds');
    }

    final configured = policy.returnBasisPoints / 100;
    final actual = snapshot.actualReturnPercent;
    final deviation = actual - configured;

    if (snapshot.platformGrossResult < 0 ||
        deviation >= criticalDeviationPercent) {
      return AvoraGameEconomyHealthResult(
        health: AvoraGameEconomyHealth.critical,
        reason: snapshot.platformGrossResult < 0
            ? 'negative_platform_gross_result'
            : 'actual_return_critically_above_policy',
        configuredReturnPercent: configured,
        actualReturnPercent: actual,
        platformGrossResult: snapshot.platformGrossResult,
        pauseRecommended: true,
      );
    }

    if (deviation >= warningDeviationPercent) {
      return AvoraGameEconomyHealthResult(
        health: AvoraGameEconomyHealth.warning,
        reason: 'actual_return_above_policy_warning',
        configuredReturnPercent: configured,
        actualReturnPercent: actual,
        platformGrossResult: snapshot.platformGrossResult,
        pauseRecommended: false,
      );
    }

    return AvoraGameEconomyHealthResult(
      health: AvoraGameEconomyHealth.healthy,
      reason: 'game_economy_within_guardrails',
      configuredReturnPercent: configured,
      actualReturnPercent: actual,
      platformGrossResult: snapshot.platformGrossResult,
      pauseRecommended: false,
    );
  }

  static bool guardMustNeverManipulateIndividualGameResult() => true;
  static bool ownerMustSeeConfiguredVsActualReturn() => true;
  static bool negativeGrossMustTriggerCriticalAlert() => true;
  static bool abnormalReturnMustBeDetectable() => true;
  static bool criticalEconomyMayRecommendGamePause() => true;
  static bool futureGamesMustUseSameHealthGuard() => true;
}
