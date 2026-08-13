import 'avora_message_persistence.dart';
import 'avora_message_persistence_adapter.dart';

class AvoraMessagePersistenceService<T> {
  AvoraMessagePersistenceService({
    required AvoraMessagePersistenceStorageAdapter<T> adapter,
    required AvoraMessageStorageCodec<T> codec,
  })  : _adapter = adapter,
        _codec = codec;

  final AvoraMessagePersistenceStorageAdapter<T> _adapter;
  final AvoraMessageStorageCodec<T> _codec;

  Future<AvoraMessageStorageWriteResult<T>> persist(
    AvoraMessagePersistenceRecord<T> record,
  ) {
    final envelope = encodeAvoraMessageStorageEnvelope<T>(
      record: record,
      codec: _codec,
    );

    return _adapter.insertAtomic(envelope);
  }

  Future<AvoraMessagePersistenceRecord<T>?> findByMessageId(
    String messageId,
  ) {
    return _adapter.findByMessageId(messageId);
  }

  Future<AvoraMessagePage<T>> page({
    required AvoraMessagePersistenceContext context,
    required String conversationId,
    required int limit,
    AvoraMessageCursor? cursor,
    DateTime? clearedAtUtc,
    Set<String> hiddenMessageIds = const {},
  }) {
    return _adapter.page(
      context: context,
      conversationId: conversationId,
      limit: limit,
      cursor: cursor,
      clearedAtUtc: clearedAtUtc,
      hiddenMessageIds: hiddenMessageIds,
    );
  }
}
