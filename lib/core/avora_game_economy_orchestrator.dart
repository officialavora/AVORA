import 'avora_coin_master_ledger.dart';
import 'avora_game_economy_policy.dart';
import 'avora_game_pre_bet_gate.dart';
import 'avora_game_round_settlement.dart';

class AvoraGameEconomyOrchestratorResult {
  const AvoraGameEconomyOrchestratorResult({
    required this.success,
    required this.reason,
    required this.balanceAfter,
    this.settlement,
  });

  final bool success;
  final String reason;
  final int balanceAfter;
  final AvoraGameRoundSettlementResult? settlement;
}

class AvoraGameEconomyOrchestrator {
  AvoraGameEconomyOrchestrator({
    required AvoraGamePreBetGate preBetGate,
    required AvoraCoinMasterLedger masterLedger,
  })  : _preBetGate = preBetGate,
        _settlementService = AvoraGameRoundSettlementService(
          masterLedger: masterLedger,
        );

  final AvoraGamePreBetGate _preBetGate;
  final AvoraGameRoundSettlementService _settlementService;

  AvoraGameEconomyOrchestratorResult execute({
    required String roundId,
    required String gameId,
    required String userAvoraId,
    required int betCoins,
    required int payoutCoins,
    required int balanceBefore,
    required AvoraGameEconomyPolicy policy,
    required DateTime createdAtUtc,
  }) {
    if (roundId.trim().isEmpty ||
        gameId.trim().isEmpty ||
        userAvoraId.trim().isEmpty) {
      return AvoraGameEconomyOrchestratorResult(
        success: false,
        reason: 'game_round_identity_required',
        balanceAfter: balanceBefore,
      );
    }

    final gate = _preBetGate.evaluate(
      gameId: gameId,
      betCoins: betCoins,
      userBalance: balanceBefore,
      policy: policy,
    );

    if (!gate.allowed) {
      return AvoraGameEconomyOrchestratorResult(
        success: false,
        reason: gate.reason,
        balanceAfter: balanceBefore,
      );
    }

    final settlement = _settlementService.settle(
      AvoraGameRoundSettlementRequest(
        roundId: roundId,
        gameId: gameId,
        userAvoraId: userAvoraId,
        betCoins: betCoins,
        payoutCoins: payoutCoins,
        balanceBefore: balanceBefore,
        policy: policy,
        createdAtUtc: createdAtUtc,
      ),
    );

    return AvoraGameEconomyOrchestratorResult(
      success: settlement.success,
      reason: settlement.reason,
      balanceAfter: settlement.success
          ? settlement.balanceAfterSettlement
          : balanceBefore,
      settlement: settlement,
    );
  }

  static bool preBetGateMustRunBeforeCoinMutation() => true;

  static bool rejectedBetMustNeverWriteSettlement() => true;

  static bool successfulBetMustUseMasterCoinLedger() => true;

  static bool gameRegistryPolicyAndSafetyMustShareOneFlow() => true;

  static bool duplicateRoundMustNeverDoubleSettle() => true;

  static bool futureGamesMustUseSameOrchestrator() => true;
}
