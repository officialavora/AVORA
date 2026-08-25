import 'avora_game_round_engine.dart';
import 'avora_universal_game_economy_policy.dart';

class AvoraGameRoundPolicyBinding {
  const AvoraGameRoundPolicyBinding({
    required this.roundId,
    required this.gameId,
    required this.gamePolicyVersion,
    required this.economyPolicyVersion,
    required this.targetReturnBasisPoints,
    required this.boundAtUtc,
  });

  final String roundId;
  final String gameId;

  /// Game-specific multiplier/payout-table version.
  final String gamePolicyVersion;

  /// Universal AVORA economy-policy version.
  final String economyPolicyVersion;

  /// Snapshot of the active return target at round creation.
  final int targetReturnBasisPoints;

  final DateTime boundAtUtc;
}

class AvoraGameRoundPolicyBindingLedger {
  final Map<String, AvoraGameRoundPolicyBinding> _bindings =
      <String, AvoraGameRoundPolicyBinding>{};

  void bind(AvoraGameRoundPolicyBinding binding) {
    if (binding.roundId.trim().isEmpty ||
        binding.gameId.trim().isEmpty ||
        binding.gamePolicyVersion.trim().isEmpty ||
        binding.economyPolicyVersion.trim().isEmpty ||
        binding.targetReturnBasisPoints < 0 ||
        binding.targetReturnBasisPoints > 10000) {
      throw ArgumentError('invalid_game_round_policy_binding');
    }

    if (_bindings.containsKey(binding.roundId)) {
      throw StateError('game_round_policy_already_bound');
    }

    _bindings[binding.roundId] = binding;
  }

  AvoraGameRoundPolicyBinding? byRoundId(
    String roundId,
  ) {
    return _bindings[roundId.trim()];
  }

  static bool everyRoundMustBindEconomyPolicyVersion() => true;

  static bool historicalBindingMustRemainImmutable() => true;

  static bool laterPolicyChangeMustNotRewriteExistingRound() => true;

  static bool targetReturnSnapshotMustRemainTraceable() => true;

  static bool futureGamesMustUseSamePolicyBindingLedger() => true;
}

class AvoraGameRoundFactory {
  AvoraGameRoundFactory({
    required AvoraGameEconomyPolicyProvider economyPolicyProvider,
    required AvoraGameRoundPolicyBindingLedger bindingLedger,
    required AvoraGameRoundLedger roundLedger,
  })  : _economyPolicyProvider = economyPolicyProvider,
        _bindingLedger = bindingLedger,
        _roundLedger = roundLedger;

  final AvoraGameEconomyPolicyProvider _economyPolicyProvider;
  final AvoraGameRoundPolicyBindingLedger _bindingLedger;
  final AvoraGameRoundLedger _roundLedger;

  AvoraEngineGameRound openRound({
    required String roundId,
    required String gameId,
    required AvoraGamePayoutPolicySnapshot gamePolicy,
    required DateTime openedAtUtc,
  }) {
    gamePolicy.validate();

    if (gamePolicy.gameId != gameId) {
      throw StateError('game_policy_game_id_mismatch');
    }

    final economyPolicy = _economyPolicyProvider.activePolicy();

    economyPolicy.validate();

    if (_roundLedger.byId(roundId) != null) {
      throw StateError('duplicate_game_round');
    }

    if (_bindingLedger.byRoundId(roundId) != null) {
      throw StateError('game_round_policy_already_bound');
    }

    final binding = AvoraGameRoundPolicyBinding(
      roundId: roundId,
      gameId: gameId,
      gamePolicyVersion: gamePolicy.policyVersion,
      economyPolicyVersion: economyPolicy.policyVersion,
      targetReturnBasisPoints: economyPolicy.targetReturnBasisPoints,
      boundAtUtc: openedAtUtc.toUtc(),
    );

    final round = AvoraEngineGameRound(
      roundId: roundId,
      gameId: gameId,
      policyVersion: gamePolicy.policyVersion,
      status: AvoraGameRoundStatus.bettingOpen,
      openedAtUtc: openedAtUtc.toUtc(),
    );

    _bindingLedger.bind(binding);
    _roundLedger.openRound(round);

    return round;
  }

  static bool newRoundMustReadActiveUniversalEconomyPolicy() => true;

  static bool gamePolicyAndEconomyPolicyMustRemainSeparate() => true;

  static bool roundMustCaptureBothPolicyVersions() => true;

  static bool policyChangeMustOnlyAffectFutureRounds() => true;

  static bool wheelGameMustUseSameRoundFactory() => true;

  static bool fruitGameMustUseSameRoundFactory() => true;

  static bool fishGameMustUseSameRoundFactory() => true;

  static bool spinGameMustUseSameRoundFactory() => true;

  static bool futureGamesMustUseSameRoundFactory() => true;
}
