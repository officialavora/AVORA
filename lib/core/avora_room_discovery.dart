enum AvoraRoomDiscoveryMode {
  /// Launch default: show rooms from all supported countries.
  global,

  /// Show only the country explicitly selected by the user.
  countrySelected,

  /// Show preferred country first, while still allowing global rooms.
  countryPreferred,
}

class AvoraRoomDiscoveryConfig {
  final AvoraRoomDiscoveryMode mode;

  /// ISO country code such as IN, PK, BD, NP, SA.
  final String? countryCode;

  const AvoraRoomDiscoveryConfig({
    this.mode = AvoraRoomDiscoveryMode.global,
    this.countryCode,
  });
}

class AvoraRoomDiscoveryRecord {
  final String roomId;

  /// Normalized ISO country metadata.
  final String countryCode;

  final Set<String> languageCodes;

  final bool discoverable;
  final bool roomActive;

  final int participantCount;

  const AvoraRoomDiscoveryRecord({
    required this.roomId,
    required this.countryCode,
    required this.languageCodes,
    required this.discoverable,
    required this.roomActive,
    required this.participantCount,
  }) : assert(participantCount >= 0);

  bool belongsToCountry(String code) {
    return countryCode.trim().toUpperCase() == code.trim().toUpperCase();
  }
}

class AvoraRoomDiscoveryEngine {
  const AvoraRoomDiscoveryEngine._();

  static List<AvoraRoomDiscoveryRecord> visibleRooms({
    required List<AvoraRoomDiscoveryRecord> rooms,
    AvoraRoomDiscoveryConfig config = const AvoraRoomDiscoveryConfig(),
  }) {
    final active = rooms
        .where(
          (room) => room.discoverable && room.roomActive,
        )
        .toList(growable: false);

    switch (config.mode) {
      case AvoraRoomDiscoveryMode.global:
        return active;

      case AvoraRoomDiscoveryMode.countrySelected:
        final country = config.countryCode?.trim();

        if (country == null || country.isEmpty) {
          return active;
        }

        return active
            .where(
              (room) => room.belongsToCountry(country),
            )
            .toList(growable: false);

      case AvoraRoomDiscoveryMode.countryPreferred:
        final country = config.countryCode?.trim();

        if (country == null || country.isEmpty) {
          return active;
        }

        final sorted = List<AvoraRoomDiscoveryRecord>.from(active);

        sorted.sort((a, b) {
          final aPreferred = a.belongsToCountry(country);
          final bPreferred = b.belongsToCountry(country);

          if (aPreferred != bPreferred) {
            return aPreferred ? -1 : 1;
          }

          return b.participantCount.compareTo(
            a.participantCount,
          );
        });

        return sorted;
    }
  }
}
