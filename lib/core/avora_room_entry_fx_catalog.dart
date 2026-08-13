import 'avora_room_entry_fx.dart';

enum AvoraRoomEntryFxUnlockKind {
  free,
  vip,
  svip,
  identityLevel,
  purchase,
  achievement,
  seasonal,
  event,
  ownerGrant,
  custom,
}

class AvoraRoomEntryFxCatalogItem {
  const AvoraRoomEntryFxCatalogItem({
    required this.fxId,
    required this.version,
    required this.displayName,
    required this.theme,
    required this.animationAssetRef,
    required this.soundAssetRef,
    this.avatarOverlayAssetRef,
    this.emojiOverlayAssetRef,
    this.liteAnimationAssetRef,
    this.liteSoundAssetRef,
    this.unlockKind = AvoraRoomEntryFxUnlockKind.free,
    this.minimumVipTier,
    this.minimumIdentityLevel,
    this.purchaseCoinUnits,
    this.unlockTags = const {},
    this.active = true,
    this.scary = false,
    this.effectiveFrom,
    this.effectiveUntil,
  });

  final String fxId;

  /// Versioned so future edits do not rewrite historical ownership/events.
  final int version;

  final String displayName;
  final AvoraRoomEntryFxTheme theme;

  /// Asset references only. Actual animation/media files live outside core logic.
  final String animationAssetRef;
  final String soundAssetRef;

  /// Optional animated DP / ghost / skeleton style overlay.
  final String? avatarOverlayAssetRef;

  /// Optional haunted laughing emoji / face / reaction overlay.
  final String? emojiOverlayAssetRef;

  /// Lightweight alternatives for weaker phones / low-data mode.
  final String? liteAnimationAssetRef;
  final String? liteSoundAssetRef;

  final AvoraRoomEntryFxUnlockKind unlockKind;

  final int? minimumVipTier;
  final int? minimumIdentityLevel;

  /// Optional Owner-configurable store price.
  final int? purchaseCoinUnits;

  /// Future-proof labels for events, achievements, campaigns, etc.
  final Set<String> unlockTags;

  final bool active;
  final bool scary;

  final DateTime? effectiveFrom;
  final DateTime? effectiveUntil;

  bool isEffectiveAt(DateTime now) {
    if (!active) return false;

    if (effectiveFrom != null && now.isBefore(effectiveFrom!)) {
      return false;
    }

    if (effectiveUntil != null && !now.isBefore(effectiveUntil!)) {
      return false;
    }

    return true;
  }
}

class AvoraRoomEntryFxResolvedAssets {
  const AvoraRoomEntryFxResolvedAssets({
    required this.animationAssetRef,
    required this.soundAssetRef,
    required this.avatarOverlayAssetRef,
    required this.emojiOverlayAssetRef,
    required this.usedLiteFallback,
  });

  final String animationAssetRef;
  final String soundAssetRef;
  final String? avatarOverlayAssetRef;
  final String? emojiOverlayAssetRef;
  final bool usedLiteFallback;
}

class AvoraRoomEntryFxCatalogEngine {
  static AvoraRoomEntryFxCatalogItem? findActiveVersion({
    required Iterable<AvoraRoomEntryFxCatalogItem> catalog,
    required String fxId,
    required DateTime now,
  }) {
    final matches = catalog
        .where(
          (item) => item.fxId == fxId && item.isEffectiveAt(now),
        )
        .toList()
      ..sort((a, b) => b.version.compareTo(a.version));

    return matches.isEmpty ? null : matches.first;
  }

  static AvoraRoomEntryFxResolvedAssets resolveAssets({
    required AvoraRoomEntryFxCatalogItem item,
    required bool lowDeviceMode,
  }) {
    final useLite = lowDeviceMode &&
        item.liteAnimationAssetRef != null &&
        item.liteAnimationAssetRef!.trim().isNotEmpty;

    return AvoraRoomEntryFxResolvedAssets(
      animationAssetRef:
          useLite ? item.liteAnimationAssetRef! : item.animationAssetRef,
      soundAssetRef: useLite &&
              item.liteSoundAssetRef != null &&
              item.liteSoundAssetRef!.trim().isNotEmpty
          ? item.liteSoundAssetRef!
          : item.soundAssetRef,
      avatarOverlayAssetRef: item.avatarOverlayAssetRef,
      emojiOverlayAssetRef: item.emojiOverlayAssetRef,
      usedLiteFallback: useLite,
    );
  }

  static bool isStructurallyValid(AvoraRoomEntryFxCatalogItem item) {
    return item.fxId.trim().isNotEmpty &&
        item.version > 0 &&
        item.displayName.trim().isNotEmpty &&
        item.animationAssetRef.trim().isNotEmpty &&
        item.soundAssetRef.trim().isNotEmpty &&
        (item.minimumVipTier == null || item.minimumVipTier! >= 0) &&
        (item.minimumIdentityLevel == null ||
            item.minimumIdentityLevel! >= 0) &&
        (item.purchaseCoinUnits == null || item.purchaseCoinUnits! >= 0);
  }

  /// Ghost, skeleton, haunted laugh, scream, royal etc. may each have
  /// independent animation and sound references.
  static bool perEntryAnimationAndSoundSupported() => true;

  static bool ghostOrSkeletonAvatarOverlaySupported() => true;

  static bool hauntedLaughEmojiOverlaySupported() => true;

  static bool scaryScreamSoundSupported() => true;

  /// Owner may edit catalog policy without changing app code.
  static bool ownerEditableCatalogSupported() => true;

  /// Historical event/ownership must retain the version it used.
  static bool historicalVersionSnapshotRequired() => true;

  /// Core engine never bundles/copies third-party copyrighted media.
  static bool coreLogicContainsCopyrightedMediaAssets() => false;
}
