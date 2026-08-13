enum AvoraOperationalEntityType {
  user,
  room,
  agency,
  seller,
  merchant,
  family,
  relationship,
  transaction,
  order,
  reference,
}

enum AvoraOperationalField {
  avatar,
  displayName,
  avoraId,
  vanityUid,
  accountStatus,
  onlineStatus,
  lastSeenAt,
  country,
  region,
  city,
  temperatureC,
  agencyId,
  roomId,
  validActiveMinutes,
  targetProgressBps,
  workSummary,
  rechargeSummary,
}

enum AvoraLocationPrecision {
  none,
  country,
  region,
  city,
  approximate,
  precise,
}

class AvoraCoarseLocationSnapshot {
  const AvoraCoarseLocationSnapshot({
    this.countryCode,
    this.regionName,
    this.cityName,
    this.temperatureC,
    this.temperatureObservedAt,
    required this.capturedAt,
    this.precision = AvoraLocationPrecision.city,
    required this.collectionAuthorized,
    this.publicSharingEnabled = false,
    this.ownerOperationalAccessAllowed = false,
  });

  final String? countryCode;
  final String? regionName;
  final String? cityName;
  final double? temperatureC;
  final DateTime? temperatureObservedAt;
  final DateTime capturedAt;
  final AvoraLocationPrecision precision;

  /// Location must not be collected merely because a UI wants to show it.
  final bool collectionAuthorized;

  /// User-controlled public/profile visibility.
  final bool publicSharingEnabled;

  /// Operational visibility must also be allowed by policy/consent.
  final bool ownerOperationalAccessAllowed;

  bool get canShowPublic => collectionAuthorized && publicSharingEnabled;

  bool get canShowToOwner =>
      collectionAuthorized && ownerOperationalAccessAllowed;

  bool temperatureIsFresh(
    DateTime now, {
    Duration maxAge = const Duration(minutes: 30),
  }) {
    final observedAt = temperatureObservedAt;
    if (observedAt == null || temperatureC == null) return false;
    return !now.isBefore(observedAt) && now.difference(observedAt) <= maxAge;
  }

  /// Precise/live coordinates are deliberately not stored in this
  /// coarse operational/profile object.
  static bool coarseProfileStoresPreciseCoordinates() => false;
}

class AvoraOperationalSearchRecord {
  const AvoraOperationalSearchRecord({
    required this.entityType,
    required this.primaryId,
    required this.displayName,
    this.avatarRef,
    this.avoraId,
    this.vanityUid,
    this.countryCode,
    this.agencyId,
    this.roomId,
    this.active = true,
    this.online = false,
    this.lastSeenAt,
    this.validActiveMinutes,
    this.targetProgressBps,
    this.workSummary,
    this.location,
  });

  final AvoraOperationalEntityType entityType;
  final String primaryId;
  final String displayName;
  final String? avatarRef;

  /// Immutable AVORA ID for user-like entities.
  final String? avoraId;

  /// Optional public luxury/vanity UID. Never replaces avoraId.
  final String? vanityUid;

  final String? countryCode;
  final String? agencyId;
  final String? roomId;

  final bool active;
  final bool online;
  final DateTime? lastSeenAt;

  final int? validActiveMinutes;

  /// 10000 bps = 100%.
  final int? targetProgressBps;

  final String? workSummary;
  final AvoraCoarseLocationSnapshot? location;
}

class AvoraOperationalSearchAuthority {
  AvoraOperationalSearchAuthority({
    required this.actorAvoraId,
    this.isOwner = false,
    Set<AvoraOperationalEntityType>? allowedEntityTypes,
    Set<AvoraOperationalField>? visibleFields,
    Set<String>? countryCodes,
    Set<String>? agencyIds,
    Set<String>? roomIds,
    this.globalScope = false,
    this.canVerifyRechargeRecipientGlobally = false,
  })  : allowedEntityTypes = Set.unmodifiable(allowedEntityTypes ?? const {}),
        visibleFields = Set.unmodifiable(visibleFields ?? const {}),
        countryCodes = Set.unmodifiable(countryCodes ?? const {}),
        agencyIds = Set.unmodifiable(agencyIds ?? const {}),
        roomIds = Set.unmodifiable(roomIds ?? const {});

  final String actorAvoraId;

  /// Owner has global operational scope, but secret credentials are
  /// intentionally not part of this search model at all.
  final bool isOwner;

  final Set<AvoraOperationalEntityType> allowedEntityTypes;
  final Set<AvoraOperationalField> visibleFields;

  final Set<String> countryCodes;
  final Set<String> agencyIds;
  final Set<String> roomIds;

  final bool globalScope;

  /// Seller/Merchant may exact-verify a recharge recipient globally
  /// without gaining unrestricted global user browsing.
  final bool canVerifyRechargeRecipientGlobally;

  bool canViewField(AvoraOperationalField field) {
    return isOwner || visibleFields.contains(field);
  }

  bool allowsRecord(AvoraOperationalSearchRecord record) {
    if (isOwner) return true;

    if (!allowedEntityTypes.contains(record.entityType)) {
      return false;
    }

    if (globalScope) return true;

    final countryMatch =
        record.countryCode != null && countryCodes.contains(record.countryCode);

    final agencyMatch =
        record.agencyId != null && agencyIds.contains(record.agencyId);

    final roomMatch = record.roomId != null && roomIds.contains(record.roomId);

    return countryMatch || agencyMatch || roomMatch;
  }

  bool allowsExactRechargeRecipient(
    AvoraOperationalSearchRecord record,
  ) {
    if (record.entityType != AvoraOperationalEntityType.user) {
      return false;
    }

    return isOwner ||
        canVerifyRechargeRecipientGlobally ||
        allowsRecord(record);
  }

  /// Passwords, OAuth tokens, signing keys and equivalent secrets
  /// never become searchable operational fields.
  static bool rawSecretsAreSearchable() => false;
}

class AvoraOperationalSearchEngine {
  static AvoraOperationalSearchRecord? exactByAvoraId({
    required Iterable<AvoraOperationalSearchRecord> records,
    required String avoraId,
    required AvoraOperationalSearchAuthority authority,
  }) {
    final query = avoraId.trim();
    if (query.isEmpty) return null;

    for (final record in records) {
      if (record.avoraId == query && authority.allowsRecord(record)) {
        return record;
      }
    }

    return null;
  }

  static List<AvoraOperationalSearchRecord> search({
    required Iterable<AvoraOperationalSearchRecord> records,
    required String query,
    required AvoraOperationalSearchAuthority authority,
    int limit = 50,
  }) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty || limit <= 0) return const [];

    final matches = records.where((record) {
      if (!authority.allowsRecord(record)) return false;

      return record.primaryId.toLowerCase().contains(normalized) ||
          record.displayName.toLowerCase().contains(normalized) ||
          (record.avoraId?.toLowerCase().contains(normalized) ?? false) ||
          (record.vanityUid?.toLowerCase().contains(normalized) ?? false);
    }).take(limit);

    return List.unmodifiable(matches);
  }

  static bool publicCanSeeLocation(
    AvoraOperationalSearchRecord record,
  ) {
    return record.location?.canShowPublic ?? false;
  }

  static bool ownerCanSeeOperationalLocation(
    AvoraOperationalSearchRecord record,
    AvoraOperationalSearchAuthority authority,
  ) {
    if (!authority.isOwner) return false;
    return record.location?.canShowToOwner ?? false;
  }
}

class AvoraSellerRecipientCard {
  const AvoraSellerRecipientCard({
    required this.avoraId,
    required this.displayName,
    this.avatarRef,
    required this.active,
  });

  final String avoraId;
  final String displayName;
  final String? avatarRef;
  final bool active;
}

class AvoraSellerRecipientVerification {
  const AvoraSellerRecipientVerification({
    required this.found,
    required this.eligible,
    this.card,
    this.reason,
  });

  final bool found;
  final bool eligible;
  final AvoraSellerRecipientCard? card;
  final String? reason;
}

class AvoraSellerRecipientVerifier {
  static AvoraSellerRecipientVerification verify({
    required Iterable<AvoraOperationalSearchRecord> records,
    required String avoraId,
    required AvoraOperationalSearchAuthority authority,
  }) {
    final query = avoraId.trim();
    if (query.isEmpty) {
      return const AvoraSellerRecipientVerification(
        found: false,
        eligible: false,
        reason: 'emptyAvoraId',
      );
    }

    AvoraOperationalSearchRecord? match;

    for (final record in records) {
      if (record.avoraId == query &&
          authority.allowsExactRechargeRecipient(record)) {
        match = record;
        break;
      }
    }

    if (match == null) {
      return const AvoraSellerRecipientVerification(
        found: false,
        eligible: false,
        reason: 'recipientNotFoundOrNotAllowed',
      );
    }

    final card = AvoraSellerRecipientCard(
      avoraId: match.avoraId!,
      displayName: match.displayName,
      avatarRef: match.avatarRef,
      active: match.active,
    );

    if (!match.active) {
      return AvoraSellerRecipientVerification(
        found: true,
        eligible: false,
        card: card,
        reason: 'recipientInactive',
      );
    }

    return AvoraSellerRecipientVerification(
      found: true,
      eligible: true,
      card: card,
    );
  }
}
