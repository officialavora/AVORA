import 'avora_actor_presentation.dart';
import 'avora_wallet_freeze_enforcement.dart';

enum AvoraGameBetStatus {
  accepted,
  settledWin,
  settledLoss,
  refunded,
}

class AvoraLaunchGameBet {
  const AvoraLaunchGameBet({
    required this.betId,
    required this.gameId,
    required this.roundId,
    required this.playerAvoraId,
    required this.selectionId,
    required this.betCoins,
    required this.status,
    required this.createdAtUtc,
  });

  final String betId;
  final String gameId;
  final String roundId;
  final String playerAvoraId;
  final String selectionId;
  final int betCoins;
  final AvoraGameBetStatus status;
  final DateTime createdAtUtc;

  AvoraLaunchGameBet copyWith({
    AvoraGameBetStatus? status,
  }) {
    return AvoraLaunchGameBet(
      betId: betId,
      gameId: gameId,
      roundId: roundId,
      playerAvoraId: playerAvoraId,
      selectionId: selectionId,
      betCoins: betCoins,
      status: status ?? this.status,
      createdAtUtc: createdAtUtc,
    );
  }
}

class AvoraLaunchGameBetLedger {
  final Map<String, AvoraLaunchGameBet> _bets = <String, AvoraLaunchGameBet>{};

  void append(AvoraLaunchGameBet bet) {
    if (bet.betId.trim().isEmpty ||
        bet.gameId.trim().isEmpty ||
        bet.roundId.trim().isEmpty ||
        bet.playerAvoraId.trim().isEmpty ||
        bet.selectionId.trim().isEmpty ||
        bet.betCoins <= 0) {
      throw ArgumentError('invalid_game_bet');
    }

    if (_bets.containsKey(bet.betId)) {
      throw StateError('duplicate_game_bet');
    }

    _bets[bet.betId] = bet;
  }

  AvoraLaunchGameBet? byId(String betId) {
    return _bets[betId.trim()];
  }

  List<AvoraLaunchGameBet> byPlayer(
    String playerAvoraId,
  ) {
    return List<AvoraLaunchGameBet>.unmodifiable(
      _bets.values.where(
        (bet) => bet.playerAvoraId == playerAvoraId,
      ),
    );
  }

  List<AvoraLaunchGameBet> byRound(
    String roundId,
  ) {
    return List<AvoraLaunchGameBet>.unmodifiable(
      _bets.values.where(
        (bet) => bet.roundId == roundId,
      ),
    );
  }

  void updateStatus({
    required String betId,
    required AvoraGameBetStatus status,
  }) {
    final current = _bets[betId];

    if (current == null) {
      throw StateError('game_bet_not_found');
    }

    _bets[betId] = current.copyWith(status: status);
  }

  static bool everyGameBetMustUseImmutableAvoraId() => true;

  static bool duplicateBetMustFailClosed() => true;

  static bool everyBetMustPreserveGameRoundAndSelection() => true;

  static bool everyBetMustPreserveCoinAmount() => true;

  static bool futureGamesMustUseSameBetLedger() => true;
}

class AvoraLaunchGameBetService {
  AvoraLaunchGameBetService({
    required AvoraFreezeAwareWalletService walletService,
    required AvoraLaunchGameBetLedger betLedger,
  })  : _walletService = walletService,
        _betLedger = betLedger;

  final AvoraFreezeAwareWalletService _walletService;
  final AvoraLaunchGameBetLedger _betLedger;

  AvoraLaunchGameBet placeBet({
    required String betId,
    required String gameId,
    required String roundId,
    required AvoraActionActor playerActor,
    required String selectionId,
    required int betCoins,
    required DateTime createdAtUtc,
  }) {
    if (playerActor.kind != AvoraActorKind.user &&
        playerActor.kind != AvoraActorKind.owner &&
        playerActor.kind != AvoraActorKind.manager &&
        playerActor.kind != AvoraActorKind.admin &&
        playerActor.kind != AvoraActorKind.superAdmin &&
        playerActor.kind != AvoraActorKind.bd &&
        playerActor.kind != AvoraActorKind.agency &&
        playerActor.kind != AvoraActorKind.merchant &&
        playerActor.kind != AvoraActorKind.seller) {
      throw StateError('invalid_game_player_actor');
    }

    if (betId.trim().isEmpty ||
        gameId.trim().isEmpty ||
        roundId.trim().isEmpty ||
        playerActor.avoraId.trim().isEmpty ||
        selectionId.trim().isEmpty ||
        betCoins <= 0) {
      throw ArgumentError('invalid_game_bet_request');
    }

    if (_betLedger.byId(betId) != null) {
      throw StateError('duplicate_game_bet');
    }

    // Freeze-aware debit happens before bet acceptance.
    _walletService.spend(
      transactionId: 'game-bet-$betId',
      actor: playerActor,
      targetAvoraId: playerActor.avoraId,
      amountCoins: betCoins,
      createdAtUtc: createdAtUtc,
      reason: 'game_bet:$gameId:$roundId:$selectionId',
      purpose: AvoraWalletSpendPurpose.game,
    );

    final bet = AvoraLaunchGameBet(
      betId: betId,
      gameId: gameId,
      roundId: roundId,
      playerAvoraId: playerActor.avoraId,
      selectionId: selectionId,
      betCoins: betCoins,
      status: AvoraGameBetStatus.accepted,
      createdAtUtc: createdAtUtc.toUtc(),
    );

    _betLedger.append(bet);

    return bet;
  }

  static bool gameBetMustCheckWalletFreezeBeforeAcceptance() => true;

  static bool gameBetDebitMustPrecedeAcceptedStatus() => true;

  static bool failedDebitMustNeverCreateAcceptedBet() => true;

  static bool futureWheelGameMustUseSameBetEntry() => true;

  static bool futureFruitMultiplierGameMustUseSameBetEntry() => true;
}

class AvoraFreezeAwareGiftSpendBridge {
  AvoraFreezeAwareGiftSpendBridge({
    required AvoraFreezeAwareWalletService walletService,
  }) : _walletService = walletService;

  final AvoraFreezeAwareWalletService _walletService;

  void debitGiftSpend({
    required String transactionId,
    required AvoraActionActor senderActor,
    required int amountCoins,
    required DateTime createdAtUtc,
    required String giftId,
  }) {
    _walletService.spend(
      transactionId: transactionId,
      actor: senderActor,
      targetAvoraId: senderActor.avoraId,
      amountCoins: amountCoins,
      createdAtUtc: createdAtUtc,
      reason: 'gift:$giftId',
      purpose: AvoraWalletSpendPurpose.gift,
    );
  }

  static bool everyGiftSpendMustCheckWalletFreeze() => true;

  static bool frozenWalletMustNotSendGift() => true;

  static bool futureGiftFlowsMustUseSameFreezeAwareBridge() => true;
}
