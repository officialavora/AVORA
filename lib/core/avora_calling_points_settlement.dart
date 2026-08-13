import 'avora_calling_points.dart';

enum AvoraCallingPointSettlementStatus {
  pendingDispatch,
  settled,
  retryableFailure,
  duplicateBlocked,
  noReward,
  invalidBeneficiary,
}

class AvoraCallingPointSettlementInstruction {
  const AvoraCallingPointSettlementInstruction({
    required this.settlementKey,
    required this.beneficiaryAvoraId,
    required this.destinationKey,
    required this.settlementAdapterKey,
    required this.rewardUnits,
    required this.callId,
    required this.ruleId,
    required this.ruleVersion,
  });

  /// Stable idempotency key passed to authoritative settlement storage.
  final String settlementKey;

  final String beneficiaryAvoraId;

  /// Logical destination only. Actual balance mutation remains downstream.
  final String destinationKey;

  /// Allows the universal settlement/router layer to select the correct
  /// economic destination without this module mutating balances itself.
  final String settlementAdapterKey;

  final int rewardUnits;

  final String callId;
  final String ruleId;
  final int ruleVersion;
}

class AvoraCallingPointSettlementRecord {
  const AvoraCallingPointSettlementRecord({
    required this.settlementKey,
    required this.status,
    required this.callId,
    required this.callerAvoraId,
    required this.calleeAvoraId,
    required this.beneficiaryAvoraId,
    required this.destinationKey,
    required this.settlementAdapterKey,
    required this.rewardUnits,
    required this.ruleId,
    required this.ruleVersion,
    required this.pointsPerUnit,
    required this.unitSeconds,
    required this.eligibleDurationMicros,
    required this.includeHeldTime,
    required this.includeReconnectingTime,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.ledgerReferenceId,
  });

  final String settlementKey;
  final AvoraCallingPointSettlementStatus status;

  final String callId;
  final String callerAvoraId;
  final String calleeAvoraId;
  final String beneficiaryAvoraId;

  final String destinationKey;
  final String settlementAdapterKey;

  final int rewardUnits;

  /// Immutable Calling Points rule snapshot.
  final String ruleId;
  final int ruleVersion;
  final int pointsPerUnit;
  final int unitSeconds;

  final int eligibleDurationMicros;

  final bool includeHeldTime;
  final bool includeReconnectingTime;

  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  /// Populated only after authoritative downstream settlement succeeds.
  final String ledgerReferenceId;
}

class AvoraCallingPointSettlementPreparation {
  const AvoraCallingPointSettlementPreparation({
    required this.record,
    required this.instruction,
    required this.shouldDispatch,
    required this.reason,
  });

  final AvoraCallingPointSettlementRecord record;
  final AvoraCallingPointSettlementInstruction? instruction;
  final bool shouldDispatch;
  final String reason;
}

class AvoraCallingPointSettlementEngine {
  const AvoraCallingPointSettlementEngine._();

  static String settlementKey({
    required AvoraCallingPointResult points,
    required String beneficiaryAvoraId,
  }) {
    return [
      'calling_points',
      points.callId.trim(),
      beneficiaryAvoraId.trim(),
      points.ruleId.trim(),
      'v${points.ruleVersion}',
    ].join('|');
  }

  static AvoraCallingPointSettlementPreparation prepare({
    required AvoraCallingPointResult points,
    required String beneficiaryAvoraId,
    required Set<String> existingSettlementKeys,
    required DateTime nowUtc,
  }) {
    final beneficiary = beneficiaryAvoraId.trim();
    final now = nowUtc.toUtc();

    final key = settlementKey(
      points: points,
      beneficiaryAvoraId: beneficiary,
    );

    final destinationKey =
        beneficiary.isEmpty ? '' : 'callingPoints:$beneficiary';

    const adapterKey = 'calling_points';

    if (!_isParticipant(
      beneficiaryAvoraId: beneficiary,
      points: points,
    )) {
      return AvoraCallingPointSettlementPreparation(
        record: _record(
          points: points,
          beneficiaryAvoraId: beneficiary,
          destinationKey: destinationKey,
          settlementAdapterKey: adapterKey,
          settlementKey: key,
          status: AvoraCallingPointSettlementStatus.invalidBeneficiary,
          nowUtc: now,
        ),
        instruction: null,
        shouldDispatch: false,
        reason: 'beneficiary_not_call_participant',
      );
    }

    if (!points.ruleMatched || points.points <= 0) {
      return AvoraCallingPointSettlementPreparation(
        record: _record(
          points: points,
          beneficiaryAvoraId: beneficiary,
          destinationKey: destinationKey,
          settlementAdapterKey: adapterKey,
          settlementKey: key,
          status: AvoraCallingPointSettlementStatus.noReward,
          nowUtc: now,
        ),
        instruction: null,
        shouldDispatch: false,
        reason: 'no_reward_units',
      );
    }

    if (existingSettlementKeys.contains(key)) {
      return AvoraCallingPointSettlementPreparation(
        record: _record(
          points: points,
          beneficiaryAvoraId: beneficiary,
          destinationKey: destinationKey,
          settlementAdapterKey: adapterKey,
          settlementKey: key,
          status: AvoraCallingPointSettlementStatus.duplicateBlocked,
          nowUtc: now,
        ),
        instruction: null,
        shouldDispatch: false,
        reason: 'duplicate_settlement_key',
      );
    }

    final record = _record(
      points: points,
      beneficiaryAvoraId: beneficiary,
      destinationKey: destinationKey,
      settlementAdapterKey: adapterKey,
      settlementKey: key,
      status: AvoraCallingPointSettlementStatus.pendingDispatch,
      nowUtc: now,
    );

    final instruction = AvoraCallingPointSettlementInstruction(
      settlementKey: key,
      beneficiaryAvoraId: beneficiary,
      destinationKey: destinationKey,
      settlementAdapterKey: adapterKey,
      rewardUnits: points.points,
      callId: points.callId.trim(),
      ruleId: points.ruleId.trim(),
      ruleVersion: points.ruleVersion,
    );

    return AvoraCallingPointSettlementPreparation(
      record: record,
      instruction: instruction,
      shouldDispatch: true,
      reason: 'ready_for_universal_settlement',
    );
  }

  static AvoraCallingPointSettlementRecord recordDispatchResult({
    required AvoraCallingPointSettlementRecord record,
    required bool settled,
    required String ledgerReferenceId,
    required DateTime nowUtc,
  }) {
    if (record.status != AvoraCallingPointSettlementStatus.pendingDispatch) {
      return record;
    }

    final ledgerReference = ledgerReferenceId.trim();

    if (settled && ledgerReference.isNotEmpty) {
      return _copyRecord(
        record,
        status: AvoraCallingPointSettlementStatus.settled,
        updatedAtUtc: nowUtc.toUtc(),
        ledgerReferenceId: ledgerReference,
      );
    }

    return _copyRecord(
      record,
      status: AvoraCallingPointSettlementStatus.retryableFailure,
      updatedAtUtc: nowUtc.toUtc(),
      ledgerReferenceId: '',
    );
  }

  static AvoraCallingPointSettlementRecord markRetryPending({
    required AvoraCallingPointSettlementRecord record,
    required DateTime nowUtc,
  }) {
    if (record.status != AvoraCallingPointSettlementStatus.retryableFailure) {
      return record;
    }

    return _copyRecord(
      record,
      status: AvoraCallingPointSettlementStatus.pendingDispatch,
      updatedAtUtc: nowUtc.toUtc(),
      ledgerReferenceId: '',
    );
  }

  static bool _isParticipant({
    required String beneficiaryAvoraId,
    required AvoraCallingPointResult points,
  }) {
    if (beneficiaryAvoraId.isEmpty) {
      return false;
    }

    return beneficiaryAvoraId == points.callerAvoraId.trim() ||
        beneficiaryAvoraId == points.calleeAvoraId.trim();
  }

  static AvoraCallingPointSettlementRecord _record({
    required AvoraCallingPointResult points,
    required String beneficiaryAvoraId,
    required String destinationKey,
    required String settlementAdapterKey,
    required String settlementKey,
    required AvoraCallingPointSettlementStatus status,
    required DateTime nowUtc,
  }) {
    return AvoraCallingPointSettlementRecord(
      settlementKey: settlementKey,
      status: status,
      callId: points.callId.trim(),
      callerAvoraId: points.callerAvoraId.trim(),
      calleeAvoraId: points.calleeAvoraId.trim(),
      beneficiaryAvoraId: beneficiaryAvoraId,
      destinationKey: destinationKey,
      settlementAdapterKey: settlementAdapterKey,
      rewardUnits: points.points,
      ruleId: points.ruleId.trim(),
      ruleVersion: points.ruleVersion,
      pointsPerUnit: points.pointsPerUnit,
      unitSeconds: points.unitSeconds,
      eligibleDurationMicros: points.eligibleDuration.inMicroseconds,
      includeHeldTime: points.includeHeldTime,
      includeReconnectingTime: points.includeReconnectingTime,
      createdAtUtc: nowUtc,
      updatedAtUtc: nowUtc,
      ledgerReferenceId: '',
    );
  }

  static AvoraCallingPointSettlementRecord _copyRecord(
    AvoraCallingPointSettlementRecord record, {
    required AvoraCallingPointSettlementStatus status,
    required DateTime updatedAtUtc,
    required String ledgerReferenceId,
  }) {
    return AvoraCallingPointSettlementRecord(
      settlementKey: record.settlementKey,
      status: status,
      callId: record.callId,
      callerAvoraId: record.callerAvoraId,
      calleeAvoraId: record.calleeAvoraId,
      beneficiaryAvoraId: record.beneficiaryAvoraId,
      destinationKey: record.destinationKey,
      settlementAdapterKey: record.settlementAdapterKey,
      rewardUnits: record.rewardUnits,
      ruleId: record.ruleId,
      ruleVersion: record.ruleVersion,
      pointsPerUnit: record.pointsPerUnit,
      unitSeconds: record.unitSeconds,
      eligibleDurationMicros: record.eligibleDurationMicros,
      includeHeldTime: record.includeHeldTime,
      includeReconnectingTime: record.includeReconnectingTime,
      createdAtUtc: record.createdAtUtc,
      updatedAtUtc: updatedAtUtc,
      ledgerReferenceId: ledgerReferenceId,
    );
  }

  /// Calling layer only prepares settlement instructions.
  /// Universal/downstream settlement remains responsible for ledger mutation.
  static bool callingLayerDirectlyCreditsWallet() => false;

  static bool universalSettlementRemainsAuthoritative() => true;

  /// Storage must enforce uniqueness atomically, not merely rely on a UI check.
  static bool settlementKeyRequiresUniqueStorageConstraint() => true;

  static bool settledCallCanBeCreditedAgainWithSameKey() => false;

  static bool historicalRuleSnapshotCanBeRetroactivelyRepriced() => false;

  static bool clientCanAuthoritativelyMarkSettlementAsSettled() => false;
}
