import 'avora_experience_asset_registry.dart';
import 'avora_experience_loadout.dart';

enum AvoraExperienceDeviceTier {
  low,
  standard,
  premium,
}

enum AvoraExperienceNetworkTier {
  constrained,
  normal,
  fast,
}

enum AvoraExperienceBatteryState {
  low,
  normal,
  charging,
}

enum AvoraExperienceRenderQuality {
  blocked,
  lightweight,
  standard,
  cinematic,
}

class AvoraExperiencePlaybackContext {
  const AvoraExperiencePlaybackContext({
    required this.deviceTier,
    required this.networkTier,
    required this.batteryState,
    required this.dataSaverEnabled,
    required this.reduceMotionEnabled,
  });

  final AvoraExperienceDeviceTier deviceTier;
  final AvoraExperienceNetworkTier networkTier;
  final AvoraExperienceBatteryState batteryState;
  final bool dataSaverEnabled;
  final bool reduceMotionEnabled;
}

class AvoraExperiencePlaybackDecision {
  const AvoraExperiencePlaybackDecision({
    required this.allowed,
    required this.quality,
    required this.playAnimation,
    required this.playSound,
    required this.playMusic,
    required this.reason,
  });

  final bool allowed;
  final AvoraExperienceRenderQuality quality;
  final bool playAnimation;
  final bool playSound;
  final bool playMusic;
  final String reason;
}

class AvoraExperiencePlaybackPolicy {
  const AvoraExperiencePlaybackPolicy();

  AvoraExperiencePlaybackDecision decide({
    required AvoraExperienceAsset asset,
    required AvoraExperiencePlaybackPreference preference,
    required AvoraExperiencePlaybackContext context,
  }) {
    if (!asset.enabled) {
      return const AvoraExperiencePlaybackDecision(
        allowed: false,
        quality: AvoraExperienceRenderQuality.blocked,
        playAnimation: false,
        playSound: false,
        playMusic: false,
        reason: 'experience_asset_disabled',
      );
    }

    final animationAllowed = _animationAllowedForType(asset.type, preference);

    final soundAllowed = preference.soundEnabled && asset.soundRef != null;

    final musicAllowed = preference.musicEnabled && asset.musicRef != null;

    if (context.reduceMotionEnabled) {
      return AvoraExperiencePlaybackDecision(
        allowed: true,
        quality: AvoraExperienceRenderQuality.lightweight,
        playAnimation: false,
        playSound: soundAllowed,
        playMusic: false,
        reason: 'reduce_motion_lightweight_playback',
      );
    }

    if (context.dataSaverEnabled ||
        context.networkTier == AvoraExperienceNetworkTier.constrained) {
      return AvoraExperiencePlaybackDecision(
        allowed: true,
        quality: AvoraExperienceRenderQuality.lightweight,
        playAnimation: animationAllowed,
        playSound: soundAllowed,
        playMusic: false,
        reason: 'data_or_network_constrained_playback',
      );
    }

    if (context.batteryState == AvoraExperienceBatteryState.low ||
        context.deviceTier == AvoraExperienceDeviceTier.low) {
      return AvoraExperiencePlaybackDecision(
        allowed: true,
        quality: AvoraExperienceRenderQuality.lightweight,
        playAnimation: animationAllowed,
        playSound: soundAllowed,
        playMusic: false,
        reason: 'battery_or_device_lightweight_playback',
      );
    }

    if (context.deviceTier == AvoraExperienceDeviceTier.premium &&
        context.networkTier == AvoraExperienceNetworkTier.fast) {
      return AvoraExperiencePlaybackDecision(
        allowed: true,
        quality: AvoraExperienceRenderQuality.cinematic,
        playAnimation: animationAllowed,
        playSound: soundAllowed,
        playMusic: musicAllowed,
        reason: 'premium_cinematic_playback',
      );
    }

    return AvoraExperiencePlaybackDecision(
      allowed: true,
      quality: AvoraExperienceRenderQuality.standard,
      playAnimation: animationAllowed,
      playSound: soundAllowed,
      playMusic: musicAllowed,
      reason: 'standard_experience_playback',
    );
  }

  bool _animationAllowedForType(
    AvoraExperienceAssetType type,
    AvoraExperiencePlaybackPreference preference,
  ) {
    switch (type) {
      case AvoraExperienceAssetType.gift:
        return preference.giftAnimationEnabled;

      case AvoraExperienceAssetType.entry:
        return preference.entryAnimationEnabled;

      default:
        return true;
    }
  }

  static bool playbackPreferenceMustNotChangeOwnership() => true;

  static bool playbackPreferenceMustNotChangeCoinSettlement() => true;

  static bool lowBatteryMayReduceRenderCost() => true;

  static bool dataSaverMayReduceRenderCost() => true;

  static bool weakNetworkMayReduceRenderCost() => true;

  static bool accessibilityReduceMotionMustBeRespected() => true;

  static bool premiumDevicesMayReceiveCinematicQuality() => true;

  static bool mutedSoundMustNotDisableVisualOwnership() => true;

  static bool futureExperienceTypesMustUseSamePlaybackPolicy() => true;
}

class AvoraExperiencePlaybackResolver {
  AvoraExperiencePlaybackResolver({
    required AvoraExperienceAssetRegistry assetRegistry,
    required AvoraExperienceLoadoutLedger loadoutLedger,
  })  : _assetRegistry = assetRegistry,
        _loadoutLedger = loadoutLedger;

  final AvoraExperienceAssetRegistry _assetRegistry;
  final AvoraExperienceLoadoutLedger _loadoutLedger;

  AvoraExperienceAsset? resolveEquippedAsset({
    required String avoraId,
    required AvoraExperienceLoadoutSlot slot,
  }) {
    final equipped = _loadoutLedger.equipped(
      avoraId: avoraId,
      slot: slot,
    );

    if (equipped == null) {
      return null;
    }

    return _assetRegistry.historical(
      assetId: equipped.assetId,
      version: equipped.assetVersion,
    );
  }

  AvoraExperiencePlaybackPreference preferencesFor(
    String avoraId,
  ) {
    return _loadoutLedger.preferencesFor(avoraId);
  }

  static bool playbackMustResolveExactEquippedVersion() => true;

  static bool laterAssetVersionMustNotRewriteEquippedExperience() => true;

  static bool clientMustNotSubstituteDifferentPremiumAsset() => true;
}

class AvoraExperienceConflictPolicy {
  const AvoraExperienceConflictPolicy();

  List<AvoraExperienceLoadoutSlot> playbackPriority() {
    return const <AvoraExperienceLoadoutSlot>[
      AvoraExperienceLoadoutSlot.entry,
      AvoraExperienceLoadoutSlot.roomEffect,
      AvoraExperienceLoadoutSlot.profileEffect,
      AvoraExperienceLoadoutSlot.profileFrame,
      AvoraExperienceLoadoutSlot.signatureSound,
      AvoraExperienceLoadoutSlot.profileMusic,
      AvoraExperienceLoadoutSlot.emojiPack,
    ];
  }

  bool mayPlayMusicWithSignatureSound({
    required bool signatureSoundActive,
    required bool profileMusicActive,
  }) {
    if (signatureSoundActive && profileMusicActive) {
      return false;
    }

    return profileMusicActive;
  }

  static bool entryEffectMustHavePlaybackPriority() => true;

  static bool overlappingAudioMustBeControlled() => true;

  static bool premiumEffectsMustNotCreateAudioChaos() => true;

  static bool futureConflictRulesMustBeConfigurable() => true;
}
