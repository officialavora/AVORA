import 'avora_message_persistence.dart';

enum AvoraMessageStorageWriteStatus {
  inserted,
  duplicateMessageId,
  invalidEnvelope,
  unsupportedSchemaVersion,
}

class AvoraMessageStorageEnvelope {
  const AvoraMessageStorageEnvelope({
    required this.schemaVersion,
    required this.messageId,
    required this.context,
    required this.conversationId,
    required this.sentAtUtc,
    required this.persistedAtUtc,
    required this.payload,
  });

  final int schemaVersion;
  final String messageId;
  final AvoraMessagePersistenceContext context;
  final String conversationId;
  final DateTime sentAtUtc;
  final DateTime persistedAtUtc;
  final Map<String, Object?> payload;

  bool get valid =>
      schemaVersion > 0 &&
      messageId.trim().isNotEmpty &&
      conversationId.trim().isNotEmpty &&
      !persistedAtUtc.toUtc().isBefore(sentAtUtc.toUtc());
}

abstract class AvoraMessageStorageCodec<T> {
  const AvoraMessageStorageCodec();

  int get currentSchemaVersion;

  bool canDecodeVersion(int version);

  Map<String, Object?> encodePayload(T value);

  T decodePayload({
    required int schemaVersion,
    required Map<String, Object?> payload,
  });
}

class AvoraMessageStorageWriteResult<T> {
  const AvoraMessageStorageWriteResult({
    required this.status,
    required this.record,
  });

  final AvoraMessageStorageWriteStatus status;
  final AvoraMessagePersistenceRecord<T>? record;

  bool get inserted => status == AvoraMessageStorageWriteStatus.inserted;
}

AvoraMessageStorageEnvelope encodeAvoraMessageStorageEnvelope<T>({
  required AvoraMessagePersistenceRecord<T> record,
  required AvoraMessageStorageCodec<T> codec,
}) {
  return AvoraMessageStorageEnvelope(
    schemaVersion: codec.currentSchemaVersion,
    messageId: record.messageId.trim(),
    context: record.context,
    conversationId: record.conversationId.trim(),
    sentAtUtc: record.sentAtUtc.toUtc(),
    persistedAtUtc: record.persistedAtUtc.toUtc(),
    payload: Map.unmodifiable(
      codec.encodePayload(record.payload),
    ),
  );
}

AvoraMessagePersistenceRecord<T> decodeAvoraMessageStorageEnvelope<T>({
  required AvoraMessageStorageEnvelope envelope,
  required AvoraMessageStorageCodec<T> codec,
}) {
  if (!envelope.valid) {
    throw ArgumentError('Invalid message storage envelope.');
  }

  if (!codec.canDecodeVersion(envelope.schemaVersion)) {
    throw ArgumentError(
      'Unsupported message schema version: '
      '${envelope.schemaVersion}',
    );
  }

  return AvoraMessagePersistenceRecord<T>(
    messageId: envelope.messageId.trim(),
    context: envelope.context,
    conversationId: envelope.conversationId.trim(),
    sentAtUtc: envelope.sentAtUtc.toUtc(),
    persistedAtUtc: envelope.persistedAtUtc.toUtc(),
    payload: codec.decodePayload(
      schemaVersion: envelope.schemaVersion,
      payload: envelope.payload,
    ),
  );
}

abstract class AvoraMessagePersistenceStorageAdapter<T> {
  Future<AvoraMessageStorageWriteResult<T>> insertAtomic(
    AvoraMessageStorageEnvelope envelope,
  );

  Future<AvoraMessagePersistenceRecord<T>?> findByMessageId(
    String messageId,
  );

  Future<AvoraMessagePage<T>> page({
    required AvoraMessagePersistenceContext context,
    required String conversationId,
    required int limit,
    AvoraMessageCursor? cursor,
    DateTime? clearedAtUtc,
    Set<String> hiddenMessageIds = const {},
  });
}

/// Reference adapter used to lock storage semantics before wiring a
/// production backend such as Firestore/Postgres/custom API.
///
/// Production implementations must preserve identical uniqueness,
/// pagination and visibility behavior.
class AvoraInMemoryMessageStorageAdapter<T>
    implements AvoraMessagePersistenceStorageAdapter<T> {
  AvoraInMemoryMessageStorageAdapter({
    required this.codec,
  }) : _repository = AvoraInMemoryMessagePersistenceRepository<T>();

  final AvoraMessageStorageCodec<T> codec;

  AvoraInMemoryMessagePersistenceRepository<T> _repository;

  @override
  Future<AvoraMessageStorageWriteResult<T>> insertAtomic(
    AvoraMessageStorageEnvelope envelope,
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

    if (_repository.findByMessageId(envelope.messageId) != null) {
      return AvoraMessageStorageWriteResult<T>(
        status: AvoraMessageStorageWriteStatus.duplicateMessageId,
        record: null,
      );
    }

    final decoded = decodeAvoraMessageStorageEnvelope<T>(
      envelope: envelope,
      codec: codec,
    );

    final inserted = _repository.insert(decoded);

    if (!inserted.inserted) {
      return AvoraMessageStorageWriteResult<T>(
        status: AvoraMessageStorageWriteStatus.duplicateMessageId,
        record: null,
      );
    }

    _repository = inserted.repository;

    return AvoraMessageStorageWriteResult<T>(
      status: AvoraMessageStorageWriteStatus.inserted,
      record: decoded,
    );
  }

  @override
  Future<AvoraMessagePersistenceRecord<T>?> findByMessageId(
    String messageId,
  ) async {
    return _repository.findByMessageId(messageId);
  }

  @override
  Future<AvoraMessagePage<T>> page({
    required AvoraMessagePersistenceContext context,
    required String conversationId,
    required int limit,
    AvoraMessageCursor? cursor,
    DateTime? clearedAtUtc,
    Set<String> hiddenMessageIds = const {},
  }) async {
    return _repository.page(
      context: context,
      conversationId: conversationId,
      limit: limit,
      cursor: cursor,
      clearedAtUtc: clearedAtUtc,
      hiddenMessageIds: hiddenMessageIds,
    );
  }

  static bool productionStorageMustEnforceAtomicMessageIdUniqueness() => true;

  static bool clientSideDuplicateCheckIsSufficient() => false;

  static bool olderSupportedSchemaMayBeReadAfterUpgrade() => true;

  static bool unsupportedSchemaMayBeSilentlyDecoded() => false;

  static bool clearHistoryMayPhysicallyDeleteStoredMessages() => false;

  static bool moderationMayRewriteHistoricalPayloadSilently() => false;

  static bool roomAndInboxPersistenceRemainLogicallyIsolated() => true;
}
