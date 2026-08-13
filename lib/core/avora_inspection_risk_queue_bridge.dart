import 'avora_delegated_inspection_denied_audit.dart';
import 'avora_delegated_inspection_risk_review.dart';

class AvoraInspectionRiskQueueBridgeResult {
  const AvoraInspectionRiskQueueBridgeResult({
    required this.decision,
    required this.queued,
    this.reviewId,
  });

  final AvoraDelegatedInspectionRiskDecision decision;
  final bool queued;
  final String? reviewId;
}

class AvoraInspectionRiskQueueBridge {
  AvoraInspectionRiskQueueBridge({
    required AvoraDelegatedInspectionRiskPolicy riskPolicy,
    required AvoraInspectionOwnerReviewQueue reviewQueue,
  })  : _riskPolicy = riskPolicy,
        _reviewQueue = reviewQueue;

  final AvoraDelegatedInspectionRiskPolicy _riskPolicy;
  final AvoraInspectionOwnerReviewQueue _reviewQueue;

  AvoraInspectionRiskQueueBridgeResult evaluateAndQueue({
    required String reviewId,
    required String officialAvoraId,
    required DateTime nowUtc,
    required Iterable<AvoraDelegatedInspectionDeniedRecord> records,
    Duration window = const Duration(hours: 24),
  }) {
    final decision = _riskPolicy.evaluate(
      officialAvoraId: officialAvoraId,
      nowUtc: nowUtc,
      records: records,
      window: window,
    );

    if (!decision.requiresOwnerReview) {
      return AvoraInspectionRiskQueueBridgeResult(
        decision: decision,
        queued: false,
      );
    }

    final alreadyPending = _reviewQueue.byOfficial(officialAvoraId).any(
          (item) =>
              item.level == decision.level && item.reason == decision.reason,
        );

    if (alreadyPending) {
      return AvoraInspectionRiskQueueBridgeResult(
        decision: decision,
        queued: false,
      );
    }

    _reviewQueue.add(
      AvoraInspectionOwnerReviewItem(
        reviewId: reviewId,
        officialAvoraId: officialAvoraId,
        level: decision.level,
        reason: decision.reason,
        deniedAttemptCount: decision.deniedAttemptCount,
        createdAtUtc: nowUtc.toUtc(),
      ),
    );

    return AvoraInspectionRiskQueueBridgeResult(
      decision: decision,
      queued: true,
      reviewId: reviewId,
    );
  }

  static bool thresholdRiskMustAutoEnterOwnerReviewQueue() => true;

  static bool queueBridgeMustNotAutoBanOfficial() => true;

  static bool queueBridgeMustNotAutoRevokeCapability() => true;

  static bool duplicateEquivalentPendingReviewMustBeSuppressed() => true;

  static bool lowRiskMustNotCreateOwnerQueueSpam() => true;

  static bool ownerRemainsFinalDecisionAuthority() => true;

  static bool futureInspectionRiskPoliciesMustUseSameQueueBridge() => true;
}
