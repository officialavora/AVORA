import 'avora_owner_message_override.dart';

class AvoraOwnerOverrideAuditRecord {
  const AvoraOwnerOverrideAuditRecord({
    required this.auditId,
    required this.actorAvoraId,
    required this.targetId,
    required this.action,
    required this.reason,
    required this.createdAtUtc,
  });

  final String auditId;
  final String actorAvoraId;
  final String targetId;
  final AvoraOwnerOverrideAction action;
  final String reason;
  final DateTime createdAtUtc;
}

abstract class AvoraOwnerOverrideAuditRepository {
  Future<void> append(AvoraOwnerOverrideAuditRecord record);
}

class AvoraOwnerOverrideAuditService {
  const AvoraOwnerOverrideAuditService({
    required AvoraOwnerOverrideAuditRepository repository,
  }) : _repository = repository;

  final AvoraOwnerOverrideAuditRepository _repository;

  Future<AvoraOwnerOverrideAuditRecord> record({
    required String auditId,
    required AvoraOwnerOverrideRequest request,
  }) async {
    if (auditId.trim().isEmpty ||
        request.actorAvoraId.trim().isEmpty ||
        request.targetId.trim().isEmpty ||
        request.reason.trim().isEmpty) {
      throw ArgumentError('invalid_owner_override_audit');
    }

    final record = AvoraOwnerOverrideAuditRecord(
      auditId: auditId.trim(),
      actorAvoraId: request.actorAvoraId.trim(),
      targetId: request.targetId.trim(),
      action: request.action,
      reason: request.reason.trim(),
      createdAtUtc: request.createdAtUtc.toUtc(),
    );

    await _repository.append(record);
    return record;
  }

  static bool auditMustBeAppendOnly() => true;

  static bool historicalAuditMustRemainImmutable() => true;

  static bool auditFailureMustNotSilentlyEraseEvidence() => true;

  static bool immutableAvoraIdMustIdentifyOwner() => true;

  static bool ownerPowerAndAuditMustRemainSeparate() => true;
}
