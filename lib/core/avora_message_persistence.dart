import 'avora_messaging.dart';

enum AvoraMessagePersistenceContext {
  room,
  inbox,
}

enum AvoraMessageInsertStatus {
  inserted,
  duplicateMessageId,
  invalidRecord,
}

class AvoraMessagePersistenceRecord<T> {
  const AvoraMessagePersistenceRecord({
    required this.messageId,
    required this.context,
    required this.conversationId,
    required this.sentAtUtc,
    required this.persistedAtUtc,
    required this.payload,
  });

  /// Immutable globally unique message identity.
  final String messageId;

  /// Storage namespace only.
  /// Existing AVORA messaging policy remains authoritative.
  final AvoraMessagePersistenceContext context;

  final String conversationId;

  /// Original message timestamp. Never silently rewritten by pagination.
  final DateTime sentAtUtc;

  final DateTime persistedAtUtc;

  final T payload;

  bool get valid =>
      messageId.trim().isNotEmpty &&
      conversationId.trim().isNotEmpty &&
      !persistedAtUtc.toUtc().isBefore(sentAtUtc.toUtc());
}

/// Typed bridge to the existing AVORA message model.
///
/// This deliberately uses the existing record's conversationId and sentAt
/// instead of creating a parallel message model.
AvoraMessagePersistenceRecord<AvoraMessageRecord>
    avoraPersistenceRecordFromMessage({
  required String messageId,
  required AvoraMessagePersistenceContext context,
  required AvoraMessageRecord message,
  required DateTime persistedAtUtc,
}) {
  return AvoraMessagePersistenceRecord<AvoraMessageRecord>(
    messageId: messageId.trim(),
    context: context,
    conversationId: message.conversationId.trim(),
    sentAtUtc: message.sentAt.toUtc(),
    persistedAtUtc: persistedAtUtc.toUtc(),
    payload: message,
  );
}

class AvoraMessageCursor {
  const AvoraMessageCursor({
    required this.sentAtUtc,
    required this.messageId,
  });

  final DateTime sentAtUtc;
  final String messageId;
}

class AvoraMessagePage<T> {
  const AvoraMessagePage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<AvoraMessagePersistenceRecord<T>> items;
  final AvoraMessageCursor? nextCursor;
  final bool hasMore;
}

class AvoraMessageInsertResult<T> {
  const AvoraMessageInsertResult({
    required this.status,
    required this.repository,
    required this.record,
  });

  final AvoraMessageInsertStatus status;
  final AvoraInMemoryMessagePersistenceRepository<T> repository;
  final AvoraMessagePersistenceRecord<T>? record;

  bool get inserted => status == AvoraMessageInsertStatus.inserted;
}

/// Reference repository implementation.
///
/// Production DB adapters should reproduce these semantics:
/// - immutable message IDs
/// - append-only insertion
/// - deterministic cursor pagination
/// - clear-history filtering at read time
/// - moderation/removal visibility filtering without hard deleting history
class AvoraInMemoryMessagePersistenceRepository<T> {
  AvoraInMemoryMessagePersistenceRepository({
    List<AvoraMessagePersistenceRecord<T>> seed = const [],
  }) : _records = List.unmodifiable(seed);

  final List<AvoraMessagePersistenceRecord<T>> _records;

  List<AvoraMessagePersistenceRecord<T>> get records =>
      List.unmodifiable(_records);

  AvoraMessageInsertResult<T> insert(
    AvoraMessagePersistenceRecord<T> record,
  ) {
    if (!record.valid) {
      return AvoraMessageInsertResult<T>(
        status: AvoraMessageInsertStatus.invalidRecord,
        repository: this,
        record: null,
      );
    }

    final duplicate = _records.any(
      (existing) => existing.messageId.trim() == record.messageId.trim(),
    );

    if (duplicate) {
      return AvoraMessageInsertResult<T>(
        status: AvoraMessageInsertStatus.duplicateMessageId,
        repository: this,
        record: null,
      );
    }

    final nextRecords = [
      ..._records,
      record,
    ];

    return AvoraMessageInsertResult<T>(
      status: AvoraMessageInsertStatus.inserted,
      repository: AvoraInMemoryMessagePersistenceRepository<T>(
        seed: nextRecords,
      ),
      record: record,
    );
  }

  AvoraMessagePersistenceRecord<T>? findByMessageId(
    String messageId,
  ) {
    final normalized = messageId.trim();

    for (final record in _records) {
      if (record.messageId.trim() == normalized) {
        return record;
      }
    }

    return null;
  }

  AvoraMessagePage<T> page({
    required AvoraMessagePersistenceContext context,
    required String conversationId,
    required int limit,
    AvoraMessageCursor? cursor,

    /// User/room-specific clear-history boundary supplied by the
    /// authoritative existing messaging/action layer.
    DateTime? clearedAtUtc,

    /// Moderation/removal layer may hide IDs without deleting persistence.
    Set<String> hiddenMessageIds = const {},
  }) {
    final normalizedConversationId = conversationId.trim();

    final normalizedHiddenIds = hiddenMessageIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    final clearBoundary = clearedAtUtc?.toUtc();

    final filtered = _records.where((record) {
      if (record.context != context) {
        return false;
      }

      if (record.conversationId.trim() != normalizedConversationId) {
        return false;
      }

      if (normalizedHiddenIds.contains(record.messageId.trim())) {
        return false;
      }

      /// Existing AVORA behavior: clear event hides only messages OLDER
      /// than the boundary. A message exactly at clearedAt is not rewritten
      /// as older.
      if (clearBoundary != null &&
          record.sentAtUtc.toUtc().isBefore(clearBoundary)) {
        return false;
      }

      if (cursor != null &&
          !_isStrictlyAfterCursorInDescendingOrder(
            record: record,
            cursor: cursor,
          )) {
        return false;
      }

      return true;
    }).toList(growable: false);

    final sorted = [...filtered]..sort((left, right) {
        final timeCompare =
            right.sentAtUtc.toUtc().compareTo(left.sentAtUtc.toUtc());

        if (timeCompare != 0) {
          return timeCompare;
        }

        return right.messageId.compareTo(left.messageId);
      });

    final normalizedLimit = limit.clamp(1, 100).toInt();

    final hasMore = sorted.length > normalizedLimit;

    final selected = sorted.take(normalizedLimit).toList(growable: false);

    AvoraMessageCursor? nextCursor;

    if (hasMore && selected.isNotEmpty) {
      final last = selected.last;

      nextCursor = AvoraMessageCursor(
        sentAtUtc: last.sentAtUtc.toUtc(),
        messageId: last.messageId,
      );
    }

    return AvoraMessagePage<T>(
      items: List.unmodifiable(selected),
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }

  static bool _isStrictlyAfterCursorInDescendingOrder<T>({
    required AvoraMessagePersistenceRecord<T> record,
    required AvoraMessageCursor cursor,
  }) {
    final recordTime = record.sentAtUtc.toUtc();
    final cursorTime = cursor.sentAtUtc.toUtc();

    if (recordTime.isBefore(cursorTime)) {
      return true;
    }

    if (recordTime.isAfter(cursorTime)) {
      return false;
    }

    /// For equal timestamps, descending messageId is the stable tie-breaker.
    return record.messageId.compareTo(cursor.messageId) < 0;
  }

  static bool hardDeleteSupported() => false;

  static bool clearHistoryRewritesStoredMessages() => false;

  static bool moderationRemovalRequiresPhysicalDelete() => false;

  static bool existingMessagingPolicyRemainsAuthoritative() => true;

  static bool existingClearHistoryModelRemainsAuthoritative() => true;

  static bool messageIdMayBeSilentlyReused() => false;

  static bool cursorPaginationUsesStableTieBreaker() => true;
}
