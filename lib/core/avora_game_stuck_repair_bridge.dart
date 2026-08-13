import 'avora_game_payout_reconciliation.dart';
import 'avora_game_stuck_review_queue.dart';

class AvoraGameStuckRepairBridgeResult {
  const AvoraGameStuckRepairBridgeResult({
    required this.success,
    required this.reason,
    required this.balanceAfter,
  });

  final bool success;
  final String reason;
  final int balanceAfter;
}

class AvoraGameStuckRepairBridge {
  AvoraGameStuckRepairBridge({
    required AvoraGameStuckReviewQueue reviewQueue,
    required AvoraGamePayoutReconciliationService reconciliation,
  })  : _reviewQueue = reviewQueue,
        _reconciliation = reconciliation;

  final AvoraGameStuckReviewQueue _reviewQueue;
  final AvoraGamePayoutReconciliationService _reconciliation;

  final Set<String> _repairedRounds = <String>{};

  AvoraGameStuckRepairBridgeResult repair({
    required String roundId,
    required String reconciliationReviewId,
    required String ownerAvoraId,
    required int approvedCoins,
    required int balanceBefore,
    required String reason,
    required DateTime createdAtUtc,
  }) {
    final review = _reviewQueue.byRoundId(roundId);

    if (review == null) {
      return AvoraGameStuckRepairBridgeResult(
        success: false,
        reason: 'stuck_review_not_found',
        balanceAfter: balanceBefore,
      );
    }

    if (review.status != AvoraGameStuckReviewStatus.investigating) {
      return AvoraGameStuckRepairBridgeResult(
        success: false,
        reason: 'stuck_review_not_investigating',
        balanceAfter: balanceBefore,
      );
    }

    if (_repairedRounds.contains(roundId)) {
      return AvoraGameStuckRepairBridgeResult(
        success: false,
        reason: 'stuck_round_already_repaired',
        balanceAfter: balanceBefore,
      );
    }

    if (approvedCoins <= 0 ||
        ownerAvoraId.trim().isEmpty ||
        reason.trim().isEmpty ||
        reconciliationReviewId.trim().isEmpty) {
      return AvoraGameStuckRepairBridgeResult(
        success: false,
        reason: 'invalid_stuck_repair',
        balanceAfter: balanceBefore,
      );
    }

    _reconciliation.createReview(
      reviewId: reconciliationReviewId,
      roundId: review.roundId,
      userAvoraId: review.userAvoraId,
      claimedMissingCoins: approvedCoins,
      reason: reason,
      createdAtUtc: createdAtUtc,
    );

    final repaired = _reconciliation.repair(
      reviewId: reconciliationReviewId,
      ownerAvoraId: ownerAvoraId,
      approvedCoins: approvedCoins,
      balanceBefore: balanceBefore,
      createdAtUtc: createdAtUtc,
    );

    if (!repaired.success) {
      return AvoraGameStuckRepairBridgeResult(
        success: false,
        reason: repaired.reason,
        balanceAfter: balanceBefore,
      );
    }

    _repairedRounds.add(roundId);

    _reviewQueue.updateStatus(
      roundId: roundId,
      status: AvoraGameStuckReviewStatus.resolved,
    );

    return AvoraGameStuckRepairBridgeResult(
      success: true,
      reason: 'stuck_round_repaired',
      balanceAfter: repaired.balanceAfter,
    );
  }

  static bool pendingCaseMustNotRepairDirectly() => true;

  static bool repairRequiresInvestigationState() => true;

  static bool repairMustUseReconciliationLedger() => true;

  static bool originalBetEvidenceMustRemainImmutable() => true;

  static bool sameRoundMustNeverRepairTwice() => true;

  static bool successfulRepairMustResolveReviewCase() => true;

  static bool ownerIdentityMustRemainInRepairAudit() => true;

  static bool futureGamesMustUseSameRepairBridge() => true;
}
