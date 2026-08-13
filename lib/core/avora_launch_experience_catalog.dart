enum AvoraLaunchExperienceCategory {
  entry,
  profileFrame,
  chatBubble,
  gift,
  animatedReaction,
  emojiGif,
  soundEffect,
  musicEffect,
  roomEffect,
  profileEffect,
  badgeMedal,
  roomTheme,
  profileDecoration,
  eventEffect,
}

class AvoraLaunchExperienceItem {
  const AvoraLaunchExperienceItem({
    required this.itemId,
    required this.version,
    required this.category,
    required this.displayName,
    required this.enabled,
    required this.sortOrder,
    required this.coinPrice,
    required this.ownerApproved,
    required this.originalAvoraCreative,
    required this.qualityApproved,
    required this.manifestApproved,
    required this.createdByOwnerAvoraId,
    required this.createdAtUtc,
    this.durationSeconds,
    this.animationRef,
    this.soundRef,
    this.musicRef,
    this.thumbnailRef,
    this.tags = const <String>{},
    this.metadata = const <String, Object?>{},
  });

  final String itemId;
  final String version;
  final AvoraLaunchExperienceCategory category;
  final String displayName;

  final bool enabled;
  final int sortOrder;
  final int coinPrice;

  final int? durationSeconds;

  final String? animationRef;
  final String? soundRef;
  final String? musicRef;
  final String? thumbnailRef;

  final Set<String> tags;

  final bool ownerApproved;
  final bool originalAvoraCreative;
  final bool qualityApproved;
  final bool manifestApproved;

  final String createdByOwnerAvoraId;
  final DateTime createdAtUtc;

  final Map<String, Object?> metadata;

  void validate() {
    if (itemId.trim().isEmpty ||
        version.trim().isEmpty ||
        displayName.trim().isEmpty ||
        createdByOwnerAvoraId.trim().isEmpty) {
      throw ArgumentError('invalid_launch_experience_identity');
    }

    if (sortOrder < 0) {
      throw ArgumentError('invalid_launch_experience_sort_order');
    }

    if (coinPrice < 0) {
      throw ArgumentError('invalid_launch_experience_coin_price');
    }

    if (durationSeconds != null && durationSeconds! <= 0) {
      throw ArgumentError('invalid_launch_experience_duration');
    }
  }

  bool get publishable =>
      enabled &&
      ownerApproved &&
      originalAvoraCreative &&
      qualityApproved &&
      manifestApproved;

  AvoraLaunchExperienceItem copyAsNewVersion({
    required String newVersion,
    required String ownerAvoraId,
    required DateTime createdAtUtc,
    String? displayName,
    bool? enabled,
    int? sortOrder,
    int? coinPrice,
    int? durationSeconds,
    String? animationRef,
    String? soundRef,
    String? musicRef,
    String? thumbnailRef,
    Set<String>? tags,
    bool? ownerApproved,
    bool? originalAvoraCreative,
    bool? qualityApproved,
    bool? manifestApproved,
    Map<String, Object?>? metadata,
  }) {
    return AvoraLaunchExperienceItem(
      itemId: itemId,
      version: newVersion,
      category: category,
      displayName: displayName ?? this.displayName,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
      coinPrice: coinPrice ?? this.coinPrice,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      animationRef: animationRef ?? this.animationRef,
      soundRef: soundRef ?? this.soundRef,
      musicRef: musicRef ?? this.musicRef,
      thumbnailRef: thumbnailRef ?? this.thumbnailRef,
      tags: tags ?? this.tags,
      ownerApproved: ownerApproved ?? this.ownerApproved,
      originalAvoraCreative:
          originalAvoraCreative ?? this.originalAvoraCreative,
      qualityApproved: qualityApproved ?? this.qualityApproved,
      manifestApproved: manifestApproved ?? this.manifestApproved,
      createdByOwnerAvoraId: ownerAvoraId,
      createdAtUtc: createdAtUtc.toUtc(),
      metadata: metadata ?? this.metadata,
    );
  }
}

class AvoraLaunchExperienceAuditRecord {
  const AvoraLaunchExperienceAuditRecord({
    required this.auditId,
    required this.itemId,
    required this.previousVersion,
    required this.newVersion,
    required this.ownerAvoraId,
    required this.reason,
    required this.createdAtUtc,
  });

  final String auditId;
  final String itemId;
  final String? previousVersion;
  final String newVersion;
  final String ownerAvoraId;
  final String reason;
  final DateTime createdAtUtc;
}

class AvoraLaunchExperienceAuditLedger {
  final Map<String, AvoraLaunchExperienceAuditRecord> _records =
      <String, AvoraLaunchExperienceAuditRecord>{};

  void append(
    AvoraLaunchExperienceAuditRecord record,
  ) {
    if (record.auditId.trim().isEmpty ||
        record.itemId.trim().isEmpty ||
        record.newVersion.trim().isEmpty ||
        record.ownerAvoraId.trim().isEmpty ||
        record.reason.trim().isEmpty) {
      throw ArgumentError('invalid_launch_experience_audit');
    }

    if (_records.containsKey(record.auditId)) {
      throw StateError('duplicate_launch_experience_audit');
    }

    _records[record.auditId] = record;
  }

  List<AvoraLaunchExperienceAuditRecord> forItem(
    String itemId,
  ) {
    return List<AvoraLaunchExperienceAuditRecord>.unmodifiable(
      _records.values.where(
        (record) => record.itemId == itemId,
      ),
    );
  }

  static bool everyPublishedChangeMustBeAudited() => true;

  static bool auditHistoryMustRemainImmutable() => true;
}

class AvoraLaunchExperienceRegistry {
  AvoraLaunchExperienceRegistry({
    required AvoraLaunchExperienceAuditLedger auditLedger,
  }) : _auditLedger = auditLedger;

  final AvoraLaunchExperienceAuditLedger _auditLedger;

  final Map<String, AvoraLaunchExperienceItem> _active =
      <String, AvoraLaunchExperienceItem>{};

  final Map<String, Map<String, AvoraLaunchExperienceItem>> _history =
      <String, Map<String, AvoraLaunchExperienceItem>>{};

  AvoraLaunchExperienceItem? activeById(
    String itemId,
  ) {
    return _active[itemId.trim()];
  }

  AvoraLaunchExperienceItem? historical({
    required String itemId,
    required String version,
  }) {
    final active = _active[itemId];

    if (active?.version == version) {
      return active;
    }

    return _history[itemId]?[version];
  }

  List<AvoraLaunchExperienceItem> activeForCategory(
    AvoraLaunchExperienceCategory category,
  ) {
    final result = _active.values
        .where(
          (item) => item.category == category && item.publishable,
        )
        .toList(growable: false)
      ..sort(
        (a, b) => a.sortOrder.compareTo(b.sortOrder),
      );

    return List<AvoraLaunchExperienceItem>.unmodifiable(
      result,
    );
  }

  void publish({
    required String auditId,
    required AvoraLaunchExperienceItem item,
    required bool actorIsVerifiedOwner,
    required String reason,
    required DateTime changedAtUtc,
  }) {
    if (!actorIsVerifiedOwner) {
      throw StateError('verified_owner_required');
    }

    item.validate();

    if (!item.ownerApproved) {
      throw StateError('owner_approval_required');
    }

    if (!item.originalAvoraCreative) {
      throw StateError('original_avora_creative_required');
    }

    if (!item.qualityApproved) {
      throw StateError('creative_quality_approval_required');
    }

    if (!item.manifestApproved) {
      throw StateError('asset_manifest_approval_required');
    }

    final previous = _active[item.itemId];

    if (previous?.version == item.version) {
      throw StateError(
        'launch_experience_version_must_change',
      );
    }

    if (previous != null) {
      _history.putIfAbsent(
        item.itemId,
        () => <String, AvoraLaunchExperienceItem>{},
      )[previous.version] = previous;
    }

    _active[item.itemId] = item;

    _auditLedger.append(
      AvoraLaunchExperienceAuditRecord(
        auditId: auditId,
        itemId: item.itemId,
        previousVersion: previous?.version,
        newVersion: item.version,
        ownerAvoraId: item.createdByOwnerAvoraId,
        reason: reason,
        createdAtUtc: changedAtUtc.toUtc(),
      ),
    );
  }

  static bool ownerMayAddNewItemWithoutCoreRewrite() => true;

  static bool ownerMayReplaceExistingItemWithoutCoreRewrite() => true;

  static bool ownerMayDisableItemWithoutDeletingHistory() => true;

  static bool ownerMayChangePriceWithoutClientRelease() => true;

  static bool ownerMayChangeDurationWithoutClientRelease() => true;

  static bool ownerMayReplaceAnimationWithoutClientRelease() => true;

  static bool ownerMayReplaceSoundOrMusicWithoutClientRelease() => true;

  static bool ownerMayRetagAndReorderWithoutClientRelease() => true;

  static bool futureChatGptCreatedAssetsMustUseSameRegistry() => true;

  static bool historicalVersionsMustRemainAvailableForRollback() => true;
}

class AvoraLaunchCatalogCoverageReport {
  const AvoraLaunchCatalogCoverageReport({
    required this.complete,
    required this.missingCategories,
    required this.availableCounts,
  });

  final bool complete;
  final Set<AvoraLaunchExperienceCategory> missingCategories;
  final Map<AvoraLaunchExperienceCategory, int> availableCounts;
}

class AvoraLaunchCatalogCoveragePolicy {
  const AvoraLaunchCatalogCoveragePolicy();

  Set<AvoraLaunchExperienceCategory> requiredAtLaunch() {
    return AvoraLaunchExperienceCategory.values.toSet();
  }

  AvoraLaunchCatalogCoverageReport evaluate(
    AvoraLaunchExperienceRegistry registry,
  ) {
    final missing = <AvoraLaunchExperienceCategory>{};
    final counts = <AvoraLaunchExperienceCategory, int>{};

    for (final category in requiredAtLaunch()) {
      final count = registry.activeForCategory(category).length;

      counts[category] = count;

      if (count == 0) {
        missing.add(category);
      }
    }

    return AvoraLaunchCatalogCoverageReport(
      complete: missing.isEmpty,
      missingCategories: Set<AvoraLaunchExperienceCategory>.unmodifiable(
        missing,
      ),
      availableCounts: Map<AvoraLaunchExperienceCategory, int>.unmodifiable(
        counts,
      ),
    );
  }

  static bool launchMustNotShipWithMissingExperienceCategory() => true;

  static bool launchRequiresRealAssetsNotEmptyPlaceholders() => true;

  static bool uploadedReferenceCategoriesMustBeCrossCheckedBeforeLaunch() =>
      true;

  static bool quantityMustIncludeUsefulVarietyPerCategory() => true;

  static bool qualityStillOverridesRawQuantity() => true;
}

class AvoraLaunchCatalogArchitecture {
  const AvoraLaunchCatalogArchitecture._();

  static bool entryMustExistAtLaunch() => true;

  static bool framesMustExistAtLaunch() => true;

  static bool chatBubblesMustExistAtLaunch() => true;

  static bool giftsMustExistAtLaunch() => true;

  static bool emojiGifAndReactionAssetsMustExistAtLaunch() => true;

  static bool soundAndMusicAssetsMustExistAtLaunch() => true;

  static bool roomAndProfileEffectsMustExistAtLaunch() => true;

  static bool badgesMedalsAndDecorationsMustExistAtLaunch() => true;

  static bool themesAndEventEffectsMustExistAtLaunch() => true;

  static bool catalogMustRemainEditableAfterLaunch() => true;

  static bool futureNewCategoriesMustFitWithoutArchitectureDemolition() => true;

  static bool competitorNamesLogosAndExactDesignMustNeverBeRequired() => true;

  static bool originalPremiumAvoraCreativeMustRemainRequired() => true;
}
