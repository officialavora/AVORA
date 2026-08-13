enum AvoraRtcConnectionState {
  idle,
  connecting,
  connected,
  reconnecting,
  disconnected,
  failed,
}

enum AvoraRtcAudioRoute {
  speaker,
  earpiece,
  wiredHeadset,
  bluetooth,
}

class AvoraRtcJoinRequest {
  const AvoraRtcJoinRequest({
    required this.roomId,
    required this.userId,
    required this.token,
    required this.joinAsSpeaker,
  });

  final String roomId;
  final String userId;
  final String token;
  final bool joinAsSpeaker;

  void validate() {
    if (roomId.trim().isEmpty ||
        userId.trim().isEmpty ||
        token.trim().isEmpty) {
      throw StateError('rtc_join_request_invalid');
    }
  }
}

class AvoraRtcSessionSnapshot {
  const AvoraRtcSessionSnapshot({
    required this.roomId,
    required this.userId,
    required this.connectionState,
    required this.microphoneEnabled,
    required this.speakerEnabled,
    required this.audioRoute,
    required this.joinedAtUtc,
    this.lastReconnectAtUtc,
  });

  final String roomId;
  final String userId;
  final AvoraRtcConnectionState connectionState;
  final bool microphoneEnabled;
  final bool speakerEnabled;
  final AvoraRtcAudioRoute audioRoute;
  final DateTime joinedAtUtc;
  final DateTime? lastReconnectAtUtc;
}

abstract interface class AvoraRtcVoiceProvider {
  Future<AvoraRtcSessionSnapshot> join(
    AvoraRtcJoinRequest request,
  );

  Future<void> leave();

  Future<void> setMicrophoneEnabled(bool enabled);

  Future<void> setSpeakerEnabled(bool enabled);

  Future<void> setAudioRoute(AvoraRtcAudioRoute route);

  Future<void> recoverAfterNetworkLoss();

  AvoraRtcConnectionState get connectionState;
}

class AvoraRtcVoicePolicy {
  const AvoraRtcVoicePolicy();

  static bool clientMustNotMintRtcTokens() => true;

  static bool rtcTokenMustComeFromTrustedBackend() => true;

  static bool financialStateMustNotDependOnRtcClientState() => true;

  static bool roomMembershipMustRemainServerAuthoritative() => true;

  static bool reconnectMustPreserveRoomIdentity() => true;

  static bool providerMustRemainReplaceableBehindContract() => true;

  static bool voiceFailureMustNotCrashWholeRoomUi() => true;

  static bool listenerAndSpeakerStatesMustRemainDistinct() => true;
}
