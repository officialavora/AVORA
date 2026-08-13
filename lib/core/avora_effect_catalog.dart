import 'avora_entertainment_effects.dart';

enum AvoraEffectPackKind {
  vehicle,
  wildlife,
  royal,
  romanticCouple,
  funny,
  birthday,
  festival,
  luxury,
  seasonal,
  pkPunishment,
  emojiReaction,
  entry,
  gift,
  lucky,
  relationship,
  custom,
}

enum AvoraEffectPackStatus {
  draft,
  active,
  paused,
  retired,
  revoked,
}

class AvoraEffectPackVersion {
  final String versionId;

  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;

  final AvoraEffectPackStatus status;

  /// IDs reference Step 9B effect definitions.
  final List<String> effectIds;

  final Set<AvoraEntertainmentEffectCategory> categories;

  /// Search/discovery tags such as:
  /// car, eagle, lion, king, queen, proposal, birthday, funny.
  final Set<String> tags;

  /// Empty means global.
  final Set<String> allowedCountryCodes;

  /// Empty means not restricted to an event/festival.
  final Set<String> eventIds;
  final Set<String> festivalIds;

  /// Optional CP/friend/brother/sister/etc. integration refs.
  final Set<String> relationshipTypeRefs;

  /// External entitlement/store configuration reference.
  final String? entitlementPolicyRef;

  /// External commercial configuration reference.
  final String? pricingPolicyRef;

  final bool featured;

  /// Higher priority appears earlier.
  final int priority;

  const AvoraEffectPackVersion({
    required this.versionId,
    required this.effectiveFrom,
    required this.status,
    required this.effectIds,
    required this.categories,
    this.effectiveUntil,
    this.tags = const {},
    this.allowedCountryCodes = const {},
    this.eventIds = const {},
    this.festivalIds = const {},
    this.relationshipTypeRefs = const {},
    this.entitlementPolicyRef,
    this.pricingPolicyRef,
    this.featured = false,
    this.priority = 0,
  });

  bool activeAt(DateTime now) {
    if (status != AvoraEffectPackStatus.active) {
      return false;
    }

    if (now.isBefore(effectiveFrom)) {
      return false;
    }

    final until = effectiveUntil;

    if (until != null && !now.isBefore(until)) {
      return false;
    }

    return true;
  }

  bool countryAllowed(String countryCode) {
    if (allowedCountryCodes.isEmpty) {
      return true;
    }

    final normalized = countryCode.trim().toUpperCase();

    return allowedCountryCodes
        .map((code) => code.trim().toUpperCase())
        .contains(normalized);
  }

  bool eventAllowed(String? eventId) {
    if (eventIds.isEmpty) {
      return true;
    }

    return eventId != null && eventIds.contains(eventId);
  }

  bool festivalAllowed(String? festivalId) {
    if (festivalIds.isEmpty) {
      return true;
    }

    return festivalId != null && festivalIds.contains(festivalId);
  }

  bool relationshipAllowed(String? relationshipTypeRef) {
    if (relationshipTypeRefs.isEmpty) {
      return true;
    }

    return relationshipTypeRef != null &&
        relationshipTypeRefs.contains(relationshipTypeRef);
  }
}

class AvoraEffectPackDefinition {
  final String packId;

  final String displayName;

  final AvoraEffectPackKind kind;

  final List<AvoraEffectPackVersion> versions;

  const AvoraEffectPackDefinition({
    required this.packId,
    required this.displayName,
    required this.kind,
    required this.versions,
  });
}

class AvoraEffectCatalogQuery {
  final String countryCode;

  final AvoraEntertainmentEffectCategory? category;

  final String? eventId;
  final String? festivalId;
  final String? relationshipTypeRef;

  /// Optional search tag.
  final String? tag;

  /// Featured-only discovery mode.
  final bool featuredOnly;

  const AvoraEffectCatalogQuery({
    required this.countryCode,
    this.category,
    this.eventId,
    this.festivalId,
    this.relationshipTypeRef,
    this.tag,
    this.featuredOnly = false,
  });
}

class AvoraResolvedEffectPack {
  final String packId;

  final String displayName;

  final AvoraEffectPackKind kind;

  final String versionId;

  final List<String> effectIds;

  final Set<AvoraEntertainmentEffectCategory> categories;

  final bool featured;

  final int priority;

  final String? entitlementPolicyRef;
  final String? pricingPolicyRef;

  const AvoraResolvedEffectPack({
    required this.packId,
    required this.displayName,
    required this.kind,
    required this.versionId,
    required this.effectIds,
    required this.categories,
    required this.featured,
    required this.priority,
    required this.entitlementPolicyRef,
    required this.pricingPolicyRef,
  });
}

class AvoraHistoricalEffectPackReference {
  final String eventId;

  final String packId;

  /// Historical use retains exact pack version.
  final String packVersionId;

  final String effectId;

  final DateTime occurredAt;

  const AvoraHistoricalEffectPackReference({
    required this.eventId,
    required this.packId,
    required this.packVersionId,
    required this.effectId,
    required this.occurredAt,
  });
}

class AvoraEffectCatalogEngine {
  const AvoraEffectCatalogEngine._();

  static AvoraEffectPackVersion? effectiveVersion({
    required AvoraEffectPackDefinition pack,
    required DateTime now,
  }) {
    final active = pack.versions
        .where((version) => version.activeAt(now))
        .toList(growable: false)
      ..sort(
        (a, b) => b.effectiveFrom.compareTo(a.effectiveFrom),
      );

    if (active.isEmpty) {
      return null;
    }

    return active.first;
  }

  static bool _matchesQuery({
    required AvoraEffectPackVersion version,
    required AvoraEffectCatalogQuery query,
  }) {
    if (!version.countryAllowed(query.countryCode)) {
      return false;
    }

    final category = query.category;

    if (category != null && !version.categories.contains(category)) {
      return false;
    }

    if (!version.eventAllowed(query.eventId)) {
      return false;
    }

    if (!version.festivalAllowed(query.festivalId)) {
      return false;
    }

    if (!version.relationshipAllowed(
      query.relationshipTypeRef,
    )) {
      return false;
    }

    if (query.featuredOnly && !version.featured) {
      return false;
    }

    final requestedTag = query.tag?.trim().toLowerCase();

    if (requestedTag != null && requestedTag.isNotEmpty) {
      final normalizedTags = version.tags.map((tag) => tag.toLowerCase());

      if (!normalizedTags.contains(requestedTag)) {
        return false;
      }
    }

    return true;
  }

  static List<AvoraResolvedEffectPack> resolvePacks({
    required List<AvoraEffectPackDefinition> packs,
    required AvoraEffectCatalogQuery query,
    required DateTime now,
  }) {
    final resolved = <AvoraResolvedEffectPack>[];

    for (final pack in packs) {
      final version = effectiveVersion(
        pack: pack,
        now: now,
      );

      if (version == null) {
        continue;
      }

      if (!_matchesQuery(
        version: version,
        query: query,
      )) {
        continue;
      }

      resolved.add(
        AvoraResolvedEffectPack(
          packId: pack.packId,
          displayName: pack.displayName,
          kind: pack.kind,
          versionId: version.versionId,
          effectIds: List.unmodifiable(version.effectIds),
          categories: Set.unmodifiable(version.categories),
          featured: version.featured,
          priority: version.priority,
          entitlementPolicyRef: version.entitlementPolicyRef,
          pricingPolicyRef: version.pricingPolicyRef,
        ),
      );
    }

    resolved.sort((a, b) {
      if (a.featured != b.featured) {
        return a.featured ? -1 : 1;
      }

      final priorityCompare = b.priority.compareTo(a.priority);

      if (priorityCompare != 0) {
        return priorityCompare;
      }

      return a.displayName.compareTo(b.displayName);
    });

    return List.unmodifiable(resolved);
  }

  static List<String> buildEffectDiscoveryList({
    required List<AvoraResolvedEffectPack> packs,
  }) {
    final seen = <String>{};
    final result = <String>[];

    for (final pack in packs) {
      for (final effectId in pack.effectIds) {
        if (seen.add(effectId)) {
          result.add(effectId);
        }
      }
    }

    return List.unmodifiable(result);
  }

  /// One pack may contain many effects.
  static bool onePackIsLimitedToOneEffect() {
    return false;
  }

  /// New semantic assets do not require a new core enum value.
  static bool everyNewAssetRequiresCoreCodeChange() {
    return false;
  }

  /// Pack/catalog organization never changes gift settlement.
  static bool catalogPackChangesGiftSettlement() {
    return false;
  }

  /// Pack visibility never grants moderation/staff authority.
  static bool catalogPackGrantsAuthority() {
    return false;
  }

  /// Pricing/entitlement references remain separate policy systems.
  static bool packHardcodesCommercialEconomics() {
    return false;
  }

  /// Historical usage never silently migrates to latest pack version.
  static bool historicalPackUsesLatestVersionRetroactively() {
    return false;
  }

  /// Asset packs remain open-ended for future content.
  static bool supportsUnlimitedFutureCatalogContent() {
    return true;
  }
}
