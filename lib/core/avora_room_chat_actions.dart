import 'avora_enforcement.dart';
import 'avora_messaging.dart';
import 'avora_messaging_policy.dart';
import 'avora_roles.dart';
import 'avora_room_chat_audit.dart';

enum AvoraRoomChatActionError {
  notAuthorized,
  invalidTarget,
}

class AvoraRoomChatActionResult {
  final AvoraRoomChatAuditRecord? auditRecord;
  final AvoraRoomChatClearEvent? clearEvent;
  final AvoraRoomChatPolicy? updatedPolicy;
  final AvoraEnforcementRecord? enforcementRecord;
  final AvoraRoomChatActionError? error;

  const AvoraRoomChatActionResult({
    this.auditRecord,
    this.clearEvent,
    this.updatedPolicy,
    this.enforcementRecord,
    this.error,
  });

  bool get success => error == null;
}

class AvoraRoomChatActions {
  const AvoraRoomChatActions._();

  static AvoraRoomChatActionResult clearChat({
    required String auditId,
    required String roomId,
    required String actorUserId,
    required AvoraRoomChatAuthority authority,
    required AvoraRoomChatPolicy policy,
    required DateTime actionAt,
    String? reason,
  }) {
    if (!AvoraMessagingPolicy.canClearRoomChat(
      policy: policy,
      authority: authority,
    )) {
      return const AvoraRoomChatActionResult(
        error: AvoraRoomChatActionError.notAuthorized,
      );
    }

    final clearEvent = AvoraRoomChatClearEvent(
      roomId: roomId,
      clearedByUserId: actorUserId,
      clearedAt: actionAt,
      reason: reason?.trim(),
    );

    final audit = AvoraRoomChatAuditRecord(
      id: auditId,
      roomId: roomId,
      actorUserId: actorUserId,
      action: AvoraRoomChatAuditAction.clearChat,
      reason: reason?.trim(),
      createdAt: actionAt,
    );

    return AvoraRoomChatActionResult(
      auditRecord: audit,
      clearEvent: clearEvent,
    );
  }

  static AvoraRoomChatActionResult removeMessage({
    required String auditId,
    required String roomId,
    required String actorUserId,
    required AvoraRoomChatAuthority authority,
    required String targetMessageId,
    required DateTime actionAt,
    String? targetUserId,
    String? reason,
  }) {
    if (!_isStaff(authority)) {
      return const AvoraRoomChatActionResult(
        error: AvoraRoomChatActionError.notAuthorized,
      );
    }

    final audit = AvoraRoomChatAuditRecord(
      id: auditId,
      roomId: roomId,
      actorUserId: actorUserId,
      action: AvoraRoomChatAuditAction.removeMessage,
      targetUserId: targetUserId,
      targetMessageId: targetMessageId,
      reason: reason?.trim(),
      createdAt: actionAt,
    );

    return AvoraRoomChatActionResult(
      auditRecord: audit,
    );
  }

  static AvoraRoomChatActionResult changeMediaPolicy({
    required String auditId,
    required String roomId,
    required String actorUserId,
    required AvoraRoomChatAuthority authority,
    required AvoraRoomChatPolicy currentPolicy,
    required AvoraRoomMediaPolicy newMediaPolicy,
    required DateTime actionAt,
  }) {
    if (!_isAdminOrOwner(authority)) {
      return const AvoraRoomChatActionResult(
        error: AvoraRoomChatActionError.notAuthorized,
      );
    }

    final updated = AvoraRoomChatPolicy(
      mediaPolicy: newMediaPolicy,
      allowStaffClearChat: currentPolicy.allowStaffClearChat,
    );

    final audit = AvoraRoomChatAuditRecord(
      id: auditId,
      roomId: roomId,
      actorUserId: actorUserId,
      action: AvoraRoomChatAuditAction.changeMediaPolicy,
      metadata: {
        'oldMediaPolicy': currentPolicy.mediaPolicy.name,
        'newMediaPolicy': newMediaPolicy.name,
      },
      createdAt: actionAt,
    );

    return AvoraRoomChatActionResult(
      auditRecord: audit,
      updatedPolicy: updated,
    );
  }

  static AvoraRoomChatActionResult blockUserFromRoom({
    required String auditId,
    required String enforcementId,
    required String roomId,
    required String actorUserId,
    required String targetUserId,
    required AvoraRoomChatAuthority authority,
    required AvoraEnforcementDuration duration,
    required DateTime actionAt,
    required String reason,
  }) {
    if (!_isStaff(authority)) {
      return const AvoraRoomChatActionResult(
        error: AvoraRoomChatActionError.notAuthorized,
      );
    }

    final enforcement = AvoraEnforcementRecord.create(
      id: enforcementId,
      targetUserId: targetUserId,
      issuedByUserId: actorUserId,
      type: AvoraEnforcementType.roomBan,
      duration: duration,
      scope: AvoraScope.room(roomId),
      reason: reason,
      createdAt: actionAt,
    );

    final audit = AvoraRoomChatAuditRecord(
      id: auditId,
      roomId: roomId,
      actorUserId: actorUserId,
      action: AvoraRoomChatAuditAction.blockUserFromRoom,
      targetUserId: targetUserId,
      reason: reason.trim(),
      metadata: {
        'duration': duration.name,
        'enforcementId': enforcementId,
      },
      createdAt: actionAt,
    );

    return AvoraRoomChatActionResult(
      auditRecord: audit,
      enforcementRecord: enforcement,
    );
  }

  static AvoraRoomChatActionResult unblockUserFromRoom({
    required String auditId,
    required String roomId,
    required String actorUserId,
    required AvoraRoomChatAuthority authority,
    required AvoraEnforcementRecord existingBlock,
    required DateTime actionAt,
    String? reason,
  }) {
    if (!_isStaff(authority)) {
      return const AvoraRoomChatActionResult(
        error: AvoraRoomChatActionError.notAuthorized,
      );
    }

    final validBlock = existingBlock.type == AvoraEnforcementType.roomBan &&
        existingBlock.scope.type == AvoraScopeType.room &&
        existingBlock.scope.id == roomId &&
        existingBlock.isActiveAt(actionAt);

    if (!validBlock) {
      return const AvoraRoomChatActionResult(
        error: AvoraRoomChatActionError.invalidTarget,
      );
    }

    final revoked = existingBlock.revoke(
      revokedByUserId: actorUserId,
      revokedAt: actionAt,
      reason: reason ?? 'Room unblock',
    );

    final audit = AvoraRoomChatAuditRecord(
      id: auditId,
      roomId: roomId,
      actorUserId: actorUserId,
      action: AvoraRoomChatAuditAction.unblockUserFromRoom,
      targetUserId: existingBlock.targetUserId,
      reason: reason?.trim(),
      metadata: {
        'enforcementId': existingBlock.id,
      },
      createdAt: actionAt,
    );

    return AvoraRoomChatActionResult(
      auditRecord: audit,
      enforcementRecord: revoked,
    );
  }

  static bool _isStaff(
    AvoraRoomChatAuthority authority,
  ) {
    return authority != AvoraRoomChatAuthority.member;
  }

  static bool _isAdminOrOwner(
    AvoraRoomChatAuthority authority,
  ) {
    return authority == AvoraRoomChatAuthority.admin ||
        authority == AvoraRoomChatAuthority.owner;
  }
}
