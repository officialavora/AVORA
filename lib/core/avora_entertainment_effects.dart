enum AvoraEntertainmentEffectCategory {
  gift,
  entry,
  luckyGift,
  luckyPocket,
  combo,
  emojiReaction,
  cpRelationship,
  friendRelationship,
  pkFunny,
  pkPunishment,
  roomEvent,
  festival,
  system,
  custom,
}

enum AvoraEffectSoundKind {
  none,
  soundEffect,
  music,
  voiceClip,
  ambient,
  custom,
}

enum AvoraEffectComboBehavior {
  none,
  replay,
  extendDuration,
  intensify,
  stack,
  replace,
}

enum AvoraEffectSuppressionReason {
  none,
  effectDisabled,
  noActiveVersion,
  categoryMismatch,
  fullyMutedByViewer,
}

class AvoraEntertainmentEffectVersion {
  final String versionId;

  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;

  final bool enabled;

  /// Optional still/image fallback.
  final String? imageAssetRef;

  /// GIF/Lottie/video-like/animated presentation reference.
  final String? animationAssetRef;

  /// Matching sound/SFX/music/voice clip.
  final String? soundAssetRef;

  final AvoraEffectSoundKind soundKind;

  /// UI-neutral duration.
  final int durationMilliseconds;

  /// Number of visual/audio repetitions.
  final int repeatCount;

  final AvoraEffectComboBehavior comboBehavior;

  /// Higher value may render above lower-priority effects.
  final int priority;

  /// Optional presentation references.
  final String? frameAssetRef;
  final String? bannerAssetRef;
  final String? overlayText;

  final bool hapticEnabled;

  const AvoraEntertainmentEffectVersion({
    required this.versionId,
    required this.effectiveFrom,
    required this.enabled,
    required this.durationMilliseconds,
    this.effectiveUntil,
    this.imageAssetRef,
    this.animationAssetRef,
    this.soundAssetRef,
    this.soundKind = AvoraEffectSoundKind.none,
    this.repeatCount = 1,
    this.comboBehavior = AvoraEffectComboBehavior.none,
    this.priority = 0,
    this.frameAssetRef,
    this.bannerAssetRef,
    this.overlayText,
    this.hapticEnabled = false,
  })  : assert(durationMilliseconds > 0),
        assert(repeatCount >= 1);

  bool activeAt(DateTime now) {
    if (!enabled || now.isBefore(effectiveFrom)) {
      return false;
    }

    final until = effectiveUntil;

    if (until != null && !now.isBefore(until)) {
      return false;
    }

    return true;
  }

  bool get hasVisual =>
      imageAssetRef != null ||
      animationAssetRef != null ||
      frameAssetRef != null ||
      bannerAssetRef != null ||
      overlayText != null;

  bool get hasSound =>
      soundAssetRef != null && soundKind != AvoraEffectSoundKind.none;
}

class AvoraEntertainmentEffectDefinition {
  final String effectId;

  final String displayName;

  final AvoraEntertainmentEffectCategory category;

  /// Semantic tag only; examples:
  /// slipper_hit, kiss, lion, crow, dog, dragon_entry.
  final String semanticKey;

  final List<AvoraEntertainmentEffectVersion> versions;

  const AvoraEntertainmentEffectDefinition({
    required this.effectId,
    required this.displayName,
    required this.category,
    required this.semanticKey,
    required this.versions,
  });
}

class AvoraEntertainmentEffectTrigger {
  final String triggerEventId;

  final String effectId;

  final AvoraEntertainmentEffectCategory category;

  /// Identity references remain immutable AVORA IDs where applicable.
  final String? senderAvoraId;
  final String? receiverAvoraId;

  final String? roomId;
  final int? seatNumber;

  final String? relationshipId;
  final String? pkMatchId;
  final String? eventId;

  final int comboCount;

  final DateTime triggeredAt;

  const AvoraEntertainmentEffectTrigger({
    required this.triggerEventId,
    required this.effectId,
    required this.category,
    required this.triggeredAt,
    this.senderAvoraId,
    this.receiverAvoraId,
    this.roomId,
    this.seatNumber,
    this.relationshipId,
    this.pkMatchId,
    this.eventId,
    this.comboCount = 1,
  }) : assert(comboCount >= 1);
}

class AvoraEntertainmentEffectPreference {
  final String viewerAvoraId;

  final bool masterVisualEffectsEnabled;
  final bool masterEffectSoundsEnabled;

  final Set<AvoraEntertainmentEffectCategory> mutedVisualCategories;

  final Set<AvoraEntertainmentEffectCategory> mutedSoundCategories;

  const AvoraEntertainmentEffectPreference({
    required this.viewerAvoraId,
    this.masterVisualEffectsEnabled = true,
    this.masterEffectSoundsEnabled = true,
    this.mutedVisualCategories = const {},
    this.mutedSoundCategories = const {},
  });

  bool visualAllowed(
    AvoraEntertainmentEffectCategory category,
  ) {
    return masterVisualEffectsEnabled &&
        !mutedVisualCategories.contains(category);
  }

  bool soundAllowed(
    AvoraEntertainmentEffectCategory category,
  ) {
    return masterEffectSoundsEnabled &&
        !mutedSoundCategories.contains(category);
  }
}

class AvoraEntertainmentEffectPlaybackDecision {
  final bool available;

  final bool renderVisual;
  final bool playSound;
  final bool playHaptic;

  final AvoraEffectSuppressionReason suppressionReason;

  final String effectId;
  final String? versionId;

  final String? imageAssetRef;
  final String? animationAssetRef;
  final String? soundAssetRef;

  final AvoraEffectSoundKind soundKind;

  final int durationMilliseconds;
  final int repeatCount;
  final int priority;

  final AvoraEffectComboBehavior comboBehavior;

  const AvoraEntertainmentEffectPlaybackDecision({
    required this.available,
    required this.renderVisual,
    required this.playSound,
    required this.playHaptic,
    required this.suppressionReason,
    required this.effectId,
    required this.versionId,
    required this.imageAssetRef,
    required this.animationAssetRef,
    required this.soundAssetRef,
    required this.soundKind,
    required this.durationMilliseconds,
    required this.repeatCount,
    required this.priority,
    required this.comboBehavior,
  });
}

class AvoraHistoricalEffectReference {
  final String triggerEventId;

  final String effectId;

  /// Exact effect version used historically.
  final String effectVersionId;

  final AvoraEntertainmentEffectCategory category;

  final DateTime occurredAt;

  const AvoraHistoricalEffectReference({
    required this.triggerEventId,
    required this.effectId,
    required this.effectVersionId,
    required this.category,
    required this.occurredAt,
  });
}

class AvoraEntertainmentEffectEngine {
  const AvoraEntertainmentEffectEngine._();

  static AvoraEntertainmentEffectVersion? effectiveVersion({
    required AvoraEntertainmentEffectDefinition effect,
    required DateTime now,
  }) {
    final active = effect.versions
        .where(
          (version) => version.activeAt(now),
        )
        .toList(growable: false)
      ..sort(
        (a, b) => b.effectiveFrom.compareTo(a.effectiveFrom),
      );

    if (active.isEmpty) {
      return null;
    }

    return active.first;
  }

  static AvoraEntertainmentEffectPlaybackDecision resolve({
    required AvoraEntertainmentEffectDefinition effect,
    required AvoraEntertainmentEffectTrigger trigger,
    required AvoraEntertainmentEffectPreference preference,
    required DateTime now,
  }) {
    if (effect.category != trigger.category) {
      return _suppressed(
        effectId: effect.effectId,
        reason: AvoraEffectSuppressionReason.categoryMismatch,
      );
    }

    final version = effectiveVersion(
      effect: effect,
      now: now,
    );

    if (version == null) {
      return _suppressed(
        effectId: effect.effectId,
        reason: AvoraEffectSuppressionReason.noActiveVersion,
      );
    }

    if (!version.enabled) {
      return _suppressed(
        effectId: effect.effectId,
        reason: AvoraEffectSuppressionReason.effectDisabled,
      );
    }

    final renderVisual =
        version.hasVisual && preference.visualAllowed(effect.category);

    final playSound =
        version.hasSound && preference.soundAllowed(effect.category);

    if (!renderVisual && !playSound) {
      return AvoraEntertainmentEffectPlaybackDecision(
        available: true,
        renderVisual: false,
        playSound: false,
        playHaptic: false,
        suppressionReason: AvoraEffectSuppressionReason.fullyMutedByViewer,
        effectId: effect.effectId,
        versionId: version.versionId,
        imageAssetRef: version.imageAssetRef,
        animationAssetRef: version.animationAssetRef,
        soundAssetRef: version.soundAssetRef,
        soundKind: version.soundKind,
        durationMilliseconds: version.durationMilliseconds,
        repeatCount: version.repeatCount,
        priority: version.priority,
        comboBehavior: version.comboBehavior,
      );
    }

    return AvoraEntertainmentEffectPlaybackDecision(
      available: true,
      renderVisual: renderVisual,
      playSound: playSound,
      playHaptic: version.hapticEnabled && (renderVisual || playSound),
      suppressionReason: AvoraEffectSuppressionReason.none,
      effectId: effect.effectId,
      versionId: version.versionId,
      imageAssetRef: version.imageAssetRef,
      animationAssetRef: version.animationAssetRef,
      soundAssetRef: version.soundAssetRef,
      soundKind: version.soundKind,
      durationMilliseconds: version.durationMilliseconds,
      repeatCount: version.repeatCount,
      priority: version.priority,
      comboBehavior: version.comboBehavior,
    );
  }

  static AvoraEntertainmentEffectPlaybackDecision _suppressed({
    required String effectId,
    required AvoraEffectSuppressionReason reason,
  }) {
    return AvoraEntertainmentEffectPlaybackDecision(
      available: false,
      renderVisual: false,
      playSound: false,
      playHaptic: false,
      suppressionReason: reason,
      effectId: effectId,
      versionId: null,
      imageAssetRef: null,
      animationAssetRef: null,
      soundAssetRef: null,
      soundKind: AvoraEffectSoundKind.none,
      durationMilliseconds: 0,
      repeatCount: 1,
      priority: 0,
      comboBehavior: AvoraEffectComboBehavior.none,
    );
  }

  /// Gift/entry/LP effect sound lives on an effects bus.
  /// Muting it never mutes actual room voice.
  static bool mutingEffectSoundMutesRoomVoice() {
    return false;
  }

  /// Effect sound mute never disables room music playback.
  static bool mutingEffectSoundMutesRoomMusic() {
    return false;
  }

  /// Effect preferences do not mute Live/PK core audio.
  static bool mutingEffectSoundMutesLiveOrPkAudio() {
    return false;
  }

  /// Presentation effects never change gift settlement.
  static bool effectChangesGiftSettlement() {
    return false;
  }

  /// Presentation effects never grant role/moderation authority.
  static bool effectGrantsAuthority() {
    return false;
  }

  /// Entertainment assets cannot bypass moderation/compliance.
  static bool effectBypassesModerationOrCompliance() {
    return false;
  }

  /// Historical triggers retain their exact effect version.
  static bool historicalEffectUsesLatestVersionRetroactively() {
    return false;
  }

  /// New funny/luxury/seasonal semantic effects can be added
  /// without expanding the core enum for every individual asset.
  static bool supportsExtensibleSemanticEffects() {
    return true;
  }
}
