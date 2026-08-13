import 'avora_room_discovery.dart';

enum AvoraRoomPinType {
  globalOfficial,
  countryOfficial,
}

class AvoraRoomPinAssignment {
  final String id;

  final String roomId;

  final AvoraRoomPinType type;

  /// Required for countryOfficial pins.
  final String? countryCode;

  /// Official room must be approved and verified
  /// before it can receive a public pin.
  final bool approved;
  final bool roomVerified;

  final bool enabled;

  final DateTime startsAt;

  /// Null means active until manually changed/revoked.
  final DateTime? expiresAt;

  final String assignedByUserId;
  final DateTime assignedAt;

  const AvoraRoomPinAssignment({
    required this.id,
    required this.roomId,
    required this.type,
    required this.approved,
    required this.roomVerified,
    required this.enabled,
    required this.startsAt,
    required this.assignedByUserId,
    required this.assignedAt,
    this.countryCode,
    this.expiresAt,
  });

  bool isActiveAt(DateTime time) {
    if (!enabled || !approved || !roomVerified) {
      return false;
    }

    if (time.isBefore(startsAt)) {
      return false;
    }

    final expiry = expiresAt;

    if (expiry != null && time.isAfter(expiry)) {
      return false;
    }

    return true;
  }

  bool matchesCountry(String country) {
    if (type != AvoraRoomPinType.countryOfficial) {
      return false;
    }

    return countryCode?.trim().toUpperCase() == country.trim().toUpperCase();
  }
}

class AvoraRoomRankingResult {
  final AvoraRoomDiscoveryRecord? pinnedRoom;

  /// Final UI-ready list.
  /// Pinned room appears only once at position 0.
  final List<AvoraRoomDiscoveryRecord> orderedRooms;

  const AvoraRoomRankingResult({
    required this.pinnedRoom,
    required this.orderedRooms,
  });
}

class AvoraRoomRankingEngine {
  const AvoraRoomRankingEngine._();

  static AvoraRoomRankingResult build({
    required List<AvoraRoomDiscoveryRecord> rooms,
    required List<AvoraRoomPinAssignment> pins,
    required AvoraRoomDiscoveryConfig discoveryConfig,
    required DateTime now,
  }) {
    final visible = AvoraRoomDiscoveryEngine.visibleRooms(
      rooms: rooms,
      config: discoveryConfig,
    );

    final pin = _selectPin(
      visibleRooms: visible,
      pins: pins,
      discoveryConfig: discoveryConfig,
      now: now,
    );

    final pinnedRoom = pin == null
        ? null
        : visible.where((room) => room.roomId == pin.roomId).firstOrNull;

    final ordinary = visible
        .where(
          (room) => room.roomId != pinnedRoom?.roomId,
        )
        .toList(growable: true);

    ordinary.sort((a, b) {
      if (discoveryConfig.mode == AvoraRoomDiscoveryMode.countryPreferred &&
          discoveryConfig.countryCode != null) {
        final country = discoveryConfig.countryCode!;

        final aPreferred = a.belongsToCountry(country);
        final bPreferred = b.belongsToCountry(country);

        if (aPreferred != bPreferred) {
          return aPreferred ? -1 : 1;
        }
      }

      final gatheringCompare = b.participantCount.compareTo(a.participantCount);

      if (gatheringCompare != 0) {
        return gatheringCompare;
      }

      /// Stable deterministic fallback.
      return a.roomId.compareTo(b.roomId);
    });

    final ordered = <AvoraRoomDiscoveryRecord>[
      if (pinnedRoom != null) pinnedRoom,
      ...ordinary,
    ];

    return AvoraRoomRankingResult(
      pinnedRoom: pinnedRoom,
      orderedRooms: List.unmodifiable(ordered),
    );
  }

  static AvoraRoomPinAssignment? _selectPin({
    required List<AvoraRoomDiscoveryRecord> visibleRooms,
    required List<AvoraRoomPinAssignment> pins,
    required AvoraRoomDiscoveryConfig discoveryConfig,
    required DateTime now,
  }) {
    final visibleRoomIds = visibleRooms.map((room) => room.roomId).toSet();

    final eligiblePins = pins.where((pin) {
      return pin.isActiveAt(now) && visibleRoomIds.contains(pin.roomId);
    });

    switch (discoveryConfig.mode) {
      case AvoraRoomDiscoveryMode.global:
        return eligiblePins
            .where(
              (pin) => pin.type == AvoraRoomPinType.globalOfficial,
            )
            .firstOrNull;

      case AvoraRoomDiscoveryMode.countrySelected:
      case AvoraRoomDiscoveryMode.countryPreferred:
        final country = discoveryConfig.countryCode;

        if (country == null || country.trim().isEmpty) {
          return eligiblePins
              .where(
                (pin) => pin.type == AvoraRoomPinType.globalOfficial,
              )
              .firstOrNull;
        }

        return eligiblePins
            .where(
              (pin) => pin.matchesCountry(country),
            )
            .firstOrNull;
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;

    if (!iterator.moveNext()) {
      return null;
    }

    return iterator.current;
  }
}
