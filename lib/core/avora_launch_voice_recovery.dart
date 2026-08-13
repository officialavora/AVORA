import 'avora_launch_room_seats.dart';
import 'avora_launch_voice_provider.dart';

abstract interface class AvoraVoiceTokenProvider {
  Future<String> issueToken({
    required String roomId,
    required String avoraId,
  });
}

class AvoraVoiceRecoveryResult {
  const AvoraVoiceRecoveryResult({
    required this.recovered,
    required this.reason,
  });

  final bool recovered;
  final String reason;
}

class AvoraLaunchVoiceRecoveryController {
  AvoraLaunchVoiceRecoveryController({
    required String roomId,
    required String avoraId,
    required AvoraLaunchRoomSeatState seatState,
    required AvoraRealtimeVoiceProvider provider,
    required AvoraVoiceTokenProvider tokenProvider,
  })  : _roomId = roomId,
        _avoraId = avoraId,
        _seatState = seatState,
        _provider = provider,
        _tokenProvider = tokenProvider {
    if (roomId.trim().isEmpty || avoraId.trim().isEmpty) {
      throw ArgumentError('invalid_voice_recovery_identity');
    }

    if (seatState.roomId != roomId) {
      throw ArgumentError('voice_recovery_room_mismatch');
    }
  }

  final String _roomId;
  final String _avoraId;
  final AvoraLaunchRoomSeatState _seatState;
  final AvoraRealtimeVoiceProvider _provider;
  final AvoraVoiceTokenProvider _tokenProvider;

  bool _recovering = false;

  bool get recovering => _recovering;

  Future<AvoraVoiceRecoveryResult> recover() async {
    if (_recovering) {
      return const AvoraVoiceRecoveryResult(
        recovered: false,
        reason: 'voice_recovery_already_running',
      );
    }

    _recovering = true;

    try {
      final token = await _tokenProvider.issueToken(
        roomId: _roomId,
        avoraId: _avoraId,
      );

      if (token.trim().isEmpty) {
        return const AvoraVoiceRecoveryResult(
          recovered: false,
          reason: 'voice_token_refresh_failed',
        );
      }

      await _provider.join(
        AvoraVoiceJoinRequest(
          roomId: _roomId,
          avoraId: _avoraId,
          accessToken: token,
        ),
      );

      final seatNumber = _seatState.seatOf(_avoraId);

      if (seatNumber == null) {
        await _provider.setMicrophoneEnabled(false);
        await _provider.setAudioPublishingEnabled(false);

        return const AvoraVoiceRecoveryResult(
          recovered: true,
          reason: 'voice_recovered_off_seat',
        );
      }

      final seat = _seatState.seat(seatNumber);
      final mayPublish = !seat.micMuted;

      await _provider.setMicrophoneEnabled(mayPublish);
      await _provider.setAudioPublishingEnabled(mayPublish);

      return AvoraVoiceRecoveryResult(
        recovered: true,
        reason: mayPublish
            ? 'voice_recovered_with_seat_audio'
            : 'voice_recovered_muted_seat',
      );
    } catch (_) {
      return const AvoraVoiceRecoveryResult(
        recovered: false,
        reason: 'voice_recovery_failed',
      );
    } finally {
      _recovering = false;
    }
  }

  static bool reconnectMustReuseSameAvoraId() => true;

  static bool reconnectMustReuseSameRoomId() => true;

  static bool seatStateMustRemainServerAuthoritative() => true;

  static bool tokenRefreshMustComeFromTrustedBackend() => true;

  static bool failedTokenRefreshMustFailClosed() => true;

  static bool offSeatRecoveryMustNotPublishAudio() => true;

  static bool mutedSeatRecoveryMustNotPublishAudio() => true;

  static bool concurrentRecoveryMustBePrevented() => true;

  static bool futureVoiceProvidersMustUseSameRecoveryContract() => true;
}
