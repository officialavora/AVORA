import 'avora_rtc_token_contract.dart';
import 'avora_rtc_voice_contract.dart';

enum AvoraVoiceParticipationMode {
  listener,
  speaker,
}

class AvoraVoiceRoomRtcSession {
  AvoraVoiceRoomRtcSession({
    required this.provider,
    required this.tokenService,
  });

  final AvoraRtcVoiceProvider provider;
  final AvoraRtcTokenService tokenService;

  String? _roomId;
  String? _avoraId;
  AvoraVoiceParticipationMode _mode = AvoraVoiceParticipationMode.listener;

  AvoraVoiceParticipationMode get mode => _mode;

  Future<AvoraRtcSessionSnapshot> join({
    required String roomId,
    required String avoraId,
    required AvoraVoiceParticipationMode mode,
  }) async {
    final tokenGrant = await tokenService.issue(
      AvoraRtcTokenRequest(
        roomId: roomId,
        avoraId: avoraId,
        role: mode == AvoraVoiceParticipationMode.speaker
            ? AvoraRtcParticipantRole.speaker
            : AvoraRtcParticipantRole.listener,
        requestedAtUtc: DateTime.now().toUtc(),
      ),
    );

    tokenGrant.validate();

    if (tokenGrant.isExpiredAt(DateTime.now().toUtc())) {
      throw StateError('rtc_token_expired_before_join');
    }

    final snapshot = await provider.join(
      AvoraRtcJoinRequest(
        roomId: roomId,
        userId: avoraId,
        token: tokenGrant.token,
        joinAsSpeaker: mode == AvoraVoiceParticipationMode.speaker,
      ),
    );

    _roomId = roomId;
    _avoraId = avoraId;
    _mode = mode;

    return snapshot;
  }

  Future<void> becomeSpeaker() async {
    _requireJoined();

    await provider.setMicrophoneEnabled(true);
    _mode = AvoraVoiceParticipationMode.speaker;
  }

  Future<void> becomeListener() async {
    _requireJoined();

    await provider.setMicrophoneEnabled(false);
    _mode = AvoraVoiceParticipationMode.listener;
  }

  Future<void> recoverNetwork() async {
    _requireJoined();
    await provider.recoverAfterNetworkLoss();
  }

  Future<void> leave() async {
    await provider.leave();
    _roomId = null;
    _avoraId = null;
    _mode = AvoraVoiceParticipationMode.listener;
  }

  void _requireJoined() {
    if (_roomId == null || _avoraId == null) {
      throw StateError('voice_rtc_session_not_joined');
    }
  }

  static bool seatPermissionMustPrecedeSpeakerPromotion() => true;

  static bool listenerMustNotPublishMicrophoneAudio() => true;

  static bool reconnectMustNotCreateDuplicateRoomMembership() => true;

  static bool roomBusinessStateMustRemainServerAuthoritative() => true;
}
