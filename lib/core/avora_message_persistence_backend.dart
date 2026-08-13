import 'avora_message_persistence.dart';
import 'avora_message_persistence_adapter.dart';

/// Production-facing persistence boundary.
///
/// Firestore, Postgres, Supabase, or another durable backend can implement
/// this contract without changing message-domain/service code.
abstract class AvoraMessagePersistenceBackend<T> {
  Future<AvoraMessageStorageWriteResult<T>> insertAtomic(
    AvoraMessageStorageEnvelope envelope,
    AvoraMessageStorageCodec<T> codec,
  );

  Future<AvoraMessagePersistenceRecord<T>?> findByMessageId(
    String messageId,
    AvoraMessageStorageCodec<T> codec,
  );

  Future<AvoraMessagePage<T>> page({
    required AvoraMessagePersistenceContext context,
    required String conversationId,
    required int limit,
    required AvoraMessageStorageCodec<T> codec,
    AvoraMessageCursor? cursor,
    DateTime? clearedAtUtc,
    Set<String> hiddenMessageIds = const {},
  });
}

/// Adapter that keeps the existing service boundary stable while delegating
/// durable work to a production backend.
class AvoraProductionMessageStorageAdapter<T>
    implements AvoraMessagePersistenceStorageAdapter<T> {
  AvoraProductionMessageStorageAdapter({
    required AvoraMessagePersistenceBackend<T> backend,
    required AvoraMessageStorageCodec<T> codec,
  })  : _backend = backend,
        _codec = codec;

  final AvoraMessagePersistenceBackend<T> _backend;
  final AvoraMessageStorageCodec<T> _codec;

  @override
  Future<AvoraMessageStorageWriteResult<T>> insertAtomic(
    AvoraMessageStorageEnvelope envelope,
  ) {
    return _backend.insertAtomic(envelope, _codec);
  }

  @override
  Future<AvoraMessagePersistenceRecord<T>?> findByMessageId(
    String messageId,
  ) {
    return _backend.findByMessageId(messageId, _codec);
  }

  @override
  Future<AvoraMessagePage<T>> page({
    required AvoraMessagePersistenceContext context,
    required String conversationId,
    required int limit,
    AvoraMessageCursor? cursor,
    DateTime? clearedAtUtc,
    Set<String> hiddenMessageIds = const {},
  }) {
    return _backend.page(
      context: context,
      conversationId: conversationId,
      limit: limit,
      codec: _codec,
      cursor: cursor,
      clearedAtUtc: clearedAtUtc,
      hiddenMessageIds: hiddenMessageIds,
    );
  }

  /// Production storage must enforce immutable message-ID uniqueness
  /// atomically at the durable storage layer.
  static bool productionMustEnforceAtomicMessageIdUniqueness() => true;

  /// Room and inbox records must remain logically isolated.
  static bool roomAndInboxMustRemainIsolated() => true;

  /// Clear-history is a visibility cutoff, not physical deletion.
  static bool clearHistoryMustRemainVisibilityFiltering() => true;

  /// Moderation-hidden messages remain stored for audit/evidence.
  static bool moderationHiddenMessagesMustRemainStored() => true;

  /// Historical payloads must not be silently rewritten by moderation.
  static bool historicalPayloadMustRemainImmutable() => true;
}
