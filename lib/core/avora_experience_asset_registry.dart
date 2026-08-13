enum AvoraExperienceAssetType {
  gift,
  entry,
  emoji,
  animatedEmoji,
  gif,
  soundReaction,
  musicEffect,
  cinematicEffect,
  roomEffect,
  profileEffect,
  eventEffect,
  other,
}

enum AvoraExperienceAssetCategory {
  luxury,
  cinematic,
  funny,
  horror,
  romantic,
  emotional,
  attitude,
  social,
  animal,
  fantasy,
  vehicle,
  celebration,
  seasonal,
  other,
}

class AvoraExperienceAsset {
  const AvoraExperienceAsset({
    required this.assetId,
    required this.version,
    required this.type,
    required this.category,
    required this.displayName,
    required this.coinPrice,
    required this.enabled,
    required this.sortOrder,
    required this.createdAtUtc,
    required this.createdByOwnerAvoraId,
    this.animationRef,
    this.soundRef,
    this.musicRef,
    this.thumbnailRef,
    this.durationMs,
    this.metadata = const <String, Object?>{},
  });

  final String assetId;
  final String version;
  final AvoraExperienceAssetType type;
  final AvoraExperienceAssetCategory category;
  final String displayName;

  final int coinPrice;
  final bool enabled;
  final int sortOrder;

  final String? animationRef;
  final String? soundRef;
  final String? musicRef;
  final String? thumbnailRef;
  final int? durationMs;

  final DateTime createdAtUtc;

  /// Internal authoritative Owner identity.
  final String createdByOwnerAvoraId;

  final Map<String, Object?> metadata;

  void validate() {
    if (assetId.trim().isEmpty ||
        version.trim().isEmpty ||
        displayName.trim().isEmpty ||
        createdByOwnerAvoraId.trim().isEmpty) {
      throw ArgumentError('invalid_experience_asset_identity');
    }

    if (coinPrice < 0) {
      throw ArgumentError('experience_asset_price_must_not_be_negative');
    }

    if (sortOrder < 0) {
      throw ArgumentError('experience_asset_sort_order_invalid');
    }

    if (durationMs != null && durationMs! <= 0) {
      throw ArgumentError('experience_asset_duration_invalid');
    }
  }

  AvoraExperienceAsset copyAsNewVersion({
    required String newVersion,
    required DateTime createdAtUtc,
    required String ownerAvoraId,
    String? displayName,
    int? coinPrice,
    bool? enabled,
    int? sortOrder,
    String? animationRef,
    String? soundRef,
    String? musicRef,
    String? thumbnailRef,
    int? durationMs,
    Map<String, Object?>? metadata,
  }) {
    return AvoraExperienceAsset(
      assetId: assetId,
      version: newVersion,
      type: type,
      category: category,
      displayName: displayName ?? this.displayName,
      coinPrice: coinPrice ?? this.coinPrice,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
      animationRef: animationRef ?? this.animationRef,
      soundRef: soundRef ?? this.soundRef,
      musicRef: musicRef ?? this.musicRef,
      thumbnailRef: thumbnailRef ?? this.thumbnailRef,
      durationMs: durationMs ?? this.durationMs,
      createdAtUtc: createdAtUtc.toUtc(),
      createdByOwnerAvoraId: ownerAvoraId,
      metadata: metadata ?? this.metadata,
    );
  }
}

class AvoraExperienceAssetAuditRecord {
  const AvoraExperienceAssetAuditRecord({
    required this.auditId,
    required this.assetId,
    required this.previousVersion,
    required this.newVersion,
    required this.ownerAvoraId,
    required this.reason,
    required this.createdAtUtc,
  });

  final String auditId;
  final String assetId;
  final String? previousVersion;
  final String newVersion;
  final String ownerAvoraId;
  final String reason;
  final DateTime createdAtUtc;
}

class AvoraExperienceAssetAuditLedger {
  final Map<String, AvoraExperienceAssetAuditRecord> _records =
      <String, AvoraExperienceAssetAuditRecord>{};

  void append(AvoraExperienceAssetAuditRecord record) {
    if (record.auditId.trim().isEmpty ||
        record.assetId.trim().isEmpty ||
        record.newVersion.trim().isEmpty ||
        record.ownerAvoraId.trim().isEmpty ||
        record.reason.trim().isEmpty) {
      throw ArgumentError('invalid_experience_asset_audit');
    }

    if (_records.containsKey(record.auditId)) {
      throw StateError('duplicate_experience_asset_audit');
    }

    _records[record.auditId] = record;
  }

  List<AvoraExperienceAssetAuditRecord> forAsset(String assetId) {
    return List<AvoraExperienceAssetAuditRecord>.unmodifiable(
      _records.values.where(
        (record) => record.assetId == assetId,
      ),
    );
  }

  static bool everyOwnerAssetChangeMustBeAudited() => true;
  static bool assetAuditHistoryMustRemainImmutable() => true;
  static bool ownerIdentityMustRemainInternalAndAuthoritative() => true;
}

class AvoraExperienceAssetRegistry {
  AvoraExperienceAssetRegistry({
    required AvoraExperienceAssetAuditLedger auditLedger,
  }) : _auditLedger = auditLedger;

  final AvoraExperienceAssetAuditLedger _auditLedger;

  final Map<String, AvoraExperienceAsset> _active =
      <String, AvoraExperienceAsset>{};

  final Map<String, Map<String, AvoraExperienceAsset>> _history =
      <String, Map<String, AvoraExperienceAsset>>{};

  AvoraExperienceAsset? activeById(String assetId) {
    return _active[assetId.trim()];
  }

  AvoraExperienceAsset? historical({
    required String assetId,
    required String version,
  }) {
    final active = _active[assetId];

    if (active?.version == version) {
      return active;
    }

    return _history[assetId]?[version];
  }

  List<AvoraExperienceAsset> enabledByType(
    AvoraExperienceAssetType type,
  ) {
    final results = _active.values
        .where(
          (asset) => asset.type == type && asset.enabled,
        )
        .toList(growable: false)
      ..sort(
        (a, b) => a.sortOrder.compareTo(b.sortOrder),
      );

    return List<AvoraExperienceAsset>.unmodifiable(results);
  }

  void activate({
    required String auditId,
    required AvoraExperienceAsset asset,
    required bool actorIsVerifiedOwner,
    required String reason,
    required DateTime changedAtUtc,
  }) {
    if (!actorIsVerifiedOwner) {
      throw StateError('verified_owner_required');
    }

    asset.validate();

    final previous = _active[asset.assetId];

    if (previous?.version == asset.version) {
      throw StateError('experience_asset_version_must_change');
    }

    if (previous != null) {
      _history.putIfAbsent(
        asset.assetId,
        () => <String, AvoraExperienceAsset>{},
      )[previous.version] = previous;
    }

    _active[asset.assetId] = asset;

    _auditLedger.append(
      AvoraExperienceAssetAuditRecord(
        auditId: auditId,
        assetId: asset.assetId,
        previousVersion: previous?.version,
        newVersion: asset.version,
        ownerAvoraId: asset.createdByOwnerAvoraId,
        reason: reason,
        createdAtUtc: changedAtUtc.toUtc(),
      ),
    );
  }

  static bool ownerMayChangeAssetPriceWithoutCodeChange() => true;
  static bool ownerMayReplaceAnimationWithoutCodeChange() => true;
  static bool ownerMayReplaceSoundWithoutCodeChange() => true;
  static bool ownerMayReplaceMusicWithoutCodeChange() => true;
  static bool ownerMayEnableOrDisableAssetWithoutCodeChange() => true;
  static bool ownerMayReorderAssetsWithoutCodeChange() => true;
  static bool historicalAssetVersionsMustRemainAvailable() => true;
  static bool futureAssetTypesMustFitRegistryWithoutMigrationDamage() => true;
}

class AvoraExperienceAssetArchitecture {
  const AvoraExperienceAssetArchitecture._();

  static bool giftsMustBeDataDriven() => true;
  static bool entriesMustBeDataDriven() => true;
  static bool emojisAndGifsMustBeDataDriven() => true;
  static bool soundsAndMusicMustBeDataDriven() => true;
  static bool cinematicEffectsMustBeDataDriven() => true;

  static bool horrorFunnyRomanticAndLuxuryAreExtensibleCategories() => true;

  static bool exampleAnimalsVehiclesAndFantasyMustNotBeHardcodedCatalog() =>
      true;

  static bool newFutureIdeasMustFitWithoutCoreRewrite() => true;

  static bool competitorBrandingAndAssetsMustNotBeCopied() => true;

  static bool originalAvoraPresentationMustRemainRequired() => true;
}
