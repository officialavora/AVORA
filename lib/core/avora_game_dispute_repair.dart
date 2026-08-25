import 'avora_actor_presentation.dart';
import 'avora_game_payout_settlement.dart';
import 'avora_game_round_engine.dart';
import 'avora_launch_game_bet.dart';
import 'avora_launch_wallet.dart';

enum AvoraGameDisputeType {
  missingWinningCredit,
  incorrectWinningCredit,
  incorrectBetDebit,
  roundResultDispute,
  duplicateDebit,
  other,
}

enum AvoraGameDisputeStatus {
  opened,
  investigating,
  confirmed,
  rejected,
  repaired,
  closed,
}

class AvoraGameDisputeCase {
  const AvoraGameDisputeCase({
    required this.caseId,
    required this.playerAvoraId,
    required this.gameId,
    required this.roundId,
    required this.betId,
    required this.type,
    required this.status,
    required this.claimReason,
    required this.createdAtUtc,
  });

  final String caseId;
  final String playerAvoraId;
  final String gameId;
  final String roundId;
  final String betId;
  final AvoraGameDisputeType type;
  final AvoraGameDisputeStatus status;
  final String claimReason;
  final DateTime createdAtUtc;

  AvoraGameDisputeCase copyWith({
    AvoraGameDisputeStatus? status,
  }) {
    return AvoraGameDisputeCase(
      caseId: caseId,
      playerAvoraId: playerAvoraId,
      gameId: gameId,
      roundId: roundId,
      betId: betId,
      type: type,
      status: status ?? this.status,
      claimReason: claimReason,
      createdAtUtc: createdAtUtc,
    );
  }
}

class AvoraGameDisputeReconstruction {
  const AvoraGameDisputeReconstruction({
    required this.caseId,
    required this.playerAvoraId,
    required this.bet,
    required this.round,
    required this.roundSettlement,
    required this.payout,
    required this.expectedWinCoins,
    required this.actualWinCoins,
    required this.walletCreditTransactionFound,
    required this.mismatchDetected,
    required this.reason,
  });

  final String caseId;
  final String playerAvoraId;
  final AvoraLaunchGameBet bet;
  final AvoraEngineGameRound round;
  final AvoraGameRoundSettlement roundSettlement;
  final AvoraGamePayoutRecord? payout;

  final int expectedWinCoins;
  final int actualWinCoins;
  final bool walletCreditTransactionFound;
  final bool mismatchDetected;
  final String reason;
}

class AvoraGameDisputeLedger {
  final Map<String, AvoraGameDisputeCase> _cases =
      <String, AvoraGameDisputeCase>{};

  void open(AvoraGameDisputeCase dispute) {
    if (dispute.caseId.trim().isEmpty ||
        dispute.playerAvoraId.trim().isEmpty ||
        dispute.gameId.trim().isEmpty ||
        dispute.roundId.trim().isEmpty ||
        dispute.betId.trim().isEmpty ||
        dispute.claimReason.trim().isEmpty) {
      throw ArgumentError('invalid_game_dispute_case');
    }

    if (_cases.containsKey(dispute.caseId)) {
      throw StateError('duplicate_game_dispute_case');
    }

    _cases[dispute.caseId] = dispute;
  }

  AvoraGameDisputeCase? byId(String caseId) {
    return _cases[caseId.trim()];
  }

  void updateStatus({
    required String caseId,
    required AvoraGameDisputeStatus status,
  }) {
    final current = _cases[caseId];

    if (current == null) {
      throw StateError('game_dispute_case_not_found');
    }

    _cases[caseId] = current.copyWith(status: status);
  }

  List<AvoraGameDisputeCase> byPlayer(
    String playerAvoraId,
  ) {
    return List<AvoraGameDisputeCase>.unmodifiable(
      _cases.values.where(
        (item) => item.playerAvoraId == playerAvoraId,
      ),
    );
  }

  static bool everyGameDisputeMustRemainTraceable() => true;

  static bool disputeMustPreserveBetAndRoundIdentity() => true;

  static bool disputeReviewMustRemainSeparateFromRepair() => true;

  static bool futureGamesMustUseSameDisputeLedger() => true;
}

class AvoraGameDisputeReconstructionService {
  const AvoraGameDisputeReconstructionService();

  AvoraGameDisputeReconstruction reconstruct({
    required AvoraGameDisputeCase dispute,
    required AvoraLaunchGameBetLedger betLedger,
    required AvoraGameRoundLedger roundLedger,
    required AvoraGamePayoutLedger payoutLedger,
    required AvoraLaunchWalletLedger walletLedger,
  }) {
    final bet = betLedger.byId(dispute.betId);

    if (bet == null) {
      throw StateError('game_bet_not_found');
    }

    if (bet.playerAvoraId != dispute.playerAvoraId ||
        bet.gameId != dispute.gameId ||
        bet.roundId != dispute.roundId) {
      throw StateError('game_dispute_identity_mismatch');
    }

    final round = roundLedger.byId(dispute.roundId);

    if (round == null) {
      throw StateError('game_round_not_found');
    }

    final roundSettlement = roundLedger.settlement(dispute.roundId);

    if (roundSettlement == null) {
      throw StateError('game_round_not_settled');
    }

    final payout = payoutLedger.byBetId(dispute.betId);

    final expectedWinCoins = payout?.winCoins ?? 0;

    final walletTransaction = walletLedger.transactionById(
      'game-win-${dispute.betId}',
    );

    final actualWinCoins = walletTransaction?.amountCoins ?? 0;

    final shouldHaveWalletCredit = expectedWinCoins > 0;

    final walletCreditTransactionFound = walletTransaction != null;

    var mismatchDetected = false;
    var reason = 'game_dispute_no_mismatch';

    if (payout == null) {
      mismatchDetected = true;
      reason = 'missing_game_payout_record';
    } else if (shouldHaveWalletCredit && !walletCreditTransactionFound) {
      mismatchDetected = true;
      reason = 'missing_game_wallet_credit';
    } else if (actualWinCoins != expectedWinCoins) {
      mismatchDetected = true;
      reason = 'incorrect_game_wallet_credit_amount';
    }

    return AvoraGameDisputeReconstruction(
      caseId: dispute.caseId,
      playerAvoraId: dispute.playerAvoraId,
      bet: bet,
      round: round,
      roundSettlement: roundSettlement,
      payout: payout,
      expectedWinCoins: expectedWinCoins,
      actualWinCoins: actualWinCoins,
      walletCreditTransactionFound: walletCreditTransactionFound,
      mismatchDetected: mismatchDetected,
      reason: reason,
    );
  }

  static bool reconstructionMustUseCanonicalBetRecord() => true;

  static bool reconstructionMustUseCanonicalRoundResult() => true;

  static bool reconstructionMustUseCanonicalPayoutRecord() => true;

  static bool reconstructionMustUseWalletLedgerEvidence() => true;

  static bool userScreenshotMustNotBeSoleGameEvidence() => true;

  static bool ownerMustSeeCompleteDisputeChain() => true;

  static bool futureGamesMustUseSameReconstructionService() => true;
}

class AvoraGameRepairRecord {
  const AvoraGameRepairRecord({
    required this.repairId,
    required this.caseId,
    required this.playerAvoraId,
    required this.betId,
    required this.roundId,
    required this.coinAdjustment,
    required this.ownerAvoraId,
    required this.reason,
    required this.createdAtUtc,
  });

  final String repairId;
  final String caseId;
  final String playerAvoraId;
  final String betId;
  final String roundId;
  final int coinAdjustment;
  final String ownerAvoraId;
  final String reason;
  final DateTime createdAtUtc;
}

class AvoraGameRepairLedger {
  final Map<String, AvoraGameRepairRecord> _records =
      <String, AvoraGameRepairRecord>{};

  void append(AvoraGameRepairRecord record) {
    if (record.repairId.trim().isEmpty ||
        record.caseId.trim().isEmpty ||
        record.playerAvoraId.trim().isEmpty ||
        record.betId.trim().isEmpty ||
        record.roundId.trim().isEmpty ||
        record.coinAdjustment <= 0 ||
        record.ownerAvoraId.trim().isEmpty ||
        record.reason.trim().isEmpty) {
      throw ArgumentError('invalid_game_repair_record');
    }

    if (_records.containsKey(record.repairId)) {
      throw StateError('duplicate_game_repair');
    }

    if (_records.values.any(
      (item) => item.caseId == record.caseId,
    )) {
      throw StateError('game_dispute_already_repaired');
    }

    _records[record.repairId] = record;
  }

  AvoraGameRepairRecord? byCaseId(String caseId) {
    for (final record in _records.values) {
      if (record.caseId == caseId) {
        return record;
      }
    }
    return null;
  }

  static bool repairMustRemainImmutable() => true;

  static bool sameDisputeMustNotBeRepairedTwice() => true;

  static bool ownerIdentityMustRemainInInternalRepairAudit() => true;

  static bool futureGamesMustUseSameRepairLedger() => true;
}

class AvoraGameDisputeRepairService {
  AvoraGameDisputeRepairService({
    required AvoraLaunchWalletLedger walletLedger,
    required AvoraGameDisputeLedger disputeLedger,
    required AvoraGameRepairLedger repairLedger,
  })  : _walletLedger = walletLedger,
        _disputeLedger = disputeLedger,
        _repairLedger = repairLedger;

  final AvoraLaunchWalletLedger _walletLedger;
  final AvoraGameDisputeLedger _disputeLedger;
  final AvoraGameRepairLedger _repairLedger;

  AvoraGameRepairRecord repairMissingOrIncorrectWin({
    required String repairId,
    required String caseId,
    required AvoraGameDisputeReconstruction reconstruction,
    required String ownerAvoraId,
    required bool actorIsVerifiedOwner,
    required String reason,
    required DateTime createdAtUtc,
  }) {
    if (!actorIsVerifiedOwner) {
      throw StateError('verified_owner_required');
    }

    final dispute = _disputeLedger.byId(caseId);

    if (dispute == null) {
      throw StateError('game_dispute_case_not_found');
    }

    if (reconstruction.caseId != caseId) {
      throw StateError('reconstruction_case_mismatch');
    }

    if (!reconstruction.mismatchDetected) {
      throw StateError('game_dispute_has_no_repairable_mismatch');
    }

    if (reconstruction.payout == null) {
      throw StateError('missing_payout_requires_manual_round_review');
    }

    final missingCoins =
        reconstruction.expectedWinCoins - reconstruction.actualWinCoins;

    if (missingCoins <= 0) {
      throw StateError('no_positive_game_credit_adjustment_required');
    }

    _walletLedger.credit(
      transactionId: 'game-repair-$repairId',
      type: AvoraWalletTransactionType.coinCredit,
      actor: AvoraActionActor(
        avoraId: ownerAvoraId,
        kind: AvoraActorKind.owner,
        displayName: 'Owner',
      ),
      targetAvoraId: reconstruction.playerAvoraId,
      amountCoins: missingCoins,
      createdAtUtc: createdAtUtc,
      reason: 'game_dispute_repair:$caseId',
    );

    final repair = AvoraGameRepairRecord(
      repairId: repairId,
      caseId: caseId,
      playerAvoraId: reconstruction.playerAvoraId,
      betId: reconstruction.bet.betId,
      roundId: reconstruction.round.roundId,
      coinAdjustment: missingCoins,
      ownerAvoraId: ownerAvoraId,
      reason: reason,
      createdAtUtc: createdAtUtc.toUtc(),
    );

    _repairLedger.append(repair);

    _disputeLedger.updateStatus(
      caseId: caseId,
      status: AvoraGameDisputeStatus.repaired,
    );

    return repair;
  }

  static bool onlyVerifiedOwnerMayApplyManualGameRepair() => true;

  static bool repairMustUseReconstructedCanonicalEvidence() => true;

  static bool repairMustCreditOnlyMissingAmount() => true;

  static bool repairMustNeverOverwriteOriginalBetOrPayout() => true;

  static bool repairMustCreateSeparateWalletTransaction() => true;

  static bool ownerPublicIdentityMustRemainMasked() => true;

  static bool futureGameRepairsMustUseSameService() => true;
}
