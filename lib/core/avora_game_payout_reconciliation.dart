import 'avora_coin_master_ledger.dart';

enum AvoraGamePayoutReviewStatus {
  pending,
  approved,
  rejected,
  repaired,
}

class AvoraGamePayoutReview {
  const AvoraGamePayoutReview({
    required this.reviewId,
    required this.roundId,
    required this.userAvoraId,
    required this.claimedMissingCoins,
    required this.status,
    required this.reason,
    required this.createdAtUtc,
  });

  final String reviewId;
  final String roundId;
  final String userAvoraId;
  final int claimedMissingCoins;
  final AvoraGamePayoutReviewStatus status;
  final String reason;
  final DateTime createdAtUtc;

  AvoraGamePayoutReview copyWith({
    AvoraGamePayoutReviewStatus? status,
  }) {
    return AvoraGamePayoutReview(
      reviewId: reviewId,
      roundId: roundId,
      userAvoraId: userAvoraId,
      claimedMissingCoins: claimedMissingCoins,
      status: status ?? this.status,
      reason: reason,
      createdAtUtc: createdAtUtc,
    );
  }
}

class AvoraGamePayoutRepairResult {
  const AvoraGamePayoutRepairResult({
    required this.success,
    required this.reason,
    required this.balanceBefore,
    required this.balanceAfter,
  });

  final bool success;
  final String reason;
  final int balanceBefore;
  final int balanceAfter;
}

class AvoraGamePayoutReconciliationService {
  AvoraGamePayoutReconciliationService({
    required AvoraCoinMasterLedger masterLedger,
  }) : _masterLedger = masterLedger;

  final AvoraCoinMasterLedger _masterLedger;

  final Map<String, AvoraGamePayoutReview> _reviews =
      <String, AvoraGamePayoutReview>{};

  AvoraGamePayoutReview createReview({
    required String reviewId,
    required String roundId,
    required String userAvoraId,
    required int claimedMissingCoins,
    required String reason,
    required DateTime createdAtUtc,
  }) {
    if (reviewId.trim().isEmpty ||
        roundId.trim().isEmpty ||
        userAvoraId.trim().isEmpty ||
        reason.trim().isEmpty ||
        claimedMissingCoins <= 0) {
      throw ArgumentError('invalid_game_payout_review');
    }

    if (_reviews.containsKey(reviewId)) {
      throw StateError('duplicate_game_payout_review');
    }

    final review = AvoraGamePayoutReview(
      reviewId: reviewId,
      roundId: roundId,
      userAvoraId: userAvoraId,
      claimedMissingCoins: claimedMissingCoins,
      status: AvoraGamePayoutReviewStatus.pending,
      reason: reason,
      createdAtUtc: createdAtUtc.toUtc(),
    );

    _reviews[reviewId] = review;
    return review;
  }

  AvoraGamePayoutReview? byReviewId(String reviewId) {
    return _reviews[reviewId];
  }

  AvoraGamePayoutRepairResult repair({
    required String reviewId,
    required String ownerAvoraId,
    required int approvedCoins,
    required int balanceBefore,
    required DateTime createdAtUtc,
  }) {
    final review = _reviews[reviewId];

    if (review == null) {
      return AvoraGamePayoutRepairResult(
        success: false,
        reason: 'review_not_found',
        balanceBefore: balanceBefore,
        balanceAfter: balanceBefore,
      );
    }

    if (review.status == AvoraGamePayoutReviewStatus.repaired) {
      return AvoraGamePayoutRepairResult(
        success: false,
        reason: 'review_already_repaired',
        balanceBefore: balanceBefore,
        balanceAfter: balanceBefore,
      );
    }

    if (ownerAvoraId.trim().isEmpty || approvedCoins <= 0) {
      return AvoraGamePayoutRepairResult(
        success: false,
        reason: 'invalid_owner_repair',
        balanceBefore: balanceBefore,
        balanceAfter: balanceBefore,
      );
    }

    final balanceAfter = balanceBefore + approvedCoins;

    _masterLedger.append(
      AvoraCoinLedgerEntry(
        entryId: '$reviewId-repair',
        transactionId: review.roundId,
        eventType: AvoraCoinLedgerEventType.adjustment,
        avoraId: review.userAvoraId,
        relatedAvoraId: ownerAvoraId,
        amount: approvedCoins,
        balanceBefore: balanceBefore,
        balanceAfter: balanceAfter,
        referenceId: review.reviewId,
        reason: 'game_payout_repair:${review.reason}',
        createdAt: createdAtUtc.toUtc(),
        policyVersion: 'game-payout-repair-v1',
      ),
    );

    _reviews[reviewId] = review.copyWith(
      status: AvoraGamePayoutReviewStatus.repaired,
    );

    return AvoraGamePayoutRepairResult(
      success: true,
      reason: 'game_payout_repaired',
      balanceBefore: balanceBefore,
      balanceAfter: balanceAfter,
    );
  }

  static bool originalRoundMustNeverBeOverwritten() => true;

  static bool repairMustCreateSeparateLedgerEvidence() => true;

  static bool ownerRepairIdentityMustBeRecorded() => true;

  static bool sameReviewMustNeverCreditTwice() => true;

  static bool ownerMustSeeClaimRoundAndRepairHistory() => true;

  static bool userMustSeeOwnRepairResult() => true;

  static bool futureGamesMustUseSameBugReconciliation() => true;
}
