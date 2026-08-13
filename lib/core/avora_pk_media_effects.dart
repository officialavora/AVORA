enum AvoraPkMode {
  audioRoom,
  liveVideo,
}

enum AvoraPkMatchType {
  friendInvite,
  directChallenge,
  randomRoom,
}

enum AvoraPkState {
  waiting,
  active,
  punishment,
  completed,
  cancelled,
}

enum AvoraMicProfile {
  normalChat,
  singingKaraoke,
  radioMusic,
  hostEvent,
  punishmentEffect,
}

enum AvoraAudioEffectCapability {
  noiseReduction,
  echoCancellation,
  reverb,
  voiceChanger,
  pitchControl,
  singingBeautifier,
  timbre,
  inEarMonitoring,
  musicMixing,
}

enum AvoraBeautyCapability {
  smoothing,
  whitening,
  sharpening,
  faceShape,
  lipstick,
  blush,
  eyeEffect,
  eyebrow,
  contourHighlight,
  colorFilter,
  sticker,
  arMask,
  virtualBackground,
  styleMakeup,
}

enum AvoraPkPunishmentEffectType {
  profileOverlay,
  seatOverlay,
  funnyFrame,
  sticker,
  temporaryBadge,
  micVoiceEffect,
  liveFaceArEffect,
}

class AvoraMediaProviderCapabilities {
  final String providerId;

  final Set<AvoraAudioEffectCapability> audioEffects;
  final Set<AvoraBeautyCapability> beautyEffects;

  final bool supportsAudioPk;
  final bool supportsVideoPk;

  const AvoraMediaProviderCapabilities({
    required this.providerId,
    required this.audioEffects,
    required this.beautyEffects,
    required this.supportsAudioPk,
    required this.supportsVideoPk,
  });

  bool supportsAudioEffect(
    AvoraAudioEffectCapability effect,
  ) {
    return audioEffects.contains(effect);
  }

  bool supportsBeautyEffect(
    AvoraBeautyCapability effect,
  ) {
    return beautyEffects.contains(effect);
  }
}

class AvoraBeautySetting {
  final AvoraBeautyCapability capability;

  /// 0 = off, 10000 = maximum configured intensity.
  final int intensityBps;

  final String? assetId;

  const AvoraBeautySetting({
    required this.capability,
    required this.intensityBps,
    this.assetId,
  }) : assert(
          intensityBps >= 0 && intensityBps <= 10000,
        );
}

class AvoraMakeupPreset {
  final String id;
  final String name;

  final List<AvoraBeautySetting> settings;

  /// Premium entitlement may be required.
  final bool premium;

  final bool enabled;

  const AvoraMakeupPreset({
    required this.id,
    required this.name,
    required this.settings,
    this.premium = false,
    this.enabled = true,
  });
}

class AvoraMicProfileConfig {
  final AvoraMicProfile profile;

  final Set<AvoraAudioEffectCapability> requestedEffects;

  /// Catalog/provider-specific preset IDs.
  final String? voicePresetId;
  final String? reverbPresetId;

  const AvoraMicProfileConfig({
    required this.profile,
    required this.requestedEffects,
    this.voicePresetId,
    this.reverbPresetId,
  });
}

class AvoraPkSession {
  final String id;

  final AvoraPkMode mode;
  final AvoraPkMatchType matchType;

  final String challengerUserId;
  final String opponentUserId;

  final String? challengerRoomId;
  final String? opponentRoomId;

  final AvoraPkState state;

  final int challengerScore;
  final int opponentScore;

  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;

  const AvoraPkSession({
    required this.id,
    required this.mode,
    required this.matchType,
    required this.challengerUserId,
    required this.opponentUserId,
    required this.state,
    required this.challengerScore,
    required this.opponentScore,
    required this.createdAt,
    this.challengerRoomId,
    this.opponentRoomId,
    this.startedAt,
    this.endedAt,
  })  : assert(challengerScore >= 0),
        assert(opponentScore >= 0);

  String? get winnerUserId {
    if (challengerScore == opponentScore) {
      return null;
    }

    return challengerScore > opponentScore ? challengerUserId : opponentUserId;
  }

  String? get loserUserId {
    if (challengerScore == opponentScore) {
      return null;
    }

    return challengerScore < opponentScore ? challengerUserId : opponentUserId;
  }
}

class AvoraPkPunishmentDefinition {
  final String id;

  final AvoraPkPunishmentEffectType effectType;

  final String effectAssetId;

  final Duration duration;

  /// Audio/room and live/video may use different effects.
  final Set<AvoraPkMode> allowedModes;

  final bool requiresConsent;
  final bool enabled;

  const AvoraPkPunishmentDefinition({
    required this.id,
    required this.effectType,
    required this.effectAssetId,
    required this.duration,
    required this.allowedModes,
    this.requiresConsent = false,
    this.enabled = true,
  });

  bool supportsMode(AvoraPkMode mode) {
    return enabled && allowedModes.contains(mode);
  }
}

enum AvoraPkEffectDecisionReason {
  allowed,
  effectDisabled,
  modeNotSupported,
  consentRequired,
  providerCapabilityMissing,
  userEffectsDisabled,
}

class AvoraPkEffectDecision {
  final bool allowed;

  final AvoraPkEffectDecisionReason reason;

  const AvoraPkEffectDecision({
    required this.allowed,
    required this.reason,
  });
}

class AvoraPkMediaEffectsPolicy {
  const AvoraPkMediaEffectsPolicy._();

  static AvoraPkEffectDecision evaluatePunishment({
    required AvoraPkPunishmentDefinition punishment,
    required AvoraPkMode mode,
    required bool consentGranted,
    required bool userEffectsAllowed,
    required AvoraMediaProviderCapabilities provider,
  }) {
    if (!punishment.enabled) {
      return const AvoraPkEffectDecision(
        allowed: false,
        reason: AvoraPkEffectDecisionReason.effectDisabled,
      );
    }

    if (!punishment.supportsMode(mode)) {
      return const AvoraPkEffectDecision(
        allowed: false,
        reason: AvoraPkEffectDecisionReason.modeNotSupported,
      );
    }

    if (punishment.requiresConsent && !consentGranted) {
      return const AvoraPkEffectDecision(
        allowed: false,
        reason: AvoraPkEffectDecisionReason.consentRequired,
      );
    }

    if (!userEffectsAllowed) {
      return const AvoraPkEffectDecision(
        allowed: false,
        reason: AvoraPkEffectDecisionReason.userEffectsDisabled,
      );
    }

    if (mode == AvoraPkMode.audioRoom && !provider.supportsAudioPk) {
      return const AvoraPkEffectDecision(
        allowed: false,
        reason: AvoraPkEffectDecisionReason.providerCapabilityMissing,
      );
    }

    if (mode == AvoraPkMode.liveVideo && !provider.supportsVideoPk) {
      return const AvoraPkEffectDecision(
        allowed: false,
        reason: AvoraPkEffectDecisionReason.providerCapabilityMissing,
      );
    }

    return const AvoraPkEffectDecision(
      allowed: true,
      reason: AvoraPkEffectDecisionReason.allowed,
    );
  }

  static List<AvoraBeautySetting> supportedBeautySettings({
    required List<AvoraBeautySetting> requested,
    required AvoraMediaProviderCapabilities provider,
    required bool lowPerformanceMode,
  }) {
    final supported = requested
        .where(
          (item) => provider.supportsBeautyEffect(
            item.capability,
          ),
        )
        .toList(growable: false);

    if (!lowPerformanceMode) {
      return supported;
    }

    /// Low-end devices keep only lighter core adjustments.
    const lightweight = {
      AvoraBeautyCapability.smoothing,
      AvoraBeautyCapability.whitening,
      AvoraBeautyCapability.sharpening,
      AvoraBeautyCapability.colorFilter,
    };

    return supported
        .where(
          (item) => lightweight.contains(item.capability),
        )
        .toList(growable: false);
  }

  static Set<AvoraAudioEffectCapability> supportedMicEffects({
    required AvoraMicProfileConfig mic,
    required AvoraMediaProviderCapabilities provider,
  }) {
    return mic.requestedEffects.where(provider.supportsAudioEffect).toSet();
  }
}
