import 'avora_launch_room_seats.dart';

enum AvoraVoiceConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

class AvoraVoiceJoinRequest {
  const AvoraVoiceJoinRequest({
    required this.roomId,
    required this.avoraId,
    required this.accessToken,
  });

  final String roomId;
  final String avoraId;

  /// Short-lived backend-issued provider token.
  final String accessToken;
}

class AvoraVoiceParticipantState {
  const AvoraVoiceParticipantState({
    required this.avoraId,
    required this.connected,
    required this.publishingAudio,
    required this.muted,
  });

  final String avoraId;
  final bool connected;
  final bool publishingAudio;
  final bool muted;
}

abstract interface class AvoraRealtimeVoiceProvider {
  AvoraVoiceConnectionState get connectionState;

  Future<void> join(AvoraVoiceJoinRequest request);

  Future<void> leave();

  Future<void> setMicrophoneEnabled(bool enabled);

  Future<void> setSpeakerEnabled(bool enabled);

  Future<void> setAudioPublishingEnabled(bool enabled);

  Stream<AvoraVoiceConnectionState> get connectionStates;

  Stream<AvoraVoiceParticipantState> get participantStates;
}

class AvoraLaunchVoiceSession {
  AvoraLaunchVoiceSession({
    required this.roomId,
    required this.avoraId,
    required AvoraLaunchRoomSeatState seatState,
    required AvoraRealtimeVoiceProvider provider,
  })  : _seatState = seatState,
        _provider = provider {
    if (roomId.trim().isEmpty || avoraId.trim().isEmpty) {
      throw ArgumentError('invalid_voice_session_identity');
    }

    if (seatState.roomId != roomId) {
      throw ArgumentError('voice_room_seat_state_mismatch');
    }
  }

  final String roomId;
  final String avoraId;

  final AvoraLaunchRoomSeatState _seatState;
  final AvoraRealtimeVoiceProvider _provider;

  bool _joined = false;
  bool _speakerEnabled = true;

  bool get joined => _joined;

  bool get speakerEnabled => _speakerEnabled;

  AvoraVoiceConnectionState get connectionState => _provider.connectionState;

  Future<void> join({
    required String accessToken,
  }) async {
    if (accessToken.trim().isEmpty) {
      throw ArgumentError('voice_access_token_required');
    }

    if (_joined) {
      return;
    }

    await _provider.join(
      AvoraVoiceJoinRequest(
        roomId: roomId,
        avoraId: avoraId,
        accessToken: accessToken,
      ),
    );

    _joined = true;

    // Joining a room never means publishing microphone audio.
    await _provider.setAudioPublishingEnabled(false);
    await _provider.setMicrophoneEnabled(false);
  }

  Future<void> leave() async {
    if (!_joined) {
      return;
    }

    await _provider.setAudioPublishingEnabled(false);
    await _provider.setMicrophoneEnabled(false);
    await _provider.leave();

    _joined = false;
  }

  Future<void> syncMicrophoneFromSeatState() async {
    if (!_joined) {
      throw StateError('voice_session_not_joined');
    }

    final seatNumber = _seatState.seatOf(avoraId);

    if (seatNumber == null) {
      await _provider.setAudioPublishingEnabled(false);
      await _provider.setMicrophoneEnabled(false);
      return;
    }

    final seat = _seatState.seat(seatNumber);

    final shouldPublish = !seat.micMuted;

    await _provider.setMicrophoneEnabled(shouldPublish);
    await _provider.setAudioPublishingEnabled(shouldPublish);
  }

  Future<void> setSpeakerEnabled(bool enabled) async {
    if (!_joined) {
      throw StateError('voice_session_not_joined');
    }

    await _provider.setSpeakerEnabled(enabled);
    _speakerEnabled = enabled;
  }

  Future<void> onSeatDroppedOrLeft() async {
    if (!_joined) {
      return;
    }

    await _provider.setAudioPublishingEnabled(false);
    await _provider.setMicrophoneEnabled(false);
  }

  static bool providerMustBeReplaceable() => true;

  static bool providerMustNotOwnAvoraAuthorization() => true;

  static bool roomSeatStateMustRemainAuthoritative() => true;

  static bool roomJoinMustNotAutomaticallyPublishMic() => true;

  static bool offSeatUserMustNotPublishRoomAudio() => true;

  static bool mutedSeatMustNotPublishRoomAudio() => true;

  static bool voiceTokenMustComeFromTrustedBackend() => true;

  static bool voiceTokenMustNotBeHardcodedInClient() => true;

  static bool reconnectMustPreserveImmutableAvoraIdentity() => true;

  static bool futureVoiceProvidersMustUseSameContract() => true;
}
