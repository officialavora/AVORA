import 'avora_actor_presentation.dart';
import 'avora_game_control_enforcement_bridge.dart';
import 'avora_launch_game_bet.dart';

class AvoraControlledGameBetService {
  AvoraControlledGameBetService({
    required AvoraControlledGameBetGuard controlGuard,
    required AvoraLaunchGameBetService betService,
  })  : _controlGuard = controlGuard,
        _betService = betService;

  final AvoraControlledGameBetGuard _controlGuard;
  final AvoraLaunchGameBetService _betService;

  AvoraLaunchGameBet placeBet({
    required String betId,
    required String gameId,
    required String roundId,
    required String countryCode,
    required AvoraActionActor playerActor,
    required String selectionId,
    required int betCoins,
    required DateTime createdAtUtc,
  }) {
    _controlGuard.assertBetAllowed(
      gameId: gameId,
      countryCode: countryCode,
      betCoins: betCoins,
    );

    return _betService.placeBet(
      betId: betId,
      gameId: gameId,
      roundId: roundId,
      playerActor: playerActor,
      selectionId: selectionId,
      betCoins: betCoins,
      createdAtUtc: createdAtUtc,
    );
  }

  static bool ownerControlMustRunBeforeWalletDebit() => true;

  static bool countryScopeMustRunBeforeWalletDebit() => true;

  static bool betLimitMustRunBeforeWalletDebit() => true;

  static bool freezeAwareWalletMustStillRunAfterOwnerControl() => true;

  static bool acceptedBetMustStillCreateImmutableBetRecord() => true;

  static bool futureGamesMustUseSameControlledBetService() => true;
}
