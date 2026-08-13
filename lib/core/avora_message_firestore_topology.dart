/// Canonical Firestore topology for AVORA messaging.
///
/// Room and inbox messages intentionally use separate root collections.
/// This keeps authorization, querying, retention and moderation boundaries
/// independently enforceable.
abstract final class AvoraMessageFirestoreTopology {
  static const String roomMessages = 'roomMessages';
  static const String inboxMessages = 'inboxMessages';

  /// Production message documents use the immutable AVORA message ID
  /// as their Firestore document ID.
  static bool messageDocumentIdMustRemainImmutable() => true;

  /// Room and inbox data must never share the same root collection.
  static bool roomAndInboxMustRemainPhysicallySeparated() =>
      roomMessages != inboxMessages;

  /// Moderation hides content from normal visibility; it must not silently
  /// destroy the stored evidence/history.
  static bool moderationMustNotPhysicallyDeleteEvidence() => true;

  /// User clear-history is a visibility boundary, not destructive deletion.
  static bool clearHistoryMustRemainNonDestructive() => true;
}
