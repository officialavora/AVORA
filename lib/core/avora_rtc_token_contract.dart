enum AvoraRtcParticipantRole {
  listener,
  speaker,
}

class AvoraRtcTokenRequest {
  const AvoraRtcTokenRequest({
    required this.roomId,
    required this.avoraId,
    required this.role,
    required this.requestedAtUtc,
  });

  final String roomId;
  final String avoraId;
  final AvoraRtcParticipantRole role;
  final DateTime requestedAtUtc;

  void validate() {
    if (roomId.trim().isEmpty || avoraId.trim().isEmpty) {
      throw StateError('rtc_token_request_identity_required');
    }
  }
}

class AvoraRtcTokenGrant {
  const AvoraRtcTokenGrant({
    required this.roomId,
    required this.avoraId,
    required this.role,
    required this.token,
    required this.issuedAtUtc,
    required this.expiresAtUtc,
  });

  final String roomId;
  final String avoraId;
  final AvoraRtcParticipantRole role;

  /// Short-lived provider token returned by trusted backend.
  final String token;

  final DateTime issuedAtUtc;
  final DateTime expiresAtUtc;

  void validate() {
    if (roomId.trim().isEmpty ||
        avoraId.trim().isEmpty ||
        token.trim().isEmpty) {
      throw StateError('invalid_rtc_token_grant');
    }

    if (!expiresAtUtc.isAfter(issuedAtUtc)) {
      throw StateError('rtc_token_expiry_invalid');
    }
  }

  bool isExpiredAt(DateTime nowUtc) {
    return !nowUtc.toUtc().isBefore(expiresAtUtc.toUtc());
  }
}

abstract interface class AvoraRtcTokenService {
  Future<AvoraRtcTokenGrant> issue(
    AvoraRtcTokenRequest request,
  );
}

class AvoraRtcTokenSecurityPolicy {
  const AvoraRtcTokenSecurityPolicy._();

  static bool providerSecretMustNeverShipInClient() => true;

  static bool tokenIssuanceMustRequireAuthenticatedUser() => true;

  static bool tokenIssuanceMustVerifyRoomMembership() => true;

  static bool speakerTokenMustVerifySeatPermission() => true;

  static bool tokensMustBeShortLived() => true;

  static bool tokenRequestsMustBeRateLimited() => true;

  static bool tokenIssuanceMustRemainAuditable() => true;

  static bool expiredTokenMustNotBeAcceptedForJoin() => true;
}
