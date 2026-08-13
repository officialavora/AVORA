enum AvoraMentionSource {
  profile,
  roomParticipant,
  message,
  search,
}

enum AvoraReferencedMessageState {
  available,
  deletedForEveryone,
  removedByModeration,
  unavailable,
}

class AvoraMessageMention {
  /// Immutable authoritative AVORA user ID.
  final String targetAvoraId;

  final AvoraMentionSource source;

  /// Optional visible-name snapshot for rendering only.
  /// Never used as identity authority.
  final String? displayNameSnapshot;

  const AvoraMessageMention({
    required this.targetAvoraId,
    required this.source,
    this.displayNameSnapshot,
  }) : assert(targetAvoraId != '');
}

class AvoraMessageReplyReference {
  /// Stable server message ID.
  final String referencedMessageId;

  /// Immutable original sender AVORA ID.
  final String originalSenderAvoraId;

  final AvoraReferencedMessageState state;

  /// Small preview snapshot only.
  /// Full original message remains server-authoritative.
  final String? previewText;

  const AvoraMessageReplyReference({
    required this.referencedMessageId,
    required this.originalSenderAvoraId,
    required this.state,
    this.previewText,
  })  : assert(referencedMessageId != ''),
        assert(originalSenderAvoraId != '');

  bool get canShowPreview => state == AvoraReferencedMessageState.available;

  String get fallbackLabel {
    switch (state) {
      case AvoraReferencedMessageState.available:
        return previewText ?? '';

      case AvoraReferencedMessageState.deletedForEveryone:
        return 'message_deleted';

      case AvoraReferencedMessageState.removedByModeration:
        return 'message_removed';

      case AvoraReferencedMessageState.unavailable:
        return 'message_unavailable';
    }
  }
}

class AvoraMessageInteraction {
  final String messageId;

  final List<AvoraMessageMention> mentions;

  final AvoraMessageReplyReference? replyTo;

  const AvoraMessageInteraction({
    required this.messageId,
    this.mentions = const [],
    this.replyTo,
  }) : assert(messageId != '');

  bool mentionsUser(String avoraId) {
    final normalized = avoraId.trim();

    return mentions.any(
      (mention) => mention.targetAvoraId.trim() == normalized,
    );
  }
}

enum AvoraMentionDecisionReason {
  allowed,
  senderChatRestricted,
  blocked,
  roomChatRestricted,
}

class AvoraMentionDecision {
  final bool mentionAllowed;

  /// Mention may render but notification can be suppressed
  /// by recipient preferences/mute state.
  final bool notifyTarget;

  final AvoraMentionDecisionReason reason;

  const AvoraMentionDecision({
    required this.mentionAllowed,
    required this.notifyTarget,
    required this.reason,
  });
}

class AvoraMessageInteractionPolicy {
  const AvoraMessageInteractionPolicy._();

  static AvoraMentionDecision evaluateMention({
    required bool senderChatAllowed,
    required bool blockedEitherDirection,
    required bool roomChatAllowed,
    required bool targetMentionNotificationsEnabled,
    required bool targetMutedConversation,
  }) {
    if (!senderChatAllowed) {
      return const AvoraMentionDecision(
        mentionAllowed: false,
        notifyTarget: false,
        reason: AvoraMentionDecisionReason.senderChatRestricted,
      );
    }

    if (blockedEitherDirection) {
      return const AvoraMentionDecision(
        mentionAllowed: false,
        notifyTarget: false,
        reason: AvoraMentionDecisionReason.blocked,
      );
    }

    if (!roomChatAllowed) {
      return const AvoraMentionDecision(
        mentionAllowed: false,
        notifyTarget: false,
        reason: AvoraMentionDecisionReason.roomChatRestricted,
      );
    }

    return AvoraMentionDecision(
      mentionAllowed: true,
      notifyTarget:
          targetMentionNotificationsEnabled && !targetMutedConversation,
      reason: AvoraMentionDecisionReason.allowed,
    );
  }

  static AvoraMessageReplyReference buildReply({
    required String referencedMessageId,
    required String originalSenderAvoraId,
    required AvoraReferencedMessageState state,
    String? previewText,
  }) {
    return AvoraMessageReplyReference(
      referencedMessageId: referencedMessageId,
      originalSenderAvoraId: originalSenderAvoraId,
      state: state,
      previewText:
          state == AvoraReferencedMessageState.available ? previewText : null,
    );
  }
}
