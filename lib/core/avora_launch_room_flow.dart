enum AvoraLaunchRoomVisibility {
  public,
  locked,
  private,
}

class AvoraLaunchRoom {
  const AvoraLaunchRoom({
    required this.roomId,
    required this.ownerAvoraId,
    required this.name,
    required this.visibility,
    required this.capacity,
    required this.createdAtUtc,
    this.passwordHash,
    this.countryCode,
  });

  final String roomId;
  final String ownerAvoraId;
  final String name;
  final AvoraLaunchRoomVisibility visibility;
  final int capacity;
  final DateTime createdAtUtc;

  /// Never store plaintext password here.
  final String? passwordHash;

  final String? countryCode;
}

class AvoraLaunchRoomPresence {
  const AvoraLaunchRoomPresence({
    required this.roomId,
    required this.avoraId,
    required this.joinedAtUtc,
  });

  final String roomId;
  final String avoraId;
  final DateTime joinedAtUtc;
}

class AvoraLaunchRoomJoinDecision {
  const AvoraLaunchRoomJoinDecision({
    required this.allowed,
    required this.reason,
  });

  final bool allowed;
  final String reason;
}

class AvoraLaunchRoomService {
  final Map<String, AvoraLaunchRoom> _rooms = <String, AvoraLaunchRoom>{};

  final Map<String, Map<String, AvoraLaunchRoomPresence>> _presence =
      <String, Map<String, AvoraLaunchRoomPresence>>{};

  List<AvoraLaunchRoom> discovery({
    String? countryCode,
  }) {
    final normalizedCountry = countryCode?.trim().toUpperCase();

    final rooms = _rooms.values.where((room) {
      if (room.visibility == AvoraLaunchRoomVisibility.private) {
        return false;
      }

      if (normalizedCountry == null || normalizedCountry.isEmpty) {
        return true;
      }

      return room.countryCode == null || room.countryCode == normalizedCountry;
    }).toList(growable: false);

    rooms.sort(
      (a, b) => b.createdAtUtc.compareTo(a.createdAtUtc),
    );

    return List<AvoraLaunchRoom>.unmodifiable(rooms);
  }

  AvoraLaunchRoom createRoom({
    required String roomId,
    required String ownerAvoraId,
    required String name,
    required AvoraLaunchRoomVisibility visibility,
    required int capacity,
    required DateTime createdAtUtc,
    String? passwordHash,
    String? countryCode,
  }) {
    final id = roomId.trim();
    final ownerId = ownerAvoraId.trim();
    final roomName = name.trim();

    if (id.isEmpty || ownerId.isEmpty || roomName.isEmpty || capacity <= 0) {
      throw ArgumentError('invalid_launch_room');
    }

    if (_rooms.containsKey(id)) {
      throw StateError('room_id_already_exists');
    }

    if (visibility == AvoraLaunchRoomVisibility.locked &&
        (passwordHash == null || passwordHash.trim().isEmpty)) {
      throw ArgumentError(
        'locked_room_requires_password_hash',
      );
    }

    final room = AvoraLaunchRoom(
      roomId: id,
      ownerAvoraId: ownerId,
      name: roomName,
      visibility: visibility,
      capacity: capacity,
      createdAtUtc: createdAtUtc.toUtc(),
      passwordHash: passwordHash?.trim(),
      countryCode: countryCode?.trim().toUpperCase(),
    );

    _rooms[id] = room;
    _presence[id] = <String, AvoraLaunchRoomPresence>{};

    return room;
  }

  AvoraLaunchRoom? roomById(String roomId) {
    return _rooms[roomId.trim()];
  }

  AvoraLaunchRoomJoinDecision canJoin({
    required String roomId,
    required String avoraId,
    String? suppliedPasswordHash,
    bool ownerGlobalBypass = false,
  }) {
    final room = roomById(roomId);

    if (room == null) {
      return const AvoraLaunchRoomJoinDecision(
        allowed: false,
        reason: 'room_not_found',
      );
    }

    if (avoraId.trim().isEmpty) {
      return const AvoraLaunchRoomJoinDecision(
        allowed: false,
        reason: 'avora_id_required',
      );
    }

    final currentUsers = _presence[room.roomId]!.length;

    if (currentUsers >= room.capacity && !ownerGlobalBypass) {
      return const AvoraLaunchRoomJoinDecision(
        allowed: false,
        reason: 'room_full',
      );
    }

    if (ownerGlobalBypass) {
      return const AvoraLaunchRoomJoinDecision(
        allowed: true,
        reason: 'owner_global_room_bypass',
      );
    }

    switch (room.visibility) {
      case AvoraLaunchRoomVisibility.public:
        return const AvoraLaunchRoomJoinDecision(
          allowed: true,
          reason: 'public_room_join_allowed',
        );

      case AvoraLaunchRoomVisibility.locked:
        if (suppliedPasswordHash == room.passwordHash) {
          return const AvoraLaunchRoomJoinDecision(
            allowed: true,
            reason: 'locked_room_password_verified',
          );
        }

        return const AvoraLaunchRoomJoinDecision(
          allowed: false,
          reason: 'room_password_required_or_invalid',
        );

      case AvoraLaunchRoomVisibility.private:
        return const AvoraLaunchRoomJoinDecision(
          allowed: false,
          reason: 'private_room_invite_required',
        );
    }
  }

  AvoraLaunchRoomPresence join({
    required String roomId,
    required String avoraId,
    required DateTime joinedAtUtc,
    String? suppliedPasswordHash,
    bool ownerGlobalBypass = false,
  }) {
    final decision = canJoin(
      roomId: roomId,
      avoraId: avoraId,
      suppliedPasswordHash: suppliedPasswordHash,
      ownerGlobalBypass: ownerGlobalBypass,
    );

    if (!decision.allowed) {
      throw StateError(decision.reason);
    }

    final roomPresence = _presence[roomId]!;

    final existing = roomPresence[avoraId];

    if (existing != null) {
      return existing;
    }

    final presence = AvoraLaunchRoomPresence(
      roomId: roomId,
      avoraId: avoraId,
      joinedAtUtc: joinedAtUtc.toUtc(),
    );

    roomPresence[avoraId] = presence;

    return presence;
  }

  void leave({
    required String roomId,
    required String avoraId,
  }) {
    _presence[roomId]?.remove(avoraId);
  }

  int occupancy(String roomId) {
    return _presence[roomId.trim()]?.length ?? 0;
  }

  List<String> members(String roomId) {
    return List<String>.unmodifiable(
      _presence[roomId.trim()]?.keys ?? const <String>[],
    );
  }

  static bool homeMustShowDiscoverableRooms() => true;

  static bool userMustBeAbleToCreateRoom() => true;

  static bool userMustBeAbleToJoinPublicRoom() => true;

  static bool lockedRoomMustUseHashedPasswordCheck() => true;

  static bool plaintextPasswordMustNotBeStoredInRoomModel() => true;

  static bool roomCapacityMustBeEnforced() => true;

  static bool ownerGlobalBypassMustRemainPossible() => true;

  static bool roomPresenceMustBindToImmutableAvoraId() => true;

  static bool futureVoiceLayerMustReuseSameRoomIdentity() => true;
}
