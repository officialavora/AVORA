import 'avora_roles.dart';

enum AvoraEnforcementType {
  seatMute,
  roomMute,
  seatDrop,
  roomKick,
  roomBan,
  accountBan,
}

enum AvoraEnforcementDuration {
  fiveMinutes,
  tenMinutes,
  oneHour,
  twentyFourHours,
  oneWeek,
  permanent,
}

enum AvoraEnforcementStatus {
  active,
  expired,
  revoked,
}

class AvoraEnforcementRecord {
  final String id;
  final String targetUserId;
  final String issuedByUserId;

  final AvoraEnforcementType type;
  final AvoraEnforcementDuration duration;
  final AvoraScope scope;

  final String reason;

  final DateTime createdAt;
  final DateTime? expiresAt;

  final DateTime? revokedAt;
  final String? revokedByUserId;
  final String? revokeReason;

  const AvoraEnforcementRecord({
    required this.id,
    required this.targetUserId,
    required this.issuedByUserId,
    required this.type,
    required this.duration,
    required this.scope,
    required this.reason,
    required this.createdAt,
    required this.expiresAt,
    this.revokedAt,
    this.revokedByUserId,
    this.revokeReason,
  });

  factory AvoraEnforcementRecord.create({
    required String id,
    required String targetUserId,
    required String issuedByUserId,
    required AvoraEnforcementType type,
    required AvoraEnforcementDuration duration,
    required AvoraScope scope,
    required String reason,
    required DateTime createdAt,
  }) {
    return AvoraEnforcementRecord(
      id: id,
      targetUserId: targetUserId,
      issuedByUserId: issuedByUserId,
      type: type,
      duration: duration,
      scope: scope,
      reason: reason.trim(),
      createdAt: createdAt,
      expiresAt: calculateExpiry(
        duration,
        createdAt,
      ),
    );
  }

  static DateTime? calculateExpiry(
    AvoraEnforcementDuration duration,
    DateTime createdAt,
  ) {
    switch (duration) {
      case AvoraEnforcementDuration.fiveMinutes:
        return createdAt.add(const Duration(minutes: 5));
      case AvoraEnforcementDuration.tenMinutes:
        return createdAt.add(const Duration(minutes: 10));
      case AvoraEnforcementDuration.oneHour:
        return createdAt.add(const Duration(hours: 1));
      case AvoraEnforcementDuration.twentyFourHours:
        return createdAt.add(const Duration(hours: 24));
      case AvoraEnforcementDuration.oneWeek:
        return createdAt.add(const Duration(days: 7));
      case AvoraEnforcementDuration.permanent:
        return null;
    }
  }

  bool get isPermanent => duration == AvoraEnforcementDuration.permanent;

  AvoraEnforcementStatus statusAt(DateTime time) {
    if (revokedAt != null) {
      return AvoraEnforcementStatus.revoked;
    }

    if (expiresAt != null && !time.isBefore(expiresAt!)) {
      return AvoraEnforcementStatus.expired;
    }

    return AvoraEnforcementStatus.active;
  }

  bool isActiveAt(DateTime time) {
    return statusAt(time) == AvoraEnforcementStatus.active;
  }

  AvoraEnforcementRecord revoke({
    required String revokedByUserId,
    required DateTime revokedAt,
    String? reason,
  }) {
    return AvoraEnforcementRecord(
      id: id,
      targetUserId: targetUserId,
      issuedByUserId: issuedByUserId,
      type: type,
      duration: duration,
      scope: scope,
      reason: this.reason,
      createdAt: createdAt,
      expiresAt: expiresAt,
      revokedAt: revokedAt,
      revokedByUserId: revokedByUserId,
      revokeReason: reason?.trim(),
    );
  }
}
