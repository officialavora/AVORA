enum AvoraOwnerControlArea {
  account,
  device,
  room,
}

enum AvoraOwnerControlAction {
  inspect,
  accountBan,
  accountUnban,
  deviceBan,
  deviceUnban,
  roomBan,
  roomUnban,
  editRoomName,
  editRoomDp,
  editRoomBackground,
  editRoomPassword,
  editRoomAnnouncement,
  editRoomWelcome,
}

class AvoraOwnerControlRequest {
  const AvoraOwnerControlRequest({
    required this.actorAvoraId,
    required this.actorIsVerifiedOwner,
    required this.targetId,
    required this.area,
    required this.action,
    required this.requestedAtUtc,
    this.reason,
  });

  final String actorAvoraId;
  final bool actorIsVerifiedOwner;
  final String targetId;
  final AvoraOwnerControlArea area;
  final AvoraOwnerControlAction action;
  final DateTime requestedAtUtc;
  final String? reason;
}

class AvoraOwnerControlEngine {
  const AvoraOwnerControlEngine();

  void authorize(AvoraOwnerControlRequest request) {
    if (!request.actorIsVerifiedOwner) {
      throw StateError('verified_owner_required');
    }

    if (request.actorAvoraId.trim().isEmpty ||
        request.targetId.trim().isEmpty) {
      throw StateError('owner_control_identity_required');
    }
  }

  static bool deviceAndAccountInspectionMustBeAudited() => true;

  static bool roomSensitiveChangesMustBeAudited() => true;

  static bool passwordsMustNeverBeReturnedAsPlaintext() => true;

  static bool privateCredentialsMustNeverBeExposed() => true;

  static bool ownerMayControlGlobalScope() => true;

  static bool delegatedControlMustRespectGrantedScope() => true;

  static bool roomIdentityAndSettingsUseAuthoritativeSource() => true;
}
