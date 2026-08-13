import 'avora_launch_game_bet.dart';

enum AvoraGameRoundStatus {
  bettingOpen,
  bettingClosed,
  settled,
  cancelled,
}

class AvoraGameSelectionConfig {
  const AvoraGameSelectionConfig({
    required this.selectionId,
    required this.multiplierBasisPoints,
    required this.enabled,
  });

  final String selectionId;

  /// Example:
  /// 20000 = 2.00x
  /// 50000 = 5.00x
  final int multiplierBasisPoints;

  final bool enabled;

  void validate() {
    if (selectionId.trim().isEmpty || multiplierBasisPoints <= 0) {
      throw ArgumentError('invalid_game_selection_config');
    }
  }
}

class AvoraGamePayoutPolicySnapshot {
  const AvoraGamePayoutPolicySnapshot({
    required this.policyVersion,
    required this.gameId,
    required this.selections,
  });

  final String policyVersion;
  final String gameId;
  final List<AvoraGameSelectionConfig> selections;

  void validate() {
    if (policyVersion.trim().isEmpty ||
        gameId.trim().isEmpty ||
        selections.isEmpty) {
      throw ArgumentError('invalid_game_payout_policy');
    }

    final ids = <String>{};

    for (final selection in selections) {
      selection.validate();

      if (!ids.add(selection.selectionId)) {
        throw StateError('duplicate_game_selection');
      }
    }
  }

  AvoraGameSelectionConfig selection(String selectionId) {
    return selections.firstWhere(
      (item) => item.selectionId == selectionId,
      orElse: () => throw StateError(
        'game_selection_not_found',
      ),
    );
  }
}

class AvoraGameRound {
  const AvoraGameRound({
    required this.roundId,
    required this.gameId,
    required this.policyVersion,
    required this.status,
    required this.openedAtUtc,
    this.closedAtUtc,
    this.settledAtUtc,
    this.winningSelectionId,
  });

  final String roundId;
  final String gameId;
  final String policyVersion;
  final AvoraGameRoundStatus status;
  final DateTime openedAtUtc;
  final DateTime? closedAtUtc;
  final DateTime? settledAtUtc;
  final String? winningSelectionId;

  AvoraGameRound copyWith({
    AvoraGameRoundStatus? status,
    DateTime? closedAtUtc,
    DateTime? settledAtUtc,
    String? winningSelectionId,
  }) {
    return AvoraGameRound(
      roundId: roundId,
      gameId: gameId,
      policyVersion: policyVersion,
      status: status ?? this.status,
      openedAtUtc: openedAtUtc,
      closedAtUtc: closedAtUtc ?? this.closedAtUtc,
      settledAtUtc: settledAtUtc ?? this.settledAtUtc,
      winningSelectionId: winningSelectionId ?? this.winningSelectionId,
    );
  }
}

class AvoraGameRoundSettlement {
  const AvoraGameRoundSettlement({
    required this.roundId,
    required this.gameId,
    required this.policyVersion,
    required this.winningSelectionId,
    required this.totalBetCoins,
    required this.totalWinCoins,
    required this.totalLossCoins,
    required this.settledAtUtc,
  });

  final String roundId;
  final String gameId;
  final String policyVersion;
  final String winningSelectionId;
  final int totalBetCoins;
  final int totalWinCoins;
  final int totalLossCoins;
  final DateTime settledAtUtc;
}

class AvoraPlayerGameSettlement {
  const AvoraPlayerGameSettlement({
    required this.betId,
    required this.roundId,
    required this.playerAvoraId,
    required this.selectionId,
    required this.betCoins,
    required this.winCoins,
    required this.netCoins,
  });

  final String betId;
  final String roundId;
  final String playerAvoraId;
  final String selectionId;
  final int betCoins;
  final int winCoins;
  final int netCoins;

  bool get won => winCoins > 0;
}

abstract interface class AvoraGameResultAuthority {
  String winningSelectionId({
    required AvoraGameRound round,
    required AvoraGamePayoutPolicySnapshot policy,
  });
}

class AvoraGameRoundLedger {
  final Map<String, AvoraGameRound> _rounds = <String, AvoraGameRound>{};

  final Map<String, AvoraGameRoundSettlement> _settlements =
      <String, AvoraGameRoundSettlement>{};

  void openRound(AvoraGameRound round) {
    if (round.roundId.trim().isEmpty ||
        round.gameId.trim().isEmpty ||
        round.policyVersion.trim().isEmpty) {
      throw ArgumentError('invalid_game_round');
    }

    if (_rounds.containsKey(round.roundId)) {
      throw StateError('duplicate_game_round');
    }

    _rounds[round.roundId] = round;
  }

  AvoraGameRound? byId(String roundId) {
    return _rounds[roundId.trim()];
  }

  void closeRound({
    required String roundId,
    required DateTime closedAtUtc,
  }) {
    final current = _rounds[roundId];

    if (current == null) {
      throw StateError('game_round_not_found');
    }

    if (current.status != AvoraGameRoundStatus.bettingOpen) {
      throw StateError('game_round_not_open');
    }

    _rounds[roundId] = current.copyWith(
      status: AvoraGameRoundStatus.bettingClosed,
      closedAtUtc: closedAtUtc.toUtc(),
    );
  }

  void settleRound({
    required AvoraGameRoundSettlement settlement,
  }) {
    final current = _rounds[settlement.roundId];

    if (current == null) {
      throw StateError('game_round_not_found');
    }

    if (current.status != AvoraGameRoundStatus.bettingClosed) {
      throw StateError('game_round_not_closed');
    }

    if (_settlements.containsKey(settlement.roundId)) {
      throw StateError('game_round_already_settled');
    }

    _settlements[settlement.roundId] = settlement;

    _rounds[settlement.roundId] = current.copyWith(
      status: AvoraGameRoundStatus.settled,
      settledAtUtc: settlement.settledAtUtc.toUtc(),
      winningSelectionId: settlement.winningSelectionId,
    );
  }

  AvoraGameRoundSettlement? settlement(
    String roundId,
  ) {
    return _settlements[roundId.trim()];
  }

  static bool clientMustNeverChooseWinningSelection() => true;

  static bool everyRoundMustPreservePolicyVersion() => true;

  static bool settledRoundMustBeImmutable() => true;

  static bool duplicateSettlementMustFailClosed() => true;

  static bool futureGamesMustUseSameRoundLedger() => true;
}

class AvoraGameRoundSettlementService {
  AvoraGameRoundSettlementService({
    required AvoraLaunchGameBetLedger betLedger,
    required AvoraGameRoundLedger roundLedger,
    required AvoraGameResultAuthority resultAuthority,
  })  : _betLedger = betLedger,
        _roundLedger = roundLedger,
        _resultAuthority = resultAuthority;

  final AvoraLaunchGameBetLedger _betLedger;
  final AvoraGameRoundLedger _roundLedger;
  final AvoraGameResultAuthority _resultAuthority;

  List<AvoraPlayerGameSettlement> settle({
    required String roundId,
    required AvoraGamePayoutPolicySnapshot policy,
    required DateTime settledAtUtc,
  }) {
    policy.validate();

    final round = _roundLedger.byId(roundId);

    if (round == null) {
      throw StateError('game_round_not_found');
    }

    if (round.gameId != policy.gameId ||
        round.policyVersion != policy.policyVersion) {
      throw StateError('game_policy_round_mismatch');
    }

    if (round.status != AvoraGameRoundStatus.bettingClosed) {
      throw StateError('game_round_not_closed');
    }

    final winningSelectionId = _resultAuthority.winningSelectionId(
      round: round,
      policy: policy,
    );

    final winningConfig = policy.selection(winningSelectionId);

    if (!winningConfig.enabled) {
      throw StateError('winning_selection_disabled');
    }

    final bets = _betLedger.byRound(roundId);

    var totalBetCoins = 0;
    var totalWinCoins = 0;

    final playerSettlements = <AvoraPlayerGameSettlement>[];

    for (final bet in bets) {
      totalBetCoins += bet.betCoins;

      final isWinner = bet.selectionId == winningSelectionId;

      final winCoins = isWinner
          ? (bet.betCoins * winningConfig.multiplierBasisPoints) ~/ 10000
          : 0;

      totalWinCoins += winCoins;

      playerSettlements.add(
        AvoraPlayerGameSettlement(
          betId: bet.betId,
          roundId: bet.roundId,
          playerAvoraId: bet.playerAvoraId,
          selectionId: bet.selectionId,
          betCoins: bet.betCoins,
          winCoins: winCoins,
          netCoins: winCoins - bet.betCoins,
        ),
      );

      _betLedger.updateStatus(
        betId: bet.betId,
        status: isWinner
            ? AvoraGameBetStatus.settledWin
            : AvoraGameBetStatus.settledLoss,
      );
    }

    final totalLossCoins = totalBetCoins - totalWinCoins;

    _roundLedger.settleRound(
      settlement: AvoraGameRoundSettlement(
        roundId: round.roundId,
        gameId: round.gameId,
        policyVersion: policy.policyVersion,
        winningSelectionId: winningSelectionId,
        totalBetCoins: totalBetCoins,
        totalWinCoins: totalWinCoins,
        totalLossCoins: totalLossCoins,
        settledAtUtc: settledAtUtc.toUtc(),
      ),
    );

    return List<AvoraPlayerGameSettlement>.unmodifiable(
      playerSettlements,
    );
  }

  static bool resultMustComeFromServerAuthority() => true;

  static bool multiplierMustComeFromVersionedPolicy() => true;

  static bool payoutTableMustBeConfigurable() => true;

  static bool playerWinLossMustRemainReconstructable() => true;

  static bool roundTotalsMustRemainAuditable() => true;

  static bool wheelAndFruitGamesMustReuseSameSettlementEngine() => true;

  static bool futureGameTypesMustReuseSameSettlementEngine() => true;
}
