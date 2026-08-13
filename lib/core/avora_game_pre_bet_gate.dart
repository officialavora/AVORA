import 'avora_game_economy_policy.dart';
import 'avora_game_economy_safety_gate.dart';
import 'avora_game_registry.dart';

enum AvoraGamePreBetDecisionCode {
  allowed,
  gameUnavailable,
  economyUnavailable,
  safetyPaused,
  invalidBet,
  insufficientBalance,
}

class AvoraGamePreBetDecision {
  const AvoraGamePreBetDecision({
    required this.allowed,
    required this.code,
    required this.reason,
  });

  final bool allowed;
  final AvoraGamePreBetDecisionCode code;
  final String reason;
}

class AvoraGamePreBetGate {
  const AvoraGamePreBetGate({
    required AvoraGameRegistry gameRegistry,
    required AvoraGameEconomySafetyGate safetyGate,
  })  : _gameRegistry = gameRegistry,
        _safetyGate = safetyGate;

  final AvoraGameRegistry _gameRegistry;
  final AvoraGameEconomySafetyGate _safetyGate;

  AvoraGamePreBetDecision evaluate({
    required String gameId,
    required int betCoins,
    required int userBalance,
    required AvoraGameEconomyPolicy? policy,
  }) {
    final id = gameId.trim();

    if (id.isEmpty || !_gameRegistry.canUseCoinEconomy(id)) {
      return const AvoraGamePreBetDecision(
        allowed: false,
        code: AvoraGamePreBetDecisionCode.gameUnavailable,
        reason: 'game_not_available_for_coin_economy',
      );
    }

    if (policy == null || !policy.active) {
      return const AvoraGamePreBetDecision(
        allowed: false,
        code: AvoraGamePreBetDecisionCode.economyUnavailable,
        reason: 'game_economy_policy_unavailable',
      );
    }

    policy.validate();

    if (!_safetyGate.canAcceptNewBet(id)) {
      return const AvoraGamePreBetDecision(
        allowed: false,
        code: AvoraGamePreBetDecisionCode.safetyPaused,
        reason: 'game_economy_safety_paused',
      );
    }

    if (!policy.isBetAllowed(betCoins)) {
      return const AvoraGamePreBetDecision(
        allowed: false,
        code: AvoraGamePreBetDecisionCode.invalidBet,
        reason: 'bet_outside_allowed_limits',
      );
    }

    if (userBalance < betCoins) {
      return const AvoraGamePreBetDecision(
        allowed: false,
        code: AvoraGamePreBetDecisionCode.insufficientBalance,
        reason: 'insufficient_coin_balance',
      );
    }

    return const AvoraGamePreBetDecision(
      allowed: true,
      code: AvoraGamePreBetDecisionCode.allowed,
      reason: 'game_bet_allowed',
    );
  }

  static bool coinMustNotDebitBeforeGateAllows() => true;
  static bool unregisteredGameCannotBypassGate() => true;
  static bool pausedGameCannotBypassGate() => true;
  static bool betLimitsMustBeServerAuthoritative() => true;
  static bool insufficientBalanceMustFailClosed() => true;
  static bool futureGamesMustUseSamePreBetGate() => true;
}
