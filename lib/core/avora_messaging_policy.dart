import 'avora_messaging.dart';

enum AvoraRoomChatAuthority {
  member,
  moderator,
  admin,
  owner,
}

class AvoraMessagingPolicy {
  const AvoraMessagingPolicy._();

  /// Room media is staff-only by default.
  /// Room policy may explicitly allow everyone later.
  static bool canPostRoomMedia({
    required AvoraRoomChatPolicy policy,
    required AvoraRoomChatAuthority authority,
  }) {
    if (policy.mediaPolicy == AvoraRoomMediaPolicy.everyone) {
      return true;
    }

    return authority != AvoraRoomChatAuthority.member;
  }

  /// Owner/Admin/authorized room staff can clear room chat.
  static bool canClearRoomChat({
    required AvoraRoomChatPolicy policy,
    required AvoraRoomChatAuthority authority,
  }) {
    if (!policy.allowStaffClearChat) {
      return false;
    }

    return authority != AvoraRoomChatAuthority.member;
  }

  /// Inbox supports text/photo/video.
  /// Anyone may send unless the recipient has blocked them.
  static bool canSendInboxMessage({
    required AvoraInboxRequestStatus requestStatus,
  }) {
    return requestStatus != AvoraInboxRequestStatus.blocked;
  }

  /// Non-friends are routed through Message Requests.
  static bool requiresMessageRequest({
    required AvoraFriendshipStatus friendshipStatus,
    required AvoraInboxRequestStatus requestStatus,
  }) {
    if (friendshipStatus == AvoraFriendshipStatus.friends) {
      return false;
    }

    if (friendshipStatus == AvoraFriendshipStatus.blocked ||
        requestStatus == AvoraInboxRequestStatus.blocked) {
      return false;
    }

    if (requestStatus == AvoraInboxRequestStatus.accepted) {
      return false;
    }

    return true;
  }

  static AvoraFriendshipStatus sendFriendRequest(
    AvoraFriendshipStatus current,
  ) {
    switch (current) {
      case AvoraFriendshipStatus.none:
      case AvoraFriendshipStatus.removed:
        return AvoraFriendshipStatus.requestSent;

      case AvoraFriendshipStatus.requestReceived:
      case AvoraFriendshipStatus.requestSent:
      case AvoraFriendshipStatus.friends:
      case AvoraFriendshipStatus.blocked:
        return current;
    }
  }

  static AvoraFriendshipStatus acceptFriendRequest(
    AvoraFriendshipStatus current,
  ) {
    if (current == AvoraFriendshipStatus.requestReceived) {
      return AvoraFriendshipStatus.friends;
    }

    return current;
  }

  static AvoraFriendshipStatus removeFriend(
    AvoraFriendshipStatus current,
  ) {
    if (current == AvoraFriendshipStatus.friends) {
      return AvoraFriendshipStatus.removed;
    }

    return current;
  }

  static AvoraFriendshipStatus blockUser() {
    return AvoraFriendshipStatus.blocked;
  }

  static AvoraFriendshipStatus unblockUser(
    AvoraFriendshipStatus current,
  ) {
    if (current == AvoraFriendshipStatus.blocked) {
      return AvoraFriendshipStatus.none;
    }

    return current;
  }

  /// Clear inbox history for the current user only.
  /// The other user's copy is not automatically deleted.
  static AvoraInboxConversationState clearInboxForUser({
    required AvoraInboxConversationState current,
    required DateTime clearedAt,
  }) {
    return AvoraInboxConversationState(
      requestStatus: current.requestStatus,
      clearedAt: clearedAt,
    );
  }
}
