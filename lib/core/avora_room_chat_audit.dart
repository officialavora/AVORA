enum AvoraRoomChatAuditAction {
  clearChat,
  removeMessage,
  changeMediaPolicy,
  blockUserFromRoom,
  unblockUserFromRoom,
}

class AvoraRoomChatAuditRecord {
  final String id;
  final String roomId;

  final String actorUserId;

  final AvoraRoomChatAuditAction action;

  final String? targetUserId;
  final String? targetMessageId;

  final String? reason;

  /// Optional compact metadata, for example:
  /// oldMediaPolicy / newMediaPolicy.
  final Map<String, String> metadata;

  final DateTime createdAt;

  const AvoraRoomChatAuditRecord({
    required this.id,
    required this.roomId,
    required this.actorUserId,
    required this.action,
    required this.createdAt,
    this.targetUserId,
    this.targetMessageId,
    this.reason,
    this.metadata = const {},
  });
}

class AvoraRoomChatClearEvent {
  final String roomId;
  final String clearedByUserId;
  final DateTime clearedAt;
  final String? reason;

  const AvoraRoomChatClearEvent({
    required this.roomId,
    required this.clearedByUserId,
    required this.clearedAt,
    this.reason,
  });

  bool hidesMessage({
    required String messageRoomId,
    required DateTime messageSentAt,
  }) {
    return messageRoomId == roomId && !messageSentAt.isAfter(clearedAt);
  }
}
