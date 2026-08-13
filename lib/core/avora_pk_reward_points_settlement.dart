import 'avora_pk_reward_points.dart';

enum AvoraPkRewardSettlementStatus {
  pendingDispatch,
  settled,
  retryableFailure,
  duplicateBlocked,
  noReward,
  invalidPkId,
  invalidBeneficiary,
}

class AvoraPkRewardSettlementInstruction {
  const AvoraPkRewardSettlementInstruction({
    required this.settlementKey,
    required this.pkId,
    required this.beneficiaryAvoraId,
    required this.destinationKey,
    required this.settlementAdapterKey,
    required this.rewardUnits,
    required this.ruleId,
    required this.ruleVersion,
  });

  final String settlementKey;

  /// Authoritative unique PK/match identifier.
  final String pkId;

  final String beneficiaryAvoraId;

  /// Logical economic destination.
  /// Actual balance mutation remains downstream.
  final String destinationKey;

  final String settlementAdapterKey;

  final int rewardUnits;

  final String ruleId;
  final int ruleVersion;
}

class AvoraPkRewardSettlementRecord {
  const AvoraPkRewardSettlementRecord({
    required this.settlementKey,
    required this.status,
    required this.pkId,
    required this.beneficiaryAvoraId,
    required this.destinationKey,
    required this.settlementAdapterKey,
    required this.rewardUnits,
    required this.ruleId,
    required this.ruleVersion,
    required this.outcomeType,
    required this.participationPoints,
    required this.outcomePoints,
    required this.streakBonusPoints,
    required this.multiplierBasisPoints,
    required this.pointsBeforeCaps,
    required this.perPkCapApplied,
    required this.dailyCapApplied,
    required this.pointsAlreadyEarnedToday,
    required this.competitionPointDelta,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.ledgerReferenceId,
  });

  final String settlementKey;
  final AvoraPkRewardSettlementStatus status;

  final String pkId;
  final String beneficiaryAvoraId;

  final String destinationKey;
  final String settlementAdapterKey;

  final int rewardUnits;

  /// Immutable PK reward-policy snapshot.
  final String ruleId;
  final int ruleVersion;
  final AvoraPkRewardPointOutcomeType outcomeType;

  final int participationPoints;
  final int outcomePoints;
  final int streakBonusPoints;
  final int multiplierBasisPoints;
  final int pointsBeforeCaps;

  final bool perPkCapApplied;
  final bool dailyCapApplied;
  final int pointsAlreadyEarnedToday;

  /// Existing PK competition score remains separate.
  final int competitionPointDelta;

  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  /// Authoritative downstream ledger reference after settlement.
  final String ledgerReferenceId;
}

class AvoraPkRewardSettlementPreparation {
  const AvoraPkRewardSettlementPreparation({
    required this.record,
    required this.instruction,
    required this.shouldDispatch,
    required this.reason,
  });

  final AvoraPkRewardSettlementRecord record;
  final AvoraPkRewardSettlementInstruction? instruction;
  final bool shouldDispatch;
  final String reason;
}

class AvoraPkRewardSettlementEngine {
  const AvoraPkRewardSettlementEngine._();

  static String settlementKey({
    required String pkId,
    required AvoraPkRewardPointResult reward,
    required String beneficiaryAvoraId,
  }) {
    return [
      'pk_reward_points',
      pkId.trim(),
      beneficiaryAvoraId.trim(),
      reward.ruleId.trim(),
      'v${reward.ruleVersion}',
    ].join('|');
  }

  static AvoraPkRewardSettlementPreparation prepare({
    required String pkId,
    required AvoraPkRewardPointResult reward,
    required String beneficiaryAvoraId,
    required Set<String> existingSettlementKeys,
    required DateTime nowUtc,
  }) {
    final normalizedPkId = pkId.trim();
    final beneficiary = beneficiaryAvoraId.trim();
    final now = nowUtc.toUtc();

    final key = settlementKey(
      pkId: normalizedPkId,
      reward: reward,
      beneficiaryAvoraId: beneficiary,
    );

    final destinationKey =
        beneficiary.isEmpty ? '' : 'pkRewardPoints:$beneficiary';

    const settlementAdapterKey = 'pk_reward_points';

    if (normalizedPkId.isEmpty) {
      return AvoraPkRewardSettlementPreparation(
        record: _record(
          pkId: normalizedPkId,
          reward: reward,
          beneficiaryAvoraId: beneficiary,
          destinationKey: destinationKey,
          settlementAdapterKey: settlementAdapterKey,
          settlementKey: key,
          status: AvoraPkRewardSettlementStatus.invalidPkId,
          nowUtc: now,
        ),
        instruction: null,
        shouldDispatch: false,
        reason: 'invalid_pk_id',
      );
    }

    if (beneficiary.isEmpty || beneficiary != reward.userAvoraId.trim()) {
      return AvoraPkRewardSettlementPreparation(
        record: _record(
          pkId: normalizedPkId,
          reward: reward,
          beneficiaryAvoraId: beneficiary,
          destinationKey: destinationKey,
          settlementAdapterKey: settlementAdapterKey,
          settlementKey: key,
          status: AvoraPkRewardSettlementStatus.invalidBeneficiary,
          nowUtc: now,
        ),
        instruction: null,
        shouldDispatch: false,
        reason: 'beneficiary_does_not_match_pk_outcome_user',
      );
    }

    if (!reward.ruleMatched || !reward.eligible || reward.points <= 0) {
      return AvoraPkRewardSettlementPreparation(
        record: _record(
          pkId: normalizedPkId,
          reward: reward,
          beneficiaryAvoraId: beneficiary,
          destinationKey: destinationKey,
          settlementAdapterKey: settlementAdapterKey,
          settlementKey: key,
          status: AvoraPkRewardSettlementStatus.noReward,
          nowUtc: now,
        ),
        instruction: null,
        shouldDispatch: false,
        reason: 'no_reward_units',
      );
    }

    if (existingSettlementKeys.contains(key)) {
      return AvoraPkRewardSettlementPreparation(
        record: _record(
          pkId: normalizedPkId,
          reward: reward,
          beneficiaryAvoraId: beneficiary,
          destinationKey: destinationKey,
          settlementAdapterKey: settlementAdapterKey,
          settlementKey: key,
          status: AvoraPkRewardSettlementStatus.duplicateBlocked,
          nowUtc: now,
        ),
        instruction: null,
        shouldDispatch: false,
        reason: 'duplicate_settlement_key',
      );
    }

    final record = _record(
      pkId: normalizedPkId,
      reward: reward,
      beneficiaryAvoraId: beneficiary,
      destinationKey: destinationKey,
      settlementAdapterKey: settlementAdapterKey,
      settlementKey: key,
      status: AvoraPkRewardSettlementStatus.pendingDispatch,
      nowUtc: now,
    );

    final instruction = AvoraPkRewardSettlementInstruction(
      settlementKey: key,
      pkId: normalizedPkId,
      beneficiaryAvoraId: beneficiary,
      destinationKey: destinationKey,
      settlementAdapterKey: settlementAdapterKey,
      rewardUnits: reward.points,
      ruleId: reward.ruleId.trim(),
      ruleVersion: reward.ruleVersion,
    );

    return AvoraPkRewardSettlementPreparation(
      record: record,
      instruction: instruction,
      shouldDispatch: true,
      reason: 'ready_for_universal_settlement',
    );
  }

  static AvoraPkRewardSettlementRecord recordDispatchResult({
    required AvoraPkRewardSettlementRecord record,
    required bool settled,
    required String ledgerReferenceId,
    required DateTime nowUtc,
  }) {
    if (record.status != AvoraPkRewardSettlementStatus.pendingDispatch) {
      return record;
    }

    final ledgerReference = ledgerReferenceId.trim();

    if (settled && ledgerReference.isNotEmpty) {
      return _copy(
        record,
        status: AvoraPkRewardSettlementStatus.settled,
        updatedAtUtc: nowUtc.toUtc(),
        ledgerReferenceId: ledgerReference,
      );
    }

    return _copy(
      record,
      status: AvoraPkRewardSettlementStatus.retryableFailure,
      updatedAtUtc: nowUtc.toUtc(),
      ledgerReferenceId: '',
    );
  }

  static AvoraPkRewardSettlementRecord markRetryPending({
    required AvoraPkRewardSettlementRecord record,
    required DateTime nowUtc,
  }) {
    if (record.status != AvoraPkRewardSettlementStatus.retryableFailure) {
      return record;
    }

    return _copy(
      record,
      status: AvoraPkRewardSettlementStatus.pendingDispatch,
      updatedAtUtc: nowUtc.toUtc(),
      ledgerReferenceId: '',
    );
  }

  static AvoraPkRewardSettlementRecord _record({
    required String pkId,
    required AvoraPkRewardPointResult reward,
    required String beneficiaryAvoraId,
    required String destinationKey,
    required String settlementAdapterKey,
    required String settlementKey,
    required AvoraPkRewardSettlementStatus status,
    required DateTime nowUtc,
  }) {
    return AvoraPkRewardSettlementRecord(
      settlementKey: settlementKey,
      status: status,
      pkId: pkId,
      beneficiaryAvoraId: beneficiaryAvoraId,
      destinationKey: destinationKey,
      settlementAdapterKey: settlementAdapterKey,
      rewardUnits: reward.points,
      ruleId: reward.ruleId.trim(),
      ruleVersion: reward.ruleVersion,
      outcomeType: reward.outcomeType,
      participationPoints: reward.participationPoints,
      outcomePoints: reward.outcomePoints,
      streakBonusPoints: reward.streakBonusPoints,
      multiplierBasisPoints: reward.multiplierBasisPoints,
      pointsBeforeCaps: reward.pointsBeforeCaps,
      perPkCapApplied: reward.perPkCapApplied,
      dailyCapApplied: reward.dailyCapApplied,
      pointsAlreadyEarnedToday: reward.pointsAlreadyEarnedToday,
      competitionPointDelta: reward.competitionPointDelta,
      createdAtUtc: nowUtc,
      updatedAtUtc: nowUtc,
      ledgerReferenceId: '',
    );
  }

  static AvoraPkRewardSettlementRecord _copy(
    AvoraPkRewardSettlementRecord record, {
    required AvoraPkRewardSettlementStatus status,
    required DateTime updatedAtUtc,
    required String ledgerReferenceId,
  }) {
    return AvoraPkRewardSettlementRecord(
      settlementKey: record.settlementKey,
      status: status,
      pkId: record.pkId,
      beneficiaryAvoraId: record.beneficiaryAvoraId,
      destinationKey: record.destinationKey,
      settlementAdapterKey: record.settlementAdapterKey,
      rewardUnits: record.rewardUnits,
      ruleId: record.ruleId,
      ruleVersion: record.ruleVersion,
      outcomeType: record.outcomeType,
      participationPoints: record.participationPoints,
      outcomePoints: record.outcomePoints,
      streakBonusPoints: record.streakBonusPoints,
      multiplierBasisPoints: record.multiplierBasisPoints,
      pointsBeforeCaps: record.pointsBeforeCaps,
      perPkCapApplied: record.perPkCapApplied,
      dailyCapApplied: record.dailyCapApplied,
      pointsAlreadyEarnedToday: record.pointsAlreadyEarnedToday,
      competitionPointDelta: record.competitionPointDelta,
      createdAtUtc: record.createdAtUtc,
      updatedAtUtc: updatedAtUtc,
      ledgerReferenceId: ledgerReferenceId,
    );
  }

  static bool pkRewardLayerDirectlyCreditsWallet() => false;

  static bool universalSettlementRemainsAuthoritative() => true;

  static bool settlementKeyRequiresAtomicUniqueConstraint() => true;

  static bool samePkRewardCanSettleTwiceWithSameKey() => false;

  static bool settlementCanRewriteCompetitionPointDelta() => false;

  static bool historicalRewardPolicyCanBeRetroactivelyRepriced() => false;

  static bool clientCanMarkPkRewardSettledAuthoritatively() => false;
}
