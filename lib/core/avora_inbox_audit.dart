import 'avora_messaging.dart';

enum AvoraInboxAuditAction {
  sendFriendRequest,
  acceptFriendRequest,
  removeFriend,
  blockUser,
  unblockUser,
  acceptMessageRequest,
  ignoreMessageRequest,
  clearInbox,
  deleteMessageForSelf,
  deleteMessageForEveryone,
}

class AvoraInboxAuditRecord {
  final String id;
  final String conversationId;

  final String actorUserId;
  final String? targetUserId;
  final String? targetMessageId;

  final AvoraInboxAuditAction action;

  final String? reason;
  final Map<String, String> metadata;

  final DateTime createdAt;

  const AvoraInboxAuditRecord({
    required this.id,
    required this.conversationId,
    required this.actorUserId,
    required this.action,
    required this.createdAt,
    this.targetUserId,
    this.targetMessageId,
    this.reason,
    this.metadata = const {},
  });
}

class AvoraInboxSocialState {
  final AvoraFriendshipStatus friendshipStatus;
  final AvoraInboxConversationState conversationState;

  const AvoraInboxSocialState({
    required this.friendshipStatus,
    required this.conversationState,
  });
}

enum AvoraInboxActionError {
  invalidTransition,
  notAuthorized,
  invalidMessage,
}

class AvoraInboxActionResult {
  final AvoraInboxSocialState? socialState;
  final AvoraInboxAuditRecord? auditRecord;
  final AvoraMessageRecord? updatedMessage;
  final AvoraInboxActionError? error;

  const AvoraInboxActionResult({
    this.socialState,
    this.auditRecord,
    this.updatedMessage,
    this.error,
  });

  bool get success => error == null;
}
