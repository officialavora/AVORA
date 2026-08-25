import 'avora_room_entry_fx.dart';
import 'avora_room_entry_fx_catalog.dart';

enum AvoraRoomEntryFxPresetCategory {
  animal,
  horror,
  funny,
  royal,
  fantasy,
  premium,
}

class AvoraRoomEntryFxPreset {
  const AvoraRoomEntryFxPreset({
    required this.category,
    required this.catalogItem,
    required this.recommendedAudience,
    required this.recommendedSoundMode,
    required this.recommendedDurationSeconds,
    required this.recommendedSoundSeconds,
    required this.recommendedOverlayOpacityBps,
  });

  final AvoraRoomEntryFxPresetCategory category;
  final AvoraRoomEntryFxCatalogItem catalogItem;

  final AvoraRoomEntryFxAudience recommendedAudience;
  final AvoraRoomEntryFxSoundMode recommendedSoundMode;

  final int recommendedDurationSeconds;
  final int recommendedSoundSeconds;
  final int recommendedOverlayOpacityBps;
}

class AvoraRoomEntryFxPresetCatalog {
  const AvoraRoomEntryFxPresetCatalog._();

  static List<AvoraRoomEntryFxPreset> starterCatalog() {
    return const [
      AvoraRoomEntryFxPreset(
        category: AvoraRoomEntryFxPresetCategory.animal,
        catalogItem: AvoraRoomEntryFxCatalogItem(
          fxId: 'lion-roar-entry',
          version: 1,
          displayName: 'Lion Roar',
          theme: AvoraRoomEntryFxTheme.custom,
          animationAssetRef: 'entry/animal/lion/full',
          soundAssetRef: 'sound/animal/lion/roar',
          avatarOverlayAssetRef: 'overlay/animal/lion',
          liteAnimationAssetRef: 'entry/animal/lion/lite',
          liteSoundAssetRef: 'sound/animal/lion/roar-lite',
          unlockKind: AvoraRoomEntryFxUnlockKind.custom,
          unlockTags: {'animal', 'lion', 'roar'},
        ),
        recommendedAudience: AvoraRoomEntryFxAudience.roomWide,
        recommendedSoundMode: AvoraRoomEntryFxSoundMode.required,
        recommendedDurationSeconds: 8,
        recommendedSoundSeconds: 5,
        recommendedOverlayOpacityBps: 7000,
      ),
      AvoraRoomEntryFxPreset(
        category: AvoraRoomEntryFxPresetCategory.animal,
        catalogItem: AvoraRoomEntryFxCatalogItem(
          fxId: 'elephant-entry',
          version: 1,
          displayName: 'Elephant Arrival',
          theme: AvoraRoomEntryFxTheme.custom,
          animationAssetRef: 'entry/animal/elephant/full',
          soundAssetRef: 'sound/animal/elephant/trumpet',
          avatarOverlayAssetRef: 'overlay/animal/elephant',
          liteAnimationAssetRef: 'entry/animal/elephant/lite',
          liteSoundAssetRef: 'sound/animal/elephant/trumpet-lite',
          unlockKind: AvoraRoomEntryFxUnlockKind.custom,
          unlockTags: {'animal', 'elephant', 'trumpet'},
        ),
        recommendedAudience: AvoraRoomEntryFxAudience.roomWide,
        recommendedSoundMode: AvoraRoomEntryFxSoundMode.required,
        recommendedDurationSeconds: 8,
        recommendedSoundSeconds: 5,
        recommendedOverlayOpacityBps: 6500,
      ),
      AvoraRoomEntryFxPreset(
        category: AvoraRoomEntryFxPresetCategory.animal,
        catalogItem: AvoraRoomEntryFxCatalogItem(
          fxId: 'eagle-dive-entry',
          version: 1,
          displayName: 'Eagle Dive',
          theme: AvoraRoomEntryFxTheme.custom,
          animationAssetRef: 'entry/animal/eagle/full',
          soundAssetRef: 'sound/animal/eagle/screech',
          avatarOverlayAssetRef: 'overlay/animal/eagle',
          liteAnimationAssetRef: 'entry/animal/eagle/lite',
          liteSoundAssetRef: 'sound/animal/eagle/screech-lite',
          unlockKind: AvoraRoomEntryFxUnlockKind.custom,
          unlockTags: {'animal', 'eagle', 'flight'},
        ),
        recommendedAudience: AvoraRoomEntryFxAudience.roomWide,
        recommendedSoundMode: AvoraRoomEntryFxSoundMode.required,
        recommendedDurationSeconds: 7,
        recommendedSoundSeconds: 4,
        recommendedOverlayOpacityBps: 6000,
      ),
      AvoraRoomEntryFxPreset(
        category: AvoraRoomEntryFxPresetCategory.animal,
        catalogItem: AvoraRoomEntryFxCatalogItem(
          fxId: 'horse-gallop-entry',
          version: 1,
          displayName: 'Royal Horse',
          theme: AvoraRoomEntryFxTheme.custom,
          animationAssetRef: 'entry/animal/horse/full',
          soundAssetRef: 'sound/animal/horse/gallop-neigh',
          avatarOverlayAssetRef: 'overlay/animal/horse',
          liteAnimationAssetRef: 'entry/animal/horse/lite',
          liteSoundAssetRef: 'sound/animal/horse/gallop-lite',
          unlockKind: AvoraRoomEntryFxUnlockKind.custom,
          unlockTags: {'animal', 'horse', 'gallop'},
        ),
        recommendedAudience: AvoraRoomEntryFxAudience.roomWide,
        recommendedSoundMode: AvoraRoomEntryFxSoundMode.required,
        recommendedDurationSeconds: 8,
        recommendedSoundSeconds: 5,
        recommendedOverlayOpacityBps: 6000,
      ),
      AvoraRoomEntryFxPreset(
        category: AvoraRoomEntryFxPresetCategory.animal,
        catalogItem: AvoraRoomEntryFxCatalogItem(
          fxId: 'parrot-funny-entry',
          version: 1,
          displayName: 'Mischief Parrot',
          theme: AvoraRoomEntryFxTheme.custom,
          animationAssetRef: 'entry/animal/parrot/full',
          soundAssetRef: 'sound/animal/parrot/funny',
          emojiOverlayAssetRef: 'overlay/funny/parrot-reaction',
          liteAnimationAssetRef: 'entry/animal/parrot/lite',
          liteSoundAssetRef: 'sound/animal/parrot/funny-lite',
          unlockKind: AvoraRoomEntryFxUnlockKind.custom,
          unlockTags: {'animal', 'funny', 'parrot'},
        ),
        recommendedAudience: AvoraRoomEntryFxAudience.roomWide,
        recommendedSoundMode: AvoraRoomEntryFxSoundMode.optional,
        recommendedDurationSeconds: 6,
        recommendedSoundSeconds: 4,
        recommendedOverlayOpacityBps: 4500,
      ),
      AvoraRoomEntryFxPreset(
        category: AvoraRoomEntryFxPresetCategory.funny,
        catalogItem: AvoraRoomEntryFxCatalogItem(
          fxId: 'frog-bounce-entry',
          version: 1,
          displayName: 'Bounce Frog',
          theme: AvoraRoomEntryFxTheme.custom,
          animationAssetRef: 'entry/funny/frog/full',
          soundAssetRef: 'sound/funny/frog/croak',
          emojiOverlayAssetRef: 'overlay/funny/frog-face',
          liteAnimationAssetRef: 'entry/funny/frog/lite',
          liteSoundAssetRef: 'sound/funny/frog/croak-lite',
          unlockKind: AvoraRoomEntryFxUnlockKind.custom,
          unlockTags: {'frog', 'funny', 'comedy'},
        ),
        recommendedAudience: AvoraRoomEntryFxAudience.roomWide,
        recommendedSoundMode: AvoraRoomEntryFxSoundMode.optional,
        recommendedDurationSeconds: 6,
        recommendedSoundSeconds: 4,
        recommendedOverlayOpacityBps: 4500,
      ),
      AvoraRoomEntryFxPreset(
        category: AvoraRoomEntryFxPresetCategory.fantasy,
        catalogItem: AvoraRoomEntryFxCatalogItem(
          fxId: 'fire-dragon-entry',
          version: 1,
          displayName: 'Fire Dragon',
          theme: AvoraRoomEntryFxTheme.fireDragon,
          animationAssetRef: 'entry/fantasy/dragon/full',
          soundAssetRef: 'sound/fantasy/dragon/roar-fire',
          avatarOverlayAssetRef: 'overlay/fantasy/dragon',
          liteAnimationAssetRef: 'entry/fantasy/dragon/lite',
          liteSoundAssetRef: 'sound/fantasy/dragon/roar-lite',
          unlockKind: AvoraRoomEntryFxUnlockKind.custom,
          unlockTags: {'dragon', 'fire', 'fantasy'},
        ),
        recommendedAudience: AvoraRoomEntryFxAudience.roomWide,
        recommendedSoundMode: AvoraRoomEntryFxSoundMode.required,
        recommendedDurationSeconds: 10,
        recommendedSoundSeconds: 7,
        recommendedOverlayOpacityBps: 8000,
      ),
      AvoraRoomEntryFxPreset(
        category: AvoraRoomEntryFxPresetCategory.horror,
        catalogItem: AvoraRoomEntryFxCatalogItem(
          fxId: 'ghost-scream-entry',
          version: 1,
          displayName: 'Ghost Scream',
          theme: AvoraRoomEntryFxTheme.horrorGhost,
          animationAssetRef: 'entry/horror/ghost/full',
          soundAssetRef: 'sound/horror/ghost/scream',
          avatarOverlayAssetRef: 'overlay/horror/ghost',
          liteAnimationAssetRef: 'entry/horror/ghost/lite',
          liteSoundAssetRef: 'sound/horror/ghost/scream-lite',
          unlockKind: AvoraRoomEntryFxUnlockKind.custom,
          unlockTags: {'ghost', 'horror', 'scream'},
          scary: true,
        ),
        recommendedAudience: AvoraRoomEntryFxAudience.roomWide,
        recommendedSoundMode: AvoraRoomEntryFxSoundMode.required,
        recommendedDurationSeconds: 9,
        recommendedSoundSeconds: 6,
        recommendedOverlayOpacityBps: 7800,
      ),
      AvoraRoomEntryFxPreset(
        category: AvoraRoomEntryFxPresetCategory.horror,
        catalogItem: AvoraRoomEntryFxCatalogItem(
          fxId: 'skeleton-shock-entry',
          version: 1,
          displayName: 'Skeleton Shock',
          theme: AvoraRoomEntryFxTheme.skeletonShock,
          animationAssetRef: 'entry/horror/skeleton/full',
          soundAssetRef: 'sound/horror/skeleton/rattle-scream',
          avatarOverlayAssetRef: 'overlay/horror/skeleton',
          liteAnimationAssetRef: 'entry/horror/skeleton/lite',
          liteSoundAssetRef: 'sound/horror/skeleton/rattle-lite',
          unlockKind: AvoraRoomEntryFxUnlockKind.custom,
          unlockTags: {'skeleton', 'horror', 'shock'},
          scary: true,
        ),
        recommendedAudience: AvoraRoomEntryFxAudience.roomWide,
        recommendedSoundMode: AvoraRoomEntryFxSoundMode.required,
        recommendedDurationSeconds: 9,
        recommendedSoundSeconds: 6,
        recommendedOverlayOpacityBps: 7800,
      ),
      AvoraRoomEntryFxPreset(
        category: AvoraRoomEntryFxPresetCategory.horror,
        catalogItem: AvoraRoomEntryFxCatalogItem(
          fxId: 'haunted-laugh-entry',
          version: 1,
          displayName: 'Haunted Laugh',
          theme: AvoraRoomEntryFxTheme.darkFog,
          animationAssetRef: 'entry/horror/haunted-laugh/full',
          soundAssetRef: 'sound/horror/haunted-laugh/creepy',
          emojiOverlayAssetRef: 'overlay/horror/haunted-laugh-face',
          liteAnimationAssetRef: 'entry/horror/haunted-laugh/lite',
          liteSoundAssetRef: 'sound/horror/haunted-laugh/lite',
          unlockKind: AvoraRoomEntryFxUnlockKind.custom,
          unlockTags: {'haunted', 'laugh', 'horror'},
          scary: true,
        ),
        recommendedAudience: AvoraRoomEntryFxAudience.roomWide,
        recommendedSoundMode: AvoraRoomEntryFxSoundMode.required,
        recommendedDurationSeconds: 8,
        recommendedSoundSeconds: 6,
        recommendedOverlayOpacityBps: 7600,
      ),
      AvoraRoomEntryFxPreset(
        category: AvoraRoomEntryFxPresetCategory.royal,
        catalogItem: AvoraRoomEntryFxCatalogItem(
          fxId: 'king-entry',
          version: 1,
          displayName: 'Royal King',
          theme: AvoraRoomEntryFxTheme.royalKing,
          animationAssetRef: 'entry/royal/king/full',
          soundAssetRef: 'sound/royal/king/fanfare',
          avatarOverlayAssetRef: 'overlay/royal/crown',
          liteAnimationAssetRef: 'entry/royal/king/lite',
          liteSoundAssetRef: 'sound/royal/king/fanfare-lite',
          unlockKind: AvoraRoomEntryFxUnlockKind.custom,
          unlockTags: {'king', 'royal', 'crown'},
        ),
        recommendedAudience: AvoraRoomEntryFxAudience.roomWide,
        recommendedSoundMode: AvoraRoomEntryFxSoundMode.optional,
        recommendedDurationSeconds: 8,
        recommendedSoundSeconds: 5,
        recommendedOverlayOpacityBps: 5500,
      ),
      AvoraRoomEntryFxPreset(
        category: AvoraRoomEntryFxPresetCategory.royal,
        catalogItem: AvoraRoomEntryFxCatalogItem(
          fxId: 'queen-entry',
          version: 1,
          displayName: 'Royal Queen',
          theme: AvoraRoomEntryFxTheme.custom,
          animationAssetRef: 'entry/royal/queen/full',
          soundAssetRef: 'sound/royal/queen/elegant',
          avatarOverlayAssetRef: 'overlay/royal/queen-crown',
          liteAnimationAssetRef: 'entry/royal/queen/lite',
          liteSoundAssetRef: 'sound/royal/queen/elegant-lite',
          unlockKind: AvoraRoomEntryFxUnlockKind.custom,
          unlockTags: {'queen', 'royal', 'elegant'},
        ),
        recommendedAudience: AvoraRoomEntryFxAudience.roomWide,
        recommendedSoundMode: AvoraRoomEntryFxSoundMode.optional,
        recommendedDurationSeconds: 8,
        recommendedSoundSeconds: 4,
        recommendedOverlayOpacityBps: 5000,
      ),
      AvoraRoomEntryFxPreset(
        category: AvoraRoomEntryFxPresetCategory.fantasy,
        catalogItem: AvoraRoomEntryFxCatalogItem(
          fxId: 'thunder-entry',
          version: 1,
          displayName: 'Thunder Arrival',
          theme: AvoraRoomEntryFxTheme.thunderStorm,
          animationAssetRef: 'entry/fantasy/thunder/full',
          soundAssetRef: 'sound/fantasy/thunder/impact',
          liteAnimationAssetRef: 'entry/fantasy/thunder/lite',
          liteSoundAssetRef: 'sound/fantasy/thunder/impact-lite',
          unlockKind: AvoraRoomEntryFxUnlockKind.custom,
          unlockTags: {'thunder', 'lightning', 'power'},
        ),
        recommendedAudience: AvoraRoomEntryFxAudience.roomWide,
        recommendedSoundMode: AvoraRoomEntryFxSoundMode.required,
        recommendedDurationSeconds: 7,
        recommendedSoundSeconds: 5,
        recommendedOverlayOpacityBps: 7000,
      ),
    ];
  }

  static bool hasDistinctSoundPerPreset() {
    final sounds = starterCatalog()
        .map((preset) => preset.catalogItem.soundAssetRef)
        .toSet();

    return sounds.length == starterCatalog().length;
  }

  static bool containsScaryAndFunnyAndRoyalEntries() {
    final categories = starterCatalog().map((e) => e.category).toSet();

    return categories.contains(AvoraRoomEntryFxPresetCategory.horror) &&
        categories.contains(AvoraRoomEntryFxPresetCategory.funny) &&
        categories.contains(AvoraRoomEntryFxPresetCategory.royal) &&
        categories.contains(AvoraRoomEntryFxPresetCategory.animal) &&
        categories.contains(AvoraRoomEntryFxPresetCategory.fantasy);
  }

  /// Presets are starter metadata only; Owner/backend may add,
  /// disable, replace, reprice or version entries later.
  static bool starterCatalogIsOwnerExtendable() => true;

  /// Actual copyrighted third-party media is not embedded here.
  static bool containsBundledThirdPartyMedia() => false;
}
