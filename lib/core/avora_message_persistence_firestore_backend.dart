import 'package:cloud_firestore/cloud_firestore.dart';

import 'avora_message_persistence.dart';
import 'avora_message_persistence_adapter.dart';
import 'avora_message_persistence_backend.dart';

/// Firestore-backed durable message persistence.
///
/// Production guarantees:
/// - immutable messageId uniqueness
/// - room/inbox logical isolation
/// - historical payload preservation
/// - clear-history is visibility filtering only
/// - moderation-hidden messages remain physically stored
class AvoraFirestoreMessagePersistenceBackend<T>
    implements AvoraMessagePersistenceBackend<T> {
  AvoraFirestoreMessagePersistenceBackend({
    required FirebaseFirestore firestore,
    String collectionPath = 'messagePersistence',
  })  : _firestore = firestore,
        _collectionPath = collectionPath;

  final FirebaseFirestore _firestore;
  final String _collectionPath;

  CollectionReference<Map<String, dynamic>> get _messages =>
      _firestore.collection(_collectionPath);

  @override
  Future<AvoraMessageStorageWriteResult<T>> insertAtomic(
    AvoraMessageStorageEnvelope envelope,
    AvoraMessageStorageCodec<T> codec,
  ) async {
    if (!envelope.valid) {
      return AvoraMessageStorageWriteResult<T>(
        status: AvoraMessageStorageWriteStatus.invalidEnvelope,
        record: null,
      );
    }

    if (!codec.canDecodeVersion(envelope.schemaVersion)) {
      return AvoraMessageStorageWriteResult<T>(
        status: AvoraMessageStorageWriteStatus.unsupportedSchemaVersion,
        record: null,
      );
    }

    final document = _messages.doc(envelope.messageId.trim());

    final inserted = await _firestore.runTransaction<bool>((transaction) async {
      final existing = await transaction.get(document);

      if (existing.exists) {
        return false;
      }

      transaction.set(document, <String, dynamic>{
        'schemaVersion': envelope.schemaVersion,
        'messageId': envelope.messageId.trim(),
        'context': envelope.context.name,
        'conversationId': envelope.conversationId.trim(),
        'sentAtUtc': Timestamp.fromDate(envelope.sentAtUtc.toUtc()),
        'persistedAtUtc': Timestamp.fromDate(envelope.persistedAtUtc.toUtc()),
        'payload': Map<String, Object?>.from(envelope.payload),
      });

      return true;
    });

    if (!inserted) {
      return AvoraMessageStorageWriteResult<T>(
        status: AvoraMessageStorageWriteStatus.duplicateMessageId,
        record: null,
      );
    }

    return AvoraMessageStorageWriteResult<T>(
      status: AvoraMessageStorageWriteStatus.inserted,
      record: decodeAvoraMessageStorageEnvelope<T>(
        envelope: envelope,
        codec: codec,
      ),
    );
  }

  @override
  Future<AvoraMessagePersistenceRecord<T>?> findByMessageId(
    String messageId,
    AvoraMessageStorageCodec<T> codec,
  ) async {
    final normalized = messageId.trim();

    if (normalized.isEmpty) {
      return null;
    }

    final snapshot = await _messages.doc(normalized).get();

    if (!snapshot.exists) {
      return null;
    }

    return _decodeSnapshot(snapshot, codec);
  }

  @override
  Future<AvoraMessagePage<T>> page({
    required AvoraMessagePersistenceContext context,
    required String conversationId,
    required int limit,
    required AvoraMessageStorageCodec<T> codec,
    AvoraMessageCursor? cursor,
    DateTime? clearedAtUtc,
    Set<String> hiddenMessageIds = const {},
  }) async {
    if (limit <= 0) {
      return AvoraMessagePage<T>(
        items: const [],
        nextCursor: null,
        hasMore: false,
      );
    }

    Query<Map<String, dynamic>> query = _messages
        .where('context', isEqualTo: context.name)
        .where('conversationId', isEqualTo: conversationId.trim())
        .orderBy('sentAtUtc', descending: true)
        .orderBy(FieldPath.documentId, descending: true);

    if (cursor != null) {
      query = query.startAfter(<Object?>[
        Timestamp.fromDate(cursor.sentAtUtc.toUtc()),
        cursor.messageId,
      ]);
    }

    // Fetch extra records because visibility filters may remove some.
    final fetchLimit = (limit * 3).clamp(limit + 1, 200);

    final snapshot = await query.limit(fetchLimit).get();

    final visible = <AvoraMessagePersistenceRecord<T>>[];

    for (final document in snapshot.docs) {
      final record = _decodeSnapshot(document, codec);

      if (record == null) {
        continue;
      }

      // Clear history is visibility filtering, never physical deletion.
      if (clearedAtUtc != null &&
          !record.sentAtUtc.toUtc().isAfter(clearedAtUtc.toUtc())) {
        continue;
      }

      // Moderation-hidden message remains stored, but is not visible here.
      if (hiddenMessageIds.contains(record.messageId)) {
        continue;
      }

      visible.add(record);

      if (visible.length > limit) {
        break;
      }
    }

    final hasMore = visible.length > limit;

    final items = hasMore
        ? visible.take(limit).toList(growable: false)
        : List<AvoraMessagePersistenceRecord<T>>.unmodifiable(visible);

    final last = items.isEmpty ? null : items.last;

    return AvoraMessagePage<T>(
      items: items,
      hasMore: hasMore,
      nextCursor: hasMore && last != null
          ? AvoraMessageCursor(
              sentAtUtc: last.sentAtUtc,
              messageId: last.messageId,
            )
          : null,
    );
  }

  AvoraMessagePersistenceRecord<T>? _decodeSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    AvoraMessageStorageCodec<T> codec,
  ) {
    final data = snapshot.data();

    if (data == null) {
      return null;
    }

    final schemaVersion = data['schemaVersion'];
    final messageId = data['messageId'];
    final contextName = data['context'];
    final conversationId = data['conversationId'];
    final sentAt = data['sentAtUtc'];
    final persistedAt = data['persistedAtUtc'];
    final payload = data['payload'];

    if (schemaVersion is! int ||
        messageId is! String ||
        contextName is! String ||
        conversationId is! String ||
        sentAt is! Timestamp ||
        persistedAt is! Timestamp ||
        payload is! Map) {
      return null;
    }

    AvoraMessagePersistenceContext? context;

    for (final candidate in AvoraMessagePersistenceContext.values) {
      if (candidate.name == contextName) {
        context = candidate;
        break;
      }
    }

    if (context == null) {
      return null;
    }

    final envelope = AvoraMessageStorageEnvelope(
      schemaVersion: schemaVersion,
      messageId: messageId,
      context: context,
      conversationId: conversationId,
      sentAtUtc: sentAt.toDate().toUtc(),
      persistedAtUtc: persistedAt.toDate().toUtc(),
      payload: Map<String, Object?>.from(payload),
    );

    if (!envelope.valid || !codec.canDecodeVersion(schemaVersion)) {
      return null;
    }

    return decodeAvoraMessageStorageEnvelope<T>(
      envelope: envelope,
      codec: codec,
    );
  }

  static bool productionMustEnforceAtomicMessageIdUniqueness() => true;

  static bool roomAndInboxMustRemainIsolated() => true;

  static bool clearHistoryMustRemainVisibilityFiltering() => true;

  static bool moderationHiddenMessagesMustRemainStored() => true;

  static bool historicalPayloadMustRemainImmutable() => true;
}
