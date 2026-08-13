import 'avora_delegated_inspection_denied_audit.dart';

enum AvoraDelegatedInspectionRiskLevel {
  none,
  low,
  medium,
  high,
}

class AvoraDelegatedInspectionRiskDecision {
  const AvoraDelegatedInspectionRiskDecision({
    required this.level,
    required this.deniedAttemptCount,
    required this.requiresOwnerReview,
    required this.reason,
  });

  final AvoraDelegatedInspectionRiskLevel level;
  final int deniedAttemptCount;
  final bool requiresOwnerReview;
  final String reason;
}

class AvoraDelegatedInspectionRiskPolicy {
  const AvoraDelegatedInspectionRiskPolicy();

  AvoraDelegatedInspectionRiskDecision evaluate({
    required String officialAvoraId,
    required DateTime nowUtc,
    required Iterable<AvoraDelegatedInspectionDeniedRecord> records,
    Duration window = const Duration(hours: 24),
  }) {
    if (officialAvoraId.trim().isEmpty || window.isNegative) {
      throw ArgumentError('invalid_inspection_risk_request');
    }

    final start = nowUtc.toUtc().subtract(window);

    final relevant = records.where((record) {
      final time = record.createdAtUtc.toUtc();

      return record.officialAvoraId == officialAvoraId &&
          !time.isBefore(start) &&
          !time.isAfter(nowUtc.toUtc());
    }).toList(growable: false);

    final count = relevant.length;

    if (count >= 10) {
      return AvoraDelegatedInspectionRiskDecision(
        level: AvoraDelegatedInspectionRiskLevel.high,
        deniedAttemptCount: count,
        requiresOwnerReview: true,
        reason: 'repeated_denied_inspection_high_risk',
      );
    }

    if (count >= 5) {
      return AvoraDelegatedInspectionRiskDecision(
        level: AvoraDelegatedInspectionRiskLevel.medium,
        deniedAttemptCount: count,
        requiresOwnerReview: true,
        reason: 'repeated_denied_inspection_review',
      );
    }

    if (count >= 2) {
      return AvoraDelegatedInspectionRiskDecision(
        level: AvoraDelegatedInspectionRiskLevel.low,
        deniedAttemptCount: count,
        requiresOwnerReview: false,
        reason: 'limited_denied_inspection_activity',
      );
    }

    return AvoraDelegatedInspectionRiskDecision(
      level: AvoraDelegatedInspectionRiskLevel.none,
      deniedAttemptCount: count,
      requiresOwnerReview: false,
      reason: 'no_meaningful_inspection_risk',
    );
  }

  static bool deniedAttemptsMayCreateRiskSignal() => true;

  static bool riskSignalMustNotAutoBanOfficial() => true;

  static bool riskSignalMustNotAutoRevokeCapability() => true;

  static bool ownerMustReviewEvidenceBeforePunitiveAction() => true;

  static bool riskEvaluationMustBeTimeWindowed() => true;

  static bool futureInspectionRiskSignalsMustUseSamePolicy() => true;
}

class AvoraInspectionOwnerReviewItem {
  const AvoraInspectionOwnerReviewItem({
    required this.reviewId,
    required this.officialAvoraId,
    required this.level,
    required this.reason,
    required this.deniedAttemptCount,
    required this.createdAtUtc,
  });

  final String reviewId;
  final String officialAvoraId;
  final AvoraDelegatedInspectionRiskLevel level;
  final String reason;
  final int deniedAttemptCount;
  final DateTime createdAtUtc;
}

class AvoraInspectionOwnerReviewQueue {
  final Map<String, AvoraInspectionOwnerReviewItem> _items =
      <String, AvoraInspectionOwnerReviewItem>{};

  void add(AvoraInspectionOwnerReviewItem item) {
    if (item.reviewId.trim().isEmpty ||
        item.officialAvoraId.trim().isEmpty ||
        item.reason.trim().isEmpty ||
        item.deniedAttemptCount < 1) {
      throw ArgumentError('invalid_owner_review_item');
    }

    if (_items.containsKey(item.reviewId)) {
      throw StateError('duplicate_owner_review_item');
    }

    _items[item.reviewId] = item;
  }

  List<AvoraInspectionOwnerReviewItem> get pending =>
      List<AvoraInspectionOwnerReviewItem>.unmodifiable(
        _items.values,
      );

  List<AvoraInspectionOwnerReviewItem> byOfficial(
    String officialAvoraId,
  ) {
    return List<AvoraInspectionOwnerReviewItem>.unmodifiable(
      _items.values.where(
        (item) => item.officialAvoraId == officialAvoraId,
      ),
    );
  }

  static bool ownerReviewQueueMustPreserveSourceOfficial() => true;

  static bool reviewQueueMustNotEqualAutomaticPunishment() => true;

  static bool repeatedMisuseSignalsMustRemainTraceable() => true;
}
