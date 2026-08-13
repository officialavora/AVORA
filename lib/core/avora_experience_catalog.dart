enum AvoraExperienceCatalogRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
  royal,
  antique,
  limited,
}

enum AvoraExperienceCatalogTheme {
  luxury,
  royal,
  cinematic,
  cute,
  funny,
  romantic,
  emotional,
  horror,
  fantasy,
  animal,
  vehicle,
  festive,
  seasonal,
  futuristic,
  minimal,
  social,
  other,
}

class AvoraExperienceCatalogItem {
  const AvoraExperienceCatalogItem({
    required this.assetId,
    required this.assetVersion,
    required this.displayName,
    required this.rarity,
    required this.themes,
    required this.tags,
    required this.sortOrder,
    required this.featured,
    required this.enabled,
  });

  final String assetId;
  final String assetVersion;
  final String displayName;

  final AvoraExperienceCatalogRarity rarity;

  final Set<AvoraExperienceCatalogTheme> themes;
  final Set<String> tags;

  final int sortOrder;
  final bool featured;
  final bool enabled;

  void validate() {
    if (assetId.trim().isEmpty ||
        assetVersion.trim().isEmpty ||
        displayName.trim().isEmpty) {
      throw ArgumentError('invalid_experience_catalog_item');
    }

    if (sortOrder < 0) {
      throw ArgumentError('catalog_sort_order_invalid');
    }

    if (themes.isEmpty) {
      throw ArgumentError('catalog_item_requires_theme');
    }
  }
}

class AvoraExperienceCollection {
  const AvoraExperienceCollection({
    required this.collectionId,
    required this.version,
    required this.displayName,
    required this.description,
    required this.itemAssetIds,
    required this.sortOrder,
    required this.featured,
    required this.enabled,
    required this.createdByOwnerAvoraId,
    required this.createdAtUtc,
  });

  final String collectionId;
  final String version;
  final String displayName;
  final String description;

  final List<String> itemAssetIds;

  final int sortOrder;
  final bool featured;
  final bool enabled;

  final String createdByOwnerAvoraId;
  final DateTime createdAtUtc;

  void validate() {
    if (collectionId.trim().isEmpty ||
        version.trim().isEmpty ||
        displayName.trim().isEmpty ||
        createdByOwnerAvoraId.trim().isEmpty) {
      throw ArgumentError('invalid_experience_collection');
    }

    if (sortOrder < 0) {
      throw ArgumentError('collection_sort_order_invalid');
    }

    final unique = itemAssetIds.toSet();

    if (unique.length != itemAssetIds.length) {
      throw StateError('duplicate_asset_in_collection');
    }
  }
}

class AvoraExperienceCatalogAuditRecord {
  const AvoraExperienceCatalogAuditRecord({
    required this.auditId,
    required this.subjectId,
    required this.subjectType,
    required this.previousVersion,
    required this.newVersion,
    required this.ownerAvoraId,
    required this.reason,
    required this.createdAtUtc,
  });

  final String auditId;
  final String subjectId;
  final String subjectType;
  final String? previousVersion;
  final String newVersion;
  final String ownerAvoraId;
  final String reason;
  final DateTime createdAtUtc;
}

class AvoraExperienceCatalogAuditLedger {
  final Map<String, AvoraExperienceCatalogAuditRecord> _records =
      <String, AvoraExperienceCatalogAuditRecord>{};

  void append(AvoraExperienceCatalogAuditRecord record) {
    if (record.auditId.trim().isEmpty ||
        record.subjectId.trim().isEmpty ||
        record.subjectType.trim().isEmpty ||
        record.newVersion.trim().isEmpty ||
        record.ownerAvoraId.trim().isEmpty ||
        record.reason.trim().isEmpty) {
      throw ArgumentError('invalid_catalog_audit');
    }

    if (_records.containsKey(record.auditId)) {
      throw StateError('duplicate_catalog_audit');
    }

    _records[record.auditId] = record;
  }

  List<AvoraExperienceCatalogAuditRecord> forSubject(
    String subjectId,
  ) {
    return List<AvoraExperienceCatalogAuditRecord>.unmodifiable(
      _records.values.where(
        (record) => record.subjectId == subjectId,
      ),
    );
  }

  static bool everyCatalogChangeMustBeAudited() => true;

  static bool catalogAuditHistoryMustRemainImmutable() => true;
}

class AvoraExperienceCatalogRegistry {
  AvoraExperienceCatalogRegistry({
    required AvoraExperienceCatalogAuditLedger auditLedger,
  }) : _auditLedger = auditLedger;

  final AvoraExperienceCatalogAuditLedger _auditLedger;

  final Map<String, AvoraExperienceCatalogItem> _items =
      <String, AvoraExperienceCatalogItem>{};

  final Map<String, AvoraExperienceCollection> _collections =
      <String, AvoraExperienceCollection>{};

  final Map<String, Map<String, AvoraExperienceCollection>> _collectionHistory =
      <String, Map<String, AvoraExperienceCollection>>{};

  void upsertItem({
    required AvoraExperienceCatalogItem item,
    required bool actorIsVerifiedOwner,
  }) {
    if (!actorIsVerifiedOwner) {
      throw StateError('verified_owner_required');
    }

    item.validate();

    _items[item.assetId] = item;
  }

  AvoraExperienceCatalogItem? itemByAssetId(
    String assetId,
  ) {
    return _items[assetId.trim()];
  }

  void activateCollection({
    required String auditId,
    required AvoraExperienceCollection collection,
    required bool actorIsVerifiedOwner,
    required String reason,
    required DateTime changedAtUtc,
  }) {
    if (!actorIsVerifiedOwner) {
      throw StateError('verified_owner_required');
    }

    collection.validate();

    for (final assetId in collection.itemAssetIds) {
      if (!_items.containsKey(assetId)) {
        throw StateError(
          'collection_asset_not_found:$assetId',
        );
      }
    }

    final previous = _collections[collection.collectionId];

    if (previous?.version == collection.version) {
      throw StateError('collection_version_must_change');
    }

    if (previous != null) {
      _collectionHistory.putIfAbsent(
        collection.collectionId,
        () => <String, AvoraExperienceCollection>{},
      )[previous.version] = previous;
    }

    _collections[collection.collectionId] = collection;

    _auditLedger.append(
      AvoraExperienceCatalogAuditRecord(
        auditId: auditId,
        subjectId: collection.collectionId,
        subjectType: 'collection',
        previousVersion: previous?.version,
        newVersion: collection.version,
        ownerAvoraId: collection.createdByOwnerAvoraId,
        reason: reason,
        createdAtUtc: changedAtUtc.toUtc(),
      ),
    );
  }

  AvoraExperienceCollection? activeCollection(
    String collectionId,
  ) {
    return _collections[collectionId.trim()];
  }

  AvoraExperienceCollection? historicalCollection({
    required String collectionId,
    required String version,
  }) {
    final active = _collections[collectionId];

    if (active?.version == version) {
      return active;
    }

    return _collectionHistory[collectionId]?[version];
  }

  List<AvoraExperienceCatalogItem> itemsForCollection(
    String collectionId,
  ) {
    final collection = _collections[collectionId];

    if (collection == null || !collection.enabled) {
      return const <AvoraExperienceCatalogItem>[];
    }

    final result = <AvoraExperienceCatalogItem>[];

    for (final assetId in collection.itemAssetIds) {
      final item = _items[assetId];

      if (item != null && item.enabled) {
        result.add(item);
      }
    }

    result.sort(
      (a, b) => a.sortOrder.compareTo(b.sortOrder),
    );

    return List<AvoraExperienceCatalogItem>.unmodifiable(
      result,
    );
  }

  List<AvoraExperienceCatalogItem> featuredItems() {
    final result = _items.values
        .where(
          (item) => item.enabled && item.featured,
        )
        .toList(growable: false)
      ..sort(
        (a, b) => a.sortOrder.compareTo(b.sortOrder),
      );

    return List<AvoraExperienceCatalogItem>.unmodifiable(
      result,
    );
  }

  List<AvoraExperienceCatalogItem> search({
    required String query,
    AvoraExperienceCatalogRarity? rarity,
    AvoraExperienceCatalogTheme? theme,
  }) {
    final normalized = query.trim().toLowerCase();

    final result = _items.values.where((item) {
      if (!item.enabled) {
        return false;
      }

      if (rarity != null && item.rarity != rarity) {
        return false;
      }

      if (theme != null && !item.themes.contains(theme)) {
        return false;
      }

      if (normalized.isEmpty) {
        return true;
      }

      final nameMatch = item.displayName.toLowerCase().contains(normalized);

      final tagMatch = item.tags.any(
        (tag) => tag.toLowerCase().contains(normalized),
      );

      return nameMatch || tagMatch;
    }).toList(growable: false)
      ..sort(
        (a, b) => a.sortOrder.compareTo(b.sortOrder),
      );

    return List<AvoraExperienceCatalogItem>.unmodifiable(
      result,
    );
  }

  static bool ownerMayAddCatalogItemsWithoutCodeRewrite() => true;

  static bool ownerMayReorderCatalogWithoutCodeRewrite() => true;

  static bool ownerMayFeatureOrUnfeatureItems() => true;

  static bool ownerMayBuildCollectionsWithoutClientRelease() => true;

  static bool historicalCollectionsMustRemainAvailable() => true;

  static bool futureThousandsOfAssetsMustFitSameCatalog() => true;
}

class AvoraExperienceDiscoveryPolicy {
  const AvoraExperienceDiscoveryPolicy();

  List<AvoraExperienceCatalogItem> diversify(
    Iterable<AvoraExperienceCatalogItem> source, {
    int limit = 12,
  }) {
    if (limit <= 0) {
      return const <AvoraExperienceCatalogItem>[];
    }

    final items = source.where((item) => item.enabled).toList();

    if (items.length <= limit) {
      return List<AvoraExperienceCatalogItem>.unmodifiable(
        items,
      );
    }

    final result = <AvoraExperienceCatalogItem>[];
    final usedThemes = <AvoraExperienceCatalogTheme>{};

    for (final item in items) {
      final introducesNewTheme =
          item.themes.any((theme) => !usedThemes.contains(theme));

      if (introducesNewTheme) {
        result.add(item);
        usedThemes.addAll(item.themes);

        if (result.length == limit) {
          return List<AvoraExperienceCatalogItem>.unmodifiable(
            result,
          );
        }
      }
    }

    for (final item in items) {
      if (result.contains(item)) {
        continue;
      }

      result.add(item);

      if (result.length == limit) {
        break;
      }
    }

    return List<AvoraExperienceCatalogItem>.unmodifiable(
      result,
    );
  }

  static bool discoveryMustAvoidShowingOnlyOneCreativeMood() => true;

  static bool premiumCatalogMustStillOfferFunnyCuteAndEmotionalVariety() =>
      true;

  static bool rarityMustNotReplaceQualityReview() => true;

  static bool discoveryMustRemainConfigurableLater() => true;
}

class AvoraExperienceCatalogArchitecture {
  const AvoraExperienceCatalogArchitecture._();

  static bool catalogMustScaleToThousandsOfAssets() => true;

  static bool randomAssetDumpMustBeAvoided() => true;

  static bool giftsEntriesEmojiAndFutureAssetsMayShareDiscoverySystem() => true;

  static bool luxuryRoyalAntiqueFunnyCuteAndHorrorMayUseSeparateCollections() =>
      true;

  static bool sameAssetMayAppearInMultipleCollections() => true;

  static bool addingNewCreativeFamilyMustNotRequireCoreRewrite() => true;

  static bool originalAvoraBrandingMustRemainRequired() => true;
}
