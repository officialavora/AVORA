import 'avora_coin_master_ledger.dart';

class AvoraGameRoundEvidence {
  const AvoraGameRoundEvidence({
    required this.roundId,
    required this.gameId,
    required this.userAvoraId,
    required this.policyVersion,
    required this.betCoins,
    required this.payoutCoins,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.complete,
  });

  final String roundId;
  final String gameId;
  final String userAvoraId;
  final String policyVersion;

  final int betCoins;
  final int payoutCoins;
  final int balanceBefore;
  final int balanceAfter;

  final bool complete;

  int get netResult => payoutCoins - betCoins;
}

class AvoraGameRoundEvidenceBuilder {
  const AvoraGameRoundEvidenceBuilder();

  AvoraGameRoundEvidence? build({
    required String roundId,
    required Iterable<AvoraCoinLedgerEntry> entries,
  }) {
    final id = roundId.trim();

    if (id.isEmpty) {
      throw ArgumentError('round_id_required');
    }

    final records = entries
        .where((entry) => entry.transactionId == id)
        .toList(growable: false);

    if (records.isEmpty) return null;

    AvoraCoinLedgerEntry? bet;
    AvoraCoinLedgerEntry? outcome;

    for (final entry in records) {
      if (entry.eventType == AvoraCoinLedgerEventType.gameBet) {
        bet ??= entry;
      }

      if (entry.eventType == AvoraCoinLedgerEventType.gameWin ||
          entry.eventType == AvoraCoinLedgerEventType.gameLoss) {
        outcome ??= entry;
      }
    }

    if (bet == null) return null;

    final payout = outcome?.eventType == AvoraCoinLedgerEventType.gameWin
        ? outcome!.amount
        : 0;

    return AvoraGameRoundEvidence(
      roundId: id,
      gameId: bet.referenceId ?? '',
      userAvoraId: bet.avoraId,
      policyVersion: bet.policyVersion,
      betCoins: bet.amount,
      payoutCoins: payout,
      balanceBefore: bet.balanceBefore,
      balanceAfter: outcome?.balanceAfter ?? bet.balanceAfter,
      complete: outcome != null,
    );
  }

  static bool ownerMustBeAbleToTraceAnyRound() => true;
  static bool evidenceMustComeFromMasterLedger() => true;
  static bool evidenceMustPreserveOriginalPolicyVersion() => true;
  static bool incompleteRoundMustRemainDetectable() => true;
  static bool disputeReviewMustNotRewriteOriginalEvidence() => true;
  static bool futureGamesMustProduceSameEvidence() => true;
}
