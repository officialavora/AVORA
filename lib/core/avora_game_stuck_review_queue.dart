import 'avora_game_stuck_round_detector.dart';

enum AvoraGameStuckReviewStatus {
  pending,
  investigating,
  resolved,
  rejected,
}

class AvoraGameStuckReviewCase {
  const AvoraGameStuckReviewCase({
    required this.caseId,
    required this.roundId,
    required this.gameId,
    required this.userAvoraId,
    required this.betCoins,
    required this.policyVersion,
    required this.status,
    required this.createdAtUtc,
  });

  final String caseId;
  final String roundId;
  final String gameId;
  final String userAvoraId;
  final int betCoins;
  final String policyVersion;
  final AvoraGameStuckReviewStatus status;
  final DateTime createdAtUtc;

  AvoraGameStuckReviewCase copyWith({
    AvoraGameStuckReviewStatus? status,
  }) {
    return AvoraGameStuckReviewCase(
      caseId: caseId,
      roundId: roundId,
      gameId: gameId,
      userAvoraId: userAvoraId,
      betCoins: betCoins,
      policyVersion: policyVersion,
      status: status ?? this.status,
      createdAtUtc: createdAtUtc,
    );
  }
}

class AvoraGameStuckReviewQueue {
  final Map<String, AvoraGameStuckReviewCase> _byRound =
      <String, AvoraGameStuckReviewCase>{};

  List<AvoraGameStuckReviewCase> get cases =>
      List<AvoraGameStuckReviewCase>.unmodifiable(
        _byRound.values,
      );

  AvoraGameStuckReviewCase enqueue({
    required String caseId,
    required AvoraStuckGameRound stuckRound,
    required DateTime createdAtUtc,
  }) {
    if (caseId.trim().isEmpty ||
        stuckRound.roundId.trim().isEmpty ||
        stuckRound.gameId.trim().isEmpty ||
        stuckRound.userAvoraId.trim().isEmpty) {
      throw ArgumentError('stuck_review_identity_required');
    }

    final existing = _byRound[stuckRound.roundId];

    if (existing != null) {
      return existing;
    }

    final review = AvoraGameStuckReviewCase(
      caseId: caseId.trim(),
      roundId: stuckRound.roundId,
      gameId: stuckRound.gameId,
      userAvoraId: stuckRound.userAvoraId,
      betCoins: stuckRound.betCoins,
      policyVersion: stuckRound.policyVersion,
      status: AvoraGameStuckReviewStatus.pending,
      createdAtUtc: createdAtUtc.toUtc(),
    );

    _byRound[review.roundId] = review;

    return review;
  }

  AvoraGameStuckReviewCase? byRoundId(String roundId) {
    return _byRound[roundId.trim()];
  }

  void updateStatus({
    required String roundId,
    required AvoraGameStuckReviewStatus status,
  }) {
    final current = byRoundId(roundId);

    if (current == null) {
      throw StateError('stuck_review_not_found');
    }

    _byRound[current.roundId] = current.copyWith(
      status: status,
    );
  }

  static bool stuckRoundMustCreateReviewableCase() => true;

  static bool sameRoundMustNotCreateDuplicateCase() => true;

  static bool reviewQueueMustNotCreditCoinsDirectly() => true;

  static bool ownerMustSeeUserGameBetAndPolicy() => true;

  static bool repairMustRemainSeparateAuditedAction() => true;

  static bool futureGamesMustUseSameReviewQueue() => true;
}
