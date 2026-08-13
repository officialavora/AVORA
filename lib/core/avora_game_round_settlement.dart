import 'avora_coin_master_ledger.dart';
import 'avora_game_economy_policy.dart';

enum AvoraGameRoundSettlementStatus {
  settled,
  rejected,
  payoutPendingReview,
}

class AvoraGameRoundSettlementRequest {
  const AvoraGameRoundSettlementRequest({
    required this.roundId,
    required this.gameId,
    required this.userAvoraId,
    required this.betCoins,
    required this.payoutCoins,
    required this.balanceBefore,
    required this.policy,
    required this.createdAtUtc,
  });

  final String roundId;
  final String gameId;
  final String userAvoraId;

  final int betCoins;
  final int payoutCoins;
  final int balanceBefore;

  final AvoraGameEconomyPolicy policy;
  final DateTime createdAtUtc;
}

class AvoraGameRoundSettlementResult {
  const AvoraGameRoundSettlementResult({
    required this.status,
    required this.reason,
    required this.balanceAfterBet,
    required this.balanceAfterSettlement,
    required this.netUserResult,
  });

  final AvoraGameRoundSettlementStatus status;
  final String reason;

  final int balanceAfterBet;
  final int balanceAfterSettlement;
  final int netUserResult;

  bool get success => status == AvoraGameRoundSettlementStatus.settled;
}

class AvoraGameRoundSettlementService {
  AvoraGameRoundSettlementService({
    required AvoraCoinMasterLedger masterLedger,
  }) : _masterLedger = masterLedger;

  final AvoraCoinMasterLedger _masterLedger;
  final Set<String> _settledRoundIds = <String>{};

  AvoraGameRoundSettlementResult settle(
    AvoraGameRoundSettlementRequest request,
  ) {
    final roundId = request.roundId.trim();
    final gameId = request.gameId.trim();
    final userId = request.userAvoraId.trim();

    if (roundId.isEmpty || gameId.isEmpty || userId.isEmpty) {
      return AvoraGameRoundSettlementResult(
        status: AvoraGameRoundSettlementStatus.rejected,
        reason: 'game_round_identity_required',
        balanceAfterBet: request.balanceBefore,
        balanceAfterSettlement: request.balanceBefore,
        netUserResult: 0,
      );
    }

    request.policy.validate();

    if (!request.policy.active ||
        !request.policy.isBetAllowed(request.betCoins)) {
      return AvoraGameRoundSettlementResult(
        status: AvoraGameRoundSettlementStatus.rejected,
        reason: 'game_bet_not_allowed',
        balanceAfterBet: request.balanceBefore,
        balanceAfterSettlement: request.balanceBefore,
        netUserResult: 0,
      );
    }

    if (request.balanceBefore < request.betCoins) {
      return AvoraGameRoundSettlementResult(
        status: AvoraGameRoundSettlementStatus.rejected,
        reason: 'insufficient_coin_balance',
        balanceAfterBet: request.balanceBefore,
        balanceAfterSettlement: request.balanceBefore,
        netUserResult: 0,
      );
    }

    if (request.payoutCoins < 0) {
      return AvoraGameRoundSettlementResult(
        status: AvoraGameRoundSettlementStatus.rejected,
        reason: 'invalid_game_payout',
        balanceAfterBet: request.balanceBefore,
        balanceAfterSettlement: request.balanceBefore,
        netUserResult: 0,
      );
    }

    if (_settledRoundIds.contains(roundId)) {
      return AvoraGameRoundSettlementResult(
        status: AvoraGameRoundSettlementStatus.rejected,
        reason: 'duplicate_game_round_settlement',
        balanceAfterBet: request.balanceBefore,
        balanceAfterSettlement: request.balanceBefore,
        netUserResult: 0,
      );
    }

    final balanceAfterBet = request.balanceBefore - request.betCoins;

    final balanceAfterSettlement = balanceAfterBet + request.payoutCoins;

    _masterLedger.append(
      AvoraCoinLedgerEntry(
        entryId: '$roundId-bet',
        transactionId: roundId,
        eventType: AvoraCoinLedgerEventType.gameBet,
        avoraId: userId,
        amount: request.betCoins,
        balanceBefore: request.balanceBefore,
        balanceAfter: balanceAfterBet,
        referenceId: gameId,
        createdAt: request.createdAtUtc.toUtc(),
        policyVersion: request.policy.policyVersion,
      ),
    );

    if (request.payoutCoins > 0) {
      _masterLedger.append(
        AvoraCoinLedgerEntry(
          entryId: '$roundId-payout',
          transactionId: roundId,
          eventType: AvoraCoinLedgerEventType.gameWin,
          avoraId: userId,
          amount: request.payoutCoins,
          balanceBefore: balanceAfterBet,
          balanceAfter: balanceAfterSettlement,
          referenceId: gameId,
          createdAt: request.createdAtUtc.toUtc(),
          policyVersion: request.policy.policyVersion,
        ),
      );
    } else {
      _masterLedger.append(
        AvoraCoinLedgerEntry(
          entryId: '$roundId-loss',
          transactionId: roundId,
          eventType: AvoraCoinLedgerEventType.gameLoss,
          avoraId: userId,
          amount: request.betCoins,
          balanceBefore: balanceAfterBet,
          balanceAfter: balanceAfterBet,
          referenceId: gameId,
          createdAt: request.createdAtUtc.toUtc(),
          policyVersion: request.policy.policyVersion,
        ),
      );
    }

    _settledRoundIds.add(roundId);

    return AvoraGameRoundSettlementResult(
      status: AvoraGameRoundSettlementStatus.settled,
      reason: 'game_round_settled',
      balanceAfterBet: balanceAfterBet,
      balanceAfterSettlement: balanceAfterSettlement,
      netUserResult: request.payoutCoins - request.betCoins,
    );
  }

  static bool everyGameBetMustCreateLedgerEvidence() => true;

  static bool payoutMustUseSameRoundTransactionId() => true;

  static bool duplicateRoundMustNeverDoubleDebitOrPay() => true;

  static bool userMustSeeOwnBetWinLossHistory() => true;

  static bool ownerMustSeeAllGameSettlementHistory() => true;

  static bool historicalRoundMustKeepOriginalPolicyVersion() => true;

  static bool failedSettlementMustNeverSilentlyChangeBalance() => true;

  static bool futureGamesMustUseSameSettlementContract() => true;
}
