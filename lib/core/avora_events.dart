enum AvoraEventType {
  national,
  cultural,
  religious,
  seasonal,
  campaign,
  special,
}

enum AvoraEventScopeType {
  global,
  country,
  region,
  family,
  room,
  targeted,
}

enum AvoraEventRewardType {
  profileFrame,
  badge,
  medal,
  entryEffect,
  roomTheme,
  giftCollection,
}

class AvoraEventScope {
  final AvoraEventScopeType type;

  /// ISO country code, region ID, family ID, room ID, etc.
  final String? scopeId;

  const AvoraEventScope._({
    required this.type,
    this.scopeId,
  });

  const AvoraEventScope.global()
      : this._(
          type: AvoraEventScopeType.global,
        );

  const AvoraEventScope.country(String countryCode)
      : this._(
          type: AvoraEventScopeType.country,
          scopeId: countryCode,
        );

  const AvoraEventScope.region(String regionId)
      : this._(
          type: AvoraEventScopeType.region,
          scopeId: regionId,
        );

  const AvoraEventScope.family(String familyId)
      : this._(
          type: AvoraEventScopeType.family,
          scopeId: familyId,
        );

  const AvoraEventScope.room(String roomId)
      : this._(
          type: AvoraEventScopeType.room,
          scopeId: roomId,
        );

  const AvoraEventScope.targeted(String targetId)
      : this._(
          type: AvoraEventScopeType.targeted,
          scopeId: targetId,
        );
}

class AvoraEventRewardDefinition {
  final String id;
  final AvoraEventRewardType type;

  /// Asset/catalog reference, not raw binary data.
  final String assetId;

  /// Optional duration after award.
  final Duration? duration;

  const AvoraEventRewardDefinition({
    required this.id,
    required this.type,
    required this.assetId,
    this.duration,
  });
}

class AvoraFestivalEvent {
  final String id;

  /// Stable catalog key such as:
  /// IN_INDEPENDENCE_DAY
  /// IN_DIWALI
  /// GLOBAL_RAMADAN_CAMPAIGN
  final String code;

  final AvoraEventType type;
  final AvoraEventScope scope;

  /// ISO country code when the event belongs to a country.
  final String? countryCode;

  /// Localized display names keyed by language code.
  /// Example: {'en': 'Diwali', 'hi': 'दीपावली'}
  final Map<String, String> localizedNames;

  /// Explicit configured schedule for this occurrence.
  final DateTime startsAt;
  final DateTime endsAt;

  /// IANA timezone name/config reference.
  final String timezoneId;

  /// Useful for movable/lunar events that change every year.
  final int eventYear;

  /// True when yearly dates are expected to be supplied
  /// by configuration instead of a fixed recurring date.
  final bool movableDate;

  final List<AvoraEventRewardDefinition> rewards;

  final bool enabled;

  AvoraFestivalEvent({
    required this.id,
    required this.code,
    required this.type,
    required this.scope,
    required this.localizedNames,
    required this.startsAt,
    required this.endsAt,
    required this.timezoneId,
    required this.eventYear,
    this.countryCode,
    this.movableDate = false,
    this.rewards = const [],
    this.enabled = true,
  }) : assert(
          !endsAt.isBefore(startsAt),
          'Event end must not be before start.',
        );

  bool isActiveAt(DateTime time) {
    if (!enabled) {
      return false;
    }

    return !time.isBefore(startsAt) && !time.isAfter(endsAt);
  }

  String displayName({
    required String languageCode,
    String fallbackLanguageCode = 'en',
  }) {
    return localizedNames[languageCode] ??
        localizedNames[fallbackLanguageCode] ??
        localizedNames.values.firstOrNull ??
        code;
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;

    if (!iterator.moveNext()) {
      return null;
    }

    return iterator.current;
  }
}
