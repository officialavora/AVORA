enum AvoraRoomEntryFxTheme {
  horrorGhost,
  skeletonShock,
  darkFog,
  thunderStorm,
  fireDragon,
  royalKing,
  angelLight,
  neonCyber,
  premiumVip,
  custom,
}

enum AvoraRoomEntryFxAudience {
  selfOnly,
  roomWide,
  spotlightOnly,
}

enum AvoraRoomEntryFxSoundMode {
  silent,
  optional,
  required,
}

class AvoraRoomEntryFxPolicy {
  final bool enabled;
  final bool roomAnimationsEnabled;
  final bool roomSoundsEnabled;
  final bool allowScaryThemes;
  final bool lowDeviceFallbackEnabled;
  final int maxDurationSeconds;
  final int maxOverlayOpacityBps; // 0..10000
  final int maxSoundSeconds;

  const AvoraRoomEntryFxPolicy({
    required this.enabled,
    required this.roomAnimationsEnabled,
    required this.roomSoundsEnabled,
    required this.allowScaryThemes,
    required this.lowDeviceFallbackEnabled,
    required this.maxDurationSeconds,
    required this.maxOverlayOpacityBps,
    required this.maxSoundSeconds,
  })  : assert(maxDurationSeconds >= 0),
        assert(maxOverlayOpacityBps >= 0 && maxOverlayOpacityBps <= 10000),
        assert(maxSoundSeconds >= 0);

  static const AvoraRoomEntryFxPolicy standard = AvoraRoomEntryFxPolicy(
    enabled: true,
    roomAnimationsEnabled: true,
    roomSoundsEnabled: true,
    allowScaryThemes: true,
    lowDeviceFallbackEnabled: true,
    maxDurationSeconds: 12,
    maxOverlayOpacityBps: 8000,
    maxSoundSeconds: 8,
  );
}

class AvoraRoomEntryFxEntitlement {
  final String fxId;
  final AvoraRoomEntryFxTheme theme;
  final String displayName;
  final AvoraRoomEntryFxAudience audience;
  final AvoraRoomEntryFxSoundMode soundMode;
  final int durationSeconds;
  final int soundSeconds;
  final int overlayOpacityBps;
  final bool premiumOnly;
  final bool scary;
  final bool active;

  const AvoraRoomEntryFxEntitlement({
    required this.fxId,
    required this.theme,
    required this.displayName,
    required this.audience,
    required this.soundMode,
    required this.durationSeconds,
    required this.soundSeconds,
    required this.overlayOpacityBps,
    required this.premiumOnly,
    required this.scary,
    required this.active,
  })  : assert(durationSeconds >= 0),
        assert(soundSeconds >= 0),
        assert(overlayOpacityBps >= 0 && overlayOpacityBps <= 10000);
}

class AvoraRoomEntryViewerPreference {
  final bool roomAnimationsEnabled;
  final bool roomSoundsEnabled;
  final bool horrorEffectsAllowed;
  final bool lowDeviceMode;
  final bool doNotDisturb;

  const AvoraRoomEntryViewerPreference({
    required this.roomAnimationsEnabled,
    required this.roomSoundsEnabled,
    required this.horrorEffectsAllowed,
    required this.lowDeviceMode,
    required this.doNotDisturb,
  });
}

class AvoraRoomEntryFxDecision {
  final bool showAnimation;
  final bool playSound;
  final bool useLiteMode;
  final String reason;
  final int resolvedDurationSeconds;
  final int resolvedSoundSeconds;

  const AvoraRoomEntryFxDecision({
    required this.showAnimation,
    required this.playSound,
    required this.useLiteMode,
    required this.reason,
    required this.resolvedDurationSeconds,
    required this.resolvedSoundSeconds,
  });
}

class AvoraRoomEntryFxEngine {
  const AvoraRoomEntryFxEngine._();

  static AvoraRoomEntryFxDecision resolve({
    required AvoraRoomEntryFxEntitlement entitlement,
    required AvoraRoomEntryFxPolicy policy,
    required AvoraRoomEntryViewerPreference viewer,
  }) {
    if (!policy.enabled) {
      return const AvoraRoomEntryFxDecision(
        showAnimation: false,
        playSound: false,
        useLiteMode: false,
        reason: 'fxDisabledByPolicy',
        resolvedDurationSeconds: 0,
        resolvedSoundSeconds: 0,
      );
    }

    if (!entitlement.active) {
      return const AvoraRoomEntryFxDecision(
        showAnimation: false,
        playSound: false,
        useLiteMode: false,
        reason: 'fxInactive',
        resolvedDurationSeconds: 0,
        resolvedSoundSeconds: 0,
      );
    }

    if (viewer.doNotDisturb) {
      return const AvoraRoomEntryFxDecision(
        showAnimation: false,
        playSound: false,
        useLiteMode: false,
        reason: 'viewerDoNotDisturb',
        resolvedDurationSeconds: 0,
        resolvedSoundSeconds: 0,
      );
    }

    if (entitlement.scary &&
        (!policy.allowScaryThemes || !viewer.horrorEffectsAllowed)) {
      return const AvoraRoomEntryFxDecision(
        showAnimation: false,
        playSound: false,
        useLiteMode: false,
        reason: 'scaryThemeNotAllowed',
        resolvedDurationSeconds: 0,
        resolvedSoundSeconds: 0,
      );
    }

    final useLiteMode = viewer.lowDeviceMode && policy.lowDeviceFallbackEnabled;

    final showAnimation =
        policy.roomAnimationsEnabled && viewer.roomAnimationsEnabled;

    final playSound =
        entitlement.soundMode != AvoraRoomEntryFxSoundMode.silent &&
            policy.roomSoundsEnabled &&
            viewer.roomSoundsEnabled &&
            !viewer.doNotDisturb;

    final resolvedDuration =
        entitlement.durationSeconds > policy.maxDurationSeconds
            ? policy.maxDurationSeconds
            : entitlement.durationSeconds;

    final resolvedSound = entitlement.soundSeconds > policy.maxSoundSeconds
        ? policy.maxSoundSeconds
        : entitlement.soundSeconds;

    return AvoraRoomEntryFxDecision(
      showAnimation: showAnimation,
      playSound: playSound,
      useLiteMode: useLiteMode,
      reason: useLiteMode ? 'liteMode' : 'allowed',
      resolvedDurationSeconds: showAnimation ? resolvedDuration : 0,
      resolvedSoundSeconds: playSound ? resolvedSound : 0,
    );
  }

  /// Public visual effect does not create backend authority.
  static bool presentationNeverGrantsAuthority() => false;

  /// Viewer may suppress sound locally without affecting entitlement validity.
  static bool localMuteCancelsOwnership() => false;

  /// Structure is owner-editable from backend policy/catalog.
  static bool entryFxCatalogShouldBeOwnerEditable() => true;

  /// Low-end device fallback should be supported.
  static bool lowEndFallbackRequired() => true;
}
