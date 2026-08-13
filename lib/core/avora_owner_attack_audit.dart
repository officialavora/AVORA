import 'avora_owner_protected_enforcement.dart';

class AvoraOwnerAttackAuditRecord {
  const AvoraOwnerAttackAuditRecord({
    required this.auditId,
    required this.actorAvoraId,
    required this.ownerAvoraId,
    required this.action,
    required this.reason,
    required this.createdAtUtc,
  });

  final String auditId;
  final String actorAvoraId;
  final String ownerAvoraId;
  final AvoraProtectedEnforcementAction action;
  final String reason;
  final DateTime createdAtUtc;
}

class AvoraOwnerAttackAuditLedger {
  final Map<String, AvoraOwnerAttackAuditRecord> _records =
      <String, AvoraOwnerAttackAuditRecord>{};

  void append(AvoraOwnerAttackAuditRecord record) {
    if (record.auditId.trim().isEmpty ||
        record.actorAvoraId.trim().isEmpty ||
        record.ownerAvoraId.trim().isEmpty ||
        record.reason.trim().isEmpty) {
      throw ArgumentError('invalid_owner_attack_audit');
    }

    if (_records.containsKey(record.auditId)) {
      throw StateError('duplicate_owner_attack_audit');
    }

    _records[record.auditId] = record;
  }

  List<AvoraOwnerAttackAuditRecord> forOwner(
    String ownerAvoraId,
  ) {
    return List<AvoraOwnerAttackAuditRecord>.unmodifiable(
      _records.values.where(
        (record) => record.ownerAvoraId == ownerAvoraId,
      ),
    );
  }

  List<AvoraOwnerAttackAuditRecord> byActor(
    String actorAvoraId,
  ) {
    return List<AvoraOwnerAttackAuditRecord>.unmodifiable(
      _records.values.where(
        (record) => record.actorAvoraId == actorAvoraId,
      ),
    );
  }

  static bool blockedOwnerAttackMustCreateEvidence() => true;

  static bool attackHistoryMustRemainImmutable() => true;

  static bool ownerMustSeeWhoAttemptedAction() => true;

  static bool ownerMustSeeAttemptedActionType() => true;

  static bool futureOwnerProtectionFailuresMustUseSameLedger() => true;
}
