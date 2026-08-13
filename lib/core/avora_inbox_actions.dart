import 'avora_inbox_audit.dart';
import 'avora_messaging.dart';
import 'avora_messaging_policy.dart';

class AvoraInboxActions {
  const AvoraInboxActions._();

  static AvoraInboxActionResult sendFriendRequest({
    required String auditId,
    required String conversationId,
    required String actorUserId,
    required String targetUserId,
    required AvoraInboxSocialState current,
    required DateTime actionAt,
  }) {
    final next = AvoraMessagingPolicy.sendFriendRequest(
      current.friendshipStatus,
    );

    if (next == current.friendshipStatus) {
      return const AvoraInboxActionResult(
        error: AvoraInboxActionError.invalidTransition,
      );
    }

    return AvoraInboxActionResult(
      socialState: AvoraInboxSocialState(
        friendshipStatus: next,
        conversationState: current.conversationState,
      ),
      auditRecord: AvoraInboxAuditRecord(
        id: auditId,
        conversationId: conversationId,
        actorUserId: actorUserId,
        targetUserId: targetUserId,
        action: AvoraInboxAuditAction.sendFriendRequest,
        createdAt: actionAt,
      ),
    );
  }

  static AvoraInboxActionResult acceptFriendRequest({
    required String auditId,
    required String conversationId,
    required String actorUserId,
    required String targetUserId,
    required AvoraInboxSocialState current,
    required DateTime actionAt,
  }) {
    final next = AvoraMessagingPolicy.acceptFriendRequest(
      current.friendshipStatus,
    );

    if (next == current.friendshipStatus) {
      return const AvoraInboxActionResult(
        error: AvoraInboxActionError.invalidTransition,
      );
    }

    return AvoraInboxActionResult(
      socialState: AvoraInboxSocialState(
        friendshipStatus: next,
        conversationState: current.conversationState,
      ),
      auditRecord: AvoraInboxAuditRecord(
        id: auditId,
        conversationId: conversationId,
        actorUserId: actorUserId,
        targetUserId: targetUserId,
        action: AvoraInboxAuditAction.acceptFriendRequest,
        createdAt: actionAt,
      ),
    );
  }

  static AvoraInboxActionResult removeFriend({
    required String auditId,
    required String conversationId,
    required String actorUserId,
    required String targetUserId,
    required AvoraInboxSocialState current,
    required DateTime actionAt,
  }) {
    final next = AvoraMessagingPolicy.removeFriend(
      current.friendshipStatus,
    );

    if (next == current.friendshipStatus) {
      return const AvoraInboxActionResult(
        error: AvoraInboxActionError.invalidTransition,
      );
    }

    return AvoraInboxActionResult(
      socialState: AvoraInboxSocialState(
        friendshipStatus: next,
        conversationState: current.conversationState,
      ),
      auditRecord: AvoraInboxAuditRecord(
        id: auditId,
        conversationId: conversationId,
        actorUserId: actorUserId,
        targetUserId: targetUserId,
        action: AvoraInboxAuditAction.removeFriend,
        createdAt: actionAt,
      ),
    );
  }

  static AvoraInboxActionResult blockUser({
    required String auditId,
    required String conversationId,
    required String actorUserId,
    required String targetUserId,
    required AvoraInboxSocialState current,
    required DateTime actionAt,
    String? reason,
  }) {
    if (current.friendshipStatus == AvoraFriendshipStatus.blocked &&
        current.conversationState.requestStatus ==
            AvoraInboxRequestStatus.blocked) {
      return const AvoraInboxActionResult(
        error: AvoraInboxActionError.invalidTransition,
      );
    }

    final conversationState = AvoraInboxConversationState(
      requestStatus: AvoraInboxRequestStatus.blocked,
      clearedAt: current.conversationState.clearedAt,
    );

    return AvoraInboxActionResult(
      socialState: AvoraInboxSocialState(
        friendshipStatus: AvoraMessagingPolicy.blockUser(),
        conversationState: conversationState,
      ),
      auditRecord: AvoraInboxAuditRecord(
        id: auditId,
        conversationId: conversationId,
        actorUserId: actorUserId,
        targetUserId: targetUserId,
        action: AvoraInboxAuditAction.blockUser,
        reason: reason?.trim(),
        createdAt: actionAt,
      ),
    );
  }

  static AvoraInboxActionResult unblockUser({
    required String auditId,
    required String conversationId,
    required String actorUserId,
    required String targetUserId,
    required AvoraInboxSocialState current,
    required DateTime actionAt,
  }) {
    final wasBlocked =
        current.friendshipStatus == AvoraFriendshipStatus.blocked ||
            current.conversationState.requestStatus ==
                AvoraInboxRequestStatus.blocked;

    if (!wasBlocked) {
      return const AvoraInboxActionResult(
        error: AvoraInboxActionError.invalidTransition,
      );
    }

    final friendship = AvoraMessagingPolicy.unblockUser(
      current.friendshipStatus,
    );

    final conversationState = AvoraInboxConversationState(
      requestStatus: AvoraInboxRequestStatus.none,
      clearedAt: current.conversationState.clearedAt,
    );

    return AvoraInboxActionResult(
      socialState: AvoraInboxSocialState(
        friendshipStatus: friendship,
        conversationState: conversationState,
      ),
      auditRecord: AvoraInboxAuditRecord(
        id: auditId,
        conversationId: conversationId,
        actorUserId: actorUserId,
        targetUserId: targetUserId,
        action: AvoraInboxAuditAction.unblockUser,
        createdAt: actionAt,
      ),
    );
  }

  static AvoraInboxActionResult acceptMessageRequest({
    required String auditId,
    required String conversationId,
    required String actorUserId,
    required String targetUserId,
    required AvoraInboxSocialState current,
    required DateTime actionAt,
  }) {
    if (current.conversationState.requestStatus !=
        AvoraInboxRequestStatus.pending) {
      return const AvoraInboxActionResult(
        error: AvoraInboxActionError.invalidTransition,
      );
    }

    final nextConversation = AvoraInboxConversationState(
      requestStatus: AvoraInboxRequestStatus.accepted,
      clearedAt: current.conversationState.clearedAt,
    );

    return AvoraInboxActionResult(
      socialState: AvoraInboxSocialState(
        friendshipStatus: current.friendshipStatus,
        conversationState: nextConversation,
      ),
      auditRecord: AvoraInboxAuditRecord(
        id: auditId,
        conversationId: conversationId,
        actorUserId: actorUserId,
        targetUserId: targetUserId,
        action: AvoraInboxAuditAction.acceptMessageRequest,
        createdAt: actionAt,
      ),
    );
  }

  static AvoraInboxActionResult ignoreMessageRequest({
    required String auditId,
    required String conversationId,
    required String actorUserId,
    required String targetUserId,
    required AvoraInboxSocialState current,
    required DateTime actionAt,
  }) {
    if (current.conversationState.requestStatus !=
        AvoraInboxRequestStatus.pending) {
      return const AvoraInboxActionResult(
        error: AvoraInboxActionError.invalidTransition,
      );
    }

    final nextConversation = AvoraInboxConversationState(
      requestStatus: AvoraInboxRequestStatus.ignored,
      clearedAt: current.conversationState.clearedAt,
    );

    return AvoraInboxActionResult(
      socialState: AvoraInboxSocialState(
        friendshipStatus: current.friendshipStatus,
        conversationState: nextConversation,
      ),
      auditRecord: AvoraInboxAuditRecord(
        id: auditId,
        conversationId: conversationId,
        actorUserId: actorUserId,
        targetUserId: targetUserId,
        action: AvoraInboxAuditAction.ignoreMessageRequest,
        createdAt: actionAt,
      ),
    );
  }

  static AvoraInboxActionResult clearInbox({
    required String auditId,
    required String conversationId,
    required String actorUserId,
    required String targetUserId,
    required AvoraInboxSocialState current,
    required DateTime actionAt,
  }) {
    final nextConversation = AvoraMessagingPolicy.clearInboxForUser(
      current: current.conversationState,
      clearedAt: actionAt,
    );

    return AvoraInboxActionResult(
      socialState: AvoraInboxSocialState(
        friendshipStatus: current.friendshipStatus,
        conversationState: nextConversation,
      ),
      auditRecord: AvoraInboxAuditRecord(
        id: auditId,
        conversationId: conversationId,
        actorUserId: actorUserId,
        targetUserId: targetUserId,
        action: AvoraInboxAuditAction.clearInbox,
        createdAt: actionAt,
      ),
    );
  }
}
