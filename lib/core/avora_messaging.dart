enum AvoraConversationType {
  room,
  inbox,
}

enum AvoraMessageType {
  text,
  image,
  video,
  system,
}

enum AvoraMessageModerationStatus {
  pending,
  allowed,
  blurred,
  blocked,
  removed,
}

enum AvoraRoomMediaPolicy {
  staffOnly,
  everyone,
}

enum AvoraInboxRequestStatus {
  none,
  pending,
  accepted,
  ignored,
  blocked,
}

enum AvoraFriendshipStatus {
  none,
  requestSent,
  requestReceived,
  friends,
  removed,
  blocked,
}

class AvoraMessageRecord {
  final String id;
  final AvoraConversationType conversationType;
  final String conversationId;
  final String senderUserId;

  final AvoraMessageType type;

  final String? text;
  final String? mediaRef;

  final DateTime sentAt;

  final AvoraMessageModerationStatus moderationStatus;

  final DateTime? deletedAt;
  final bool deletedForEveryone;

  const AvoraMessageRecord({
    required this.id,
    required this.conversationType,
    required this.conversationId,
    required this.senderUserId,
    required this.type,
    required this.sentAt,
    this.text,
    this.mediaRef,
    this.moderationStatus = AvoraMessageModerationStatus.pending,
    this.deletedAt,
    this.deletedForEveryone = false,
  });

  bool get isMedia =>
      type == AvoraMessageType.image || type == AvoraMessageType.video;

  bool get isDeleted => deletedAt != null;
}

class AvoraRoomChatPolicy {
  final AvoraRoomMediaPolicy mediaPolicy;

  /// Authorized room staff can clear room messages.
  final bool allowStaffClearChat;

  const AvoraRoomChatPolicy({
    this.mediaPolicy = AvoraRoomMediaPolicy.staffOnly,
    this.allowStaffClearChat = true,
  });
}

class AvoraInboxConversationState {
  final AvoraInboxRequestStatus requestStatus;

  /// User-specific clear-chat timestamp.
  /// Messages before this may be hidden for that user.
  final DateTime? clearedAt;

  const AvoraInboxConversationState({
    this.requestStatus = AvoraInboxRequestStatus.none,
    this.clearedAt,
  });
}
