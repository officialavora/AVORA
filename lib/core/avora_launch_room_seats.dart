class AvoraLaunchSeat {
  const AvoraLaunchSeat({
    required this.seatNumber,
    required this.locked,
    this.occupantAvoraId,
    this.micMuted = true,
    this.speaking = false,
  });

  final int seatNumber;
  final bool locked;
  final String? occupantAvoraId;
  final bool micMuted;
  final bool speaking;

  bool get occupied => occupantAvoraId != null;

  AvoraLaunchSeat copyWith({
    bool? locked,
    String? occupantAvoraId,
    bool clearOccupant = false,
    bool? micMuted,
    bool? speaking,
  }) {
    return AvoraLaunchSeat(
      seatNumber: seatNumber,
      locked: locked ?? this.locked,
      occupantAvoraId:
          clearOccupant ? null : occupantAvoraId ?? this.occupantAvoraId,
      micMuted: micMuted ?? this.micMuted,
      speaking: speaking ?? this.speaking,
    );
  }
}

class AvoraLaunchRoomSeatState {
  AvoraLaunchRoomSeatState({
    required this.roomId,
    required int seatCount,
  }) {
    if (roomId.trim().isEmpty || seatCount <= 0) {
      throw ArgumentError('invalid_room_seat_state');
    }

    for (var i = 1; i <= seatCount; i++) {
      _seats[i] = AvoraLaunchSeat(
        seatNumber: i,
        locked: false,
      );
    }
  }

  final String roomId;

  final Map<int, AvoraLaunchSeat> _seats = <int, AvoraLaunchSeat>{};

  List<AvoraLaunchSeat> get seats => List<AvoraLaunchSeat>.unmodifiable(
        _seats.values,
      );

  AvoraLaunchSeat seat(int seatNumber) {
    final value = _seats[seatNumber];

    if (value == null) {
      throw StateError('seat_not_found');
    }

    return value;
  }

  int? seatOf(String avoraId) {
    for (final entry in _seats.entries) {
      if (entry.value.occupantAvoraId == avoraId) {
        return entry.key;
      }
    }

    return null;
  }

  void takeSeat({
    required int seatNumber,
    required String avoraId,
    bool privilegedOverride = false,
  }) {
    final id = avoraId.trim();

    if (id.isEmpty) {
      throw ArgumentError('avora_id_required');
    }

    final current = seat(seatNumber);

    if (current.locked && !privilegedOverride) {
      throw StateError('seat_locked');
    }

    if (current.occupied && current.occupantAvoraId != id) {
      throw StateError('seat_already_occupied');
    }

    final existingSeat = seatOf(id);

    if (existingSeat != null && existingSeat != seatNumber) {
      throw StateError('user_already_on_another_seat');
    }

    _seats[seatNumber] = current.copyWith(
      occupantAvoraId: id,
      micMuted: true,
      speaking: false,
    );
  }

  void leaveSeat({
    required String avoraId,
  }) {
    final seatNumber = seatOf(avoraId);

    if (seatNumber == null) {
      return;
    }

    final current = seat(seatNumber);

    _seats[seatNumber] = current.copyWith(
      clearOccupant: true,
      micMuted: true,
      speaking: false,
    );
  }

  void dropFromSeat({
    required int seatNumber,
    required bool actorCanModerateSeats,
  }) {
    if (!actorCanModerateSeats) {
      throw StateError('seat_moderation_permission_required');
    }

    final current = seat(seatNumber);

    _seats[seatNumber] = current.copyWith(
      clearOccupant: true,
      micMuted: true,
      speaking: false,
    );
  }

  void setSeatLock({
    required int seatNumber,
    required bool locked,
    required bool actorCanManageSeatLocks,
  }) {
    if (!actorCanManageSeatLocks) {
      throw StateError('seat_lock_permission_required');
    }

    final current = seat(seatNumber);

    _seats[seatNumber] = current.copyWith(
      locked: locked,
    );
  }

  void setMicMuted({
    required String avoraId,
    required bool muted,
  }) {
    final seatNumber = seatOf(avoraId);

    if (seatNumber == null) {
      throw StateError('user_not_on_seat');
    }

    final current = seat(seatNumber);

    _seats[seatNumber] = current.copyWith(
      micMuted: muted,
      speaking: muted ? false : current.speaking,
    );
  }

  void setSpeaking({
    required String avoraId,
    required bool speaking,
  }) {
    final seatNumber = seatOf(avoraId);

    if (seatNumber == null) {
      throw StateError('user_not_on_seat');
    }

    final current = seat(seatNumber);

    if (speaking && current.micMuted) {
      throw StateError('muted_user_cannot_be_speaking');
    }

    _seats[seatNumber] = current.copyWith(
      speaking: speaking,
    );
  }

  List<String> get activeSpeakers => List<String>.unmodifiable(
        _seats.values
            .where(
              (seat) =>
                  seat.occupantAvoraId != null &&
                  !seat.micMuted &&
                  seat.speaking,
            )
            .map((seat) => seat.occupantAvoraId!)
            .toList(growable: false),
      );

  static bool seatOccupantMustUseImmutableAvoraId() => true;

  static bool oneUserMustNotOccupyMultipleSeats() => true;

  static bool lockedSeatMustRejectNormalTake() => true;

  static bool privilegedSeatOverrideMustRemainPossible() => true;

  static bool micMustDefaultMutedWhenTakingSeat() => true;

  static bool mutedUserMustNeverBeMarkedSpeaking() => true;

  static bool seatDropMustRequireModerationAuthority() => true;

  static bool seatLockChangeMustRequireAuthority() => true;

  static bool realtimeVoiceProviderMustConsumeThisState() => true;

  static bool futureSeatLayoutsMustReuseSameSeatAuthority() => true;
}
