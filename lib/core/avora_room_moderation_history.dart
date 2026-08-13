import 'avora_room_inspection.dart';

enum AvoraRoomModerationHistoryStatus {
  active,
  expired,
  revoked,
}

class AvoraRoomModerationHistoryRecord {
  const AvoraRoomModerationHistoryRecord({
    required this.historyId,
    required this.actionId,
    required this.roomId,
    required this.actorAvoraId,
    required this.actorDisplayNameSnapshot,
    required this.targetAvoraId,
    required this.targetDisplayNameSnapshot,
    required this.action,
    required this.reasonCode,
    required this.reasonText,
    required this.occurredAt,
    this.expiresAt,
    this.status = AvoraRoomModerationHistoryStatus.active,
    this.revokedAt,
    this.revokedByAvoraId,
    this.revokedByDisplayNameSnapshot,
    this.revokeReason,
  });

  /// Stable audit/history event ID.
  final String historyId;

  /// Source moderation action/request ID for audit linkage.
  final String actionId;

  final String roomId;

  /// Immutable authoritative AVORA ID of staff/admin/owner actor.
  final String actorAvoraId;

  /// Historical display metadata only.
  /// Name changes later must not rewrite old audit history.
  final String actorDisplayNameSnapshot;

  /// Immutable authoritative AVORA ID of affected user.
  final String targetAvoraId;

  /// Historical display metadata only.
  final String targetDisplayNameSnapshot;

  final AvoraRoomModerationAction action;

  final String reasonCode;
  final String? reasonText;

  final DateTime occurredAt;
  final DateTime? expiresAt;

  final AvoraRoomModerationHistoryStatus status;

  final DateTime? revokedAt;

  /// Immutable ID of person who reversed/unblocked/unbanned the action.
  final String? revokedByAvoraId;

  final String? revokedByDisplayNameSnapshot;
  final String? revokeReason;

  bool get isPermanent => expiresAt == null;

  bool isActiveAt(DateTime now) {
    if (status != AvoraRoomModerationHistoryStatus.active) {
      return false;
    }

    if (expiresAt != null && !now.isBefore(expiresAt!)) {
      return false;
    }

    return true;
  }

  AvoraRoomModerationHistoryRecord revoked({
    required DateTime at,
    required String byAvoraId,
    required String byDisplayNameSnapshot,
    required String reason,
  }) {
    return AvoraRoomModerationHistoryRecord(
      historyId: historyId,
      actionId: actionId,
      roomId: roomId,
      actorAvoraId: actorAvoraId,
      actorDisplayNameSnapshot: actorDisplayNameSnapshot,
      targetAvoraId: targetAvoraId,
      targetDisplayNameSnapshot: targetDisplayNameSnapshot,
      action: action,
      reasonCode: reasonCode,
      reasonText: reasonText,
      occurredAt: occurredAt,
      expiresAt: expiresAt,
      status: AvoraRoomModerationHistoryStatus.revoked,
      revokedAt: at,
      revokedByAvoraId: byAvoraId,
      revokedByDisplayNameSnapshot: byDisplayNameSnapshot,
      revokeReason: reason,
    );
  }
}

class AvoraRoomModerationHistoryEngine {
  const AvoraRoomModerationHistoryEngine._();

  static AvoraRoomModerationHistoryRecord fromRequest({
    required String historyId,
    required AvoraRoomModerationActionRequest request,
    required String actorDisplayNameSnapshot,
    required String targetDisplayNameSnapshot,
    DateTime? expiresAt,
  }) {
    return AvoraRoomModerationHistoryRecord(
      historyId: historyId,
      actionId: request.actionId,
      roomId: request.roomId,
      actorAvoraId: request.staffAvoraId,
      actorDisplayNameSnapshot: actorDisplayNameSnapshot,
      targetAvoraId: request.targetAvoraId,
      targetDisplayNameSnapshot: targetDisplayNameSnapshot,
      action: request.action,
      reasonCode: request.reasonCode,
      reasonText: request.reasonText,
      occurredAt: request.requestedAt,
      expiresAt: expiresAt,
    );
  }

  /// Immutable AVORA IDs remain authoritative even if names change later.
  static bool immutableIdsAreAuthoritative() => true;

  /// Display names are snapshots and must not be rewritten retroactively.
  static bool historicalNamesAreSnapshots() => true;

  /// Mobile clients must not silently delete moderation audit history.
  static bool clientCanDeleteAuditHistory() => false;

  /// Reversal/unban creates audit metadata instead of deleting old action.
  static bool reversalDeletesOriginalRecord() => false;

  /// Generic room inspection audit remains separate.
  static bool inspectionAuditIsSeparate() => true;
}
