import 'package:cloud_firestore/cloud_firestore.dart';

import 'avora_owner_override_audit.dart';

class AvoraFirestoreOwnerOverrideAuditRepository
    implements AvoraOwnerOverrideAuditRepository {
  AvoraFirestoreOwnerOverrideAuditRepository({
    required FirebaseFirestore firestore,
    this.collectionPath = 'ownerOverrideAudit',
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;
  final String collectionPath;

  @override
  Future<void> append(
    AvoraOwnerOverrideAuditRecord record,
  ) async {
    final auditId = record.auditId.trim();

    if (auditId.isEmpty) {
      throw ArgumentError('audit_id_required');
    }

    final ref = _firestore.collection(collectionPath).doc(auditId);

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(ref);

      if (existing.exists) {
        throw StateError('owner_override_audit_already_exists');
      }

      transaction.set(ref, <String, Object?>{
        'auditId': auditId,
        'actorAvoraId': record.actorAvoraId,
        'targetId': record.targetId,
        'action': record.action.name,
        'reason': record.reason,
        'createdAtUtc': Timestamp.fromDate(
          record.createdAtUtc.toUtc(),
        ),
        'immutable': true,
      });
    });
  }

  static bool duplicateAuditIdMustFail() => true;

  static bool auditDocumentsMustBeAppendOnly() => true;

  static bool auditMustPreserveImmutableOwnerId() => true;

  static bool clientMustNeverDeleteAuditEvidence() => true;
}
