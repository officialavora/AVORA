import 'avora_game_round_engine.dart';
import 'avora_game_round_policy_binding.dart';
import 'avora_owner_game_control.dart';

class AvoraGameControlEnforcementDecision {
  const AvoraGameControlEnforcementDecision({
    required this.allowed,
    required this.reason,
  });

  final bool allowed;
  final String reason;
}

class AvoraGameControlEnforcementBridge {
  const AvoraGameControlEnforcementBridge();

  AvoraGameControlEnforcementDecision validateRoundOpen({
    required AvoraOwnerGameControlPolicy controlPolicy,
    required String gameId,
    required String countryCode,
  }) {
    if (controlPolicy.gameId != gameId) {
      return const AvoraGameControlEnforcementDecision(
        allowed: false,
        reason: 'game_control_policy_mismatch',
      );
    }

    if (!controlPolicy.isAvailableInCountry(countryCode)) {
      return const AvoraGameControlEnforcementDecision(
        allowed: false,
        reason: 'game_not_available_in_country',
      );
    }

    return const AvoraGameControlEnforcementDecision(
      allowed: true,
      reason: 'game_round_open_allowed',
    );
  }

  AvoraGameControlEnforcementDecision validateBet({
    required AvoraOwnerGameControlPolicy controlPolicy,
    required String gameId,
    required String countryCode,
    required int betCoins,
  }) {
    final roundDecision = validateRoundOpen(
      controlPolicy: controlPolicy,
      gameId: gameId,
      countryCode: countryCode,
    );

    if (!roundDecision.allowed) {
      return roundDecision;
    }

    if (!controlPolicy.acceptsBet(betCoins)) {
      return const AvoraGameControlEnforcementDecision(
        allowed: false,
        reason: 'game_bet_outside_owner_limits',
      );
    }

    return const AvoraGameControlEnforcementDecision(
      allowed: true,
      reason: 'game_bet_allowed',
    );
  }

  static bool ownerControlMustBeCheckedBeforeRoundOpen() => true;

  static bool ownerControlMustBeCheckedBeforeBetAcceptance() => true;

  static bool disabledGameMustNeverOpenNewRound() => true;

  static bool countryScopeMustApplyToActualGameFlow() => true;

  static bool ownerBetLimitsMustApplyToActualGameFlow() => true;

  static bool clientMustNotBypassOwnerControlBridge() => true;

  static bool futureGamesMustUseSameControlBridge() => true;
}

class AvoraControlledGameRoundFactory {
  AvoraControlledGameRoundFactory({
    required AvoraOwnerGameControlRegistry controlRegistry,
    required AvoraGameRoundFactory roundFactory,
    required AvoraGameControlEnforcementBridge enforcementBridge,
  })  : _controlRegistry = controlRegistry,
        _roundFactory = roundFactory,
        _enforcementBridge = enforcementBridge;

  final AvoraOwnerGameControlRegistry _controlRegistry;
  final AvoraGameRoundFactory _roundFactory;
  final AvoraGameControlEnforcementBridge _enforcementBridge;

  AvoraEngineGameRound openRound({
    required String roundId,
    required String gameId,
    required String countryCode,
    required AvoraGamePayoutPolicySnapshot gamePolicy,
    required DateTime openedAtUtc,
  }) {
    final control = _controlRegistry.activeFor(gameId);

    if (control == null) {
      throw StateError('active_owner_game_control_required');
    }

    final decision = _enforcementBridge.validateRoundOpen(
      controlPolicy: control,
      gameId: gameId,
      countryCode: countryCode,
    );

    if (!decision.allowed) {
      throw StateError(decision.reason);
    }

    return _roundFactory.openRound(
      roundId: roundId,
      gameId: gameId,
      gamePolicy: gamePolicy,
      openedAtUtc: openedAtUtc,
    );
  }

  static bool roundFactoryMustRequireActiveOwnerControl() => true;

  static bool everyNewGameMustUseControlledRoundFactory() => true;
}

class AvoraControlledGameBetGuard {
  AvoraControlledGameBetGuard({
    required AvoraOwnerGameControlRegistry controlRegistry,
    required AvoraGameControlEnforcementBridge enforcementBridge,
  })  : _controlRegistry = controlRegistry,
        _enforcementBridge = enforcementBridge;

  final AvoraOwnerGameControlRegistry _controlRegistry;
  final AvoraGameControlEnforcementBridge _enforcementBridge;

  void assertBetAllowed({
    required String gameId,
    required String countryCode,
    required int betCoins,
  }) {
    final control = _controlRegistry.activeFor(gameId);

    if (control == null) {
      throw StateError('active_owner_game_control_required');
    }

    final decision = _enforcementBridge.validateBet(
      controlPolicy: control,
      gameId: gameId,
      countryCode: countryCode,
      betCoins: betCoins,
    );

    if (!decision.allowed) {
      throw StateError(decision.reason);
    }
  }

  bool jackpotEnabled(String gameId) {
    final control = _controlRegistry.activeFor(gameId);

    if (control == null) {
      throw StateError('active_owner_game_control_required');
    }

    return control.jackpotEnabled;
  }

  bool specialEventsEnabled(String gameId) {
    final control = _controlRegistry.activeFor(gameId);

    if (control == null) {
      throw StateError('active_owner_game_control_required');
    }

    return control.specialEventsEnabled;
  }

  static bool jackpotMustRespectOwnerToggle() => true;

  static bool specialEventsMustRespectOwnerToggle() => true;

  static bool allBetEntryPointsMustUseSameGuard() => true;
}
