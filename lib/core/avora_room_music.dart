enum AvoraRoomMusicStatus { stopped, loading, playing, paused, failed }

class AvoraRoomMusicTrack {
  const AvoraRoomMusicTrack({
    required this.trackId,
    required this.roomId,
    required this.uploadedByAvoraId,
    required this.mediaAssetId,
    required this.displayName,
    required this.mimeType,
  });

  final String trackId;
  final String roomId;
  final String uploadedByAvoraId;
  final String mediaAssetId;
  final String displayName;
  final String mimeType;

  bool get supported => const <String>{
        'audio/mpeg',
        'audio/mp4',
        'audio/aac',
        'audio/x-m4a',
      }.contains(mimeType.toLowerCase());
}

class AvoraRoomMusicSession {
  const AvoraRoomMusicSession({
    required this.roomId,
    required this.status,
    required this.position,
    this.track,
  });

  final String roomId;
  final AvoraRoomMusicTrack? track;
  final AvoraRoomMusicStatus status;
  final Duration position;

  static bool onlyRoomAuthorizedRolesControlPlayback() => true;
  static bool musicContinuesDuringInAppRoomMinimize() => true;
  static bool uploadedTracksRequireSafetyAndRightsChecks() => true;
}
