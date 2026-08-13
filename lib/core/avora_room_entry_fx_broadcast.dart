import 'avora_room_entry_fx.dart';
import 'avora_room_entry_fx_catalog.dart';

enum AvoraRoomEntryBroadcastDenyReason {
  none,
  invalidRoom,
  invalidEntrant,
  catalogItemMissing,
  entitlementMismatch,
  notRoomWide,
  presentationSuppressed,
}

class AvoraRoomEntryBroadcastDecision {
  const AvoraRoomEntryBroadcastDecision({
    required this.allowed,
    required this.reason,
    this.roomId,
    this.entrantAvoraId,
    this.fxId,
    this.fxVersion,
    this.animationAssetRef,
    this.soundAssetRef,
    this.avatarOverlayAssetRef,
    this.emojiOverlayAssetRef,
    this.showAnimation = false,
    this.playSound = false,
    this.useLiteMode = false,
    this.durationSeconds = 0,
    this.soundSeconds = 0,
  });

  final bool allowed;
  final AvoraRoomEntryBroadcastDenyReason reason;

  final String? roomId;

  /// Authoritative immutable AVORA identity of the entrant.
  final String? entrantAvoraId;

  final String? fxId;
  final int? fxVersion;

  /// Existing room renderer consumes these references.
  final String? animationAssetRef;
  final String? soundAssetRef;
  final String? avatarOverlayAssetRef;
  final String? emojiOverlayAssetRef;

  final bool showAnimation;
  final bool playSound;
  final bool useLiteMode;

  final int durationSeconds;
  final int soundSeconds;
}

class AvoraRoomEntryFxBroadcastBridge {
  const AvoraRoomEntryFxBroadcastBridge._();

  static AvoraRoomEntryBroadcastDecision resolveJoin({
    required String roomId,
    required String entrantAvoraId,
    required String selectedFxId,
    required DateTime now,
    required Iterable<AvoraRoomEntryFxCatalogItem> catalog,
    required AvoraRoomEntryFxEntitlement entitlement,
    required AvoraRoomEntryFxPolicy policy,
    required AvoraRoomEntryViewerPreference viewer,
  }) {
    if (roomId.trim().isEmpty) {
      return _deny(AvoraRoomEntryBroadcastDenyReason.invalidRoom);
    }

    if (entrantAvoraId.trim().isEmpty) {
      return _deny(AvoraRoomEntryBroadcastDenyReason.invalidEntrant);
    }

    final item = AvoraRoomEntryFxCatalogEngine.findActiveVersion(
      catalog: catalog,
      fxId: selectedFxId,
      now: now,
    );

    if (item == null) {
      return _deny(
        AvoraRoomEntryBroadcastDenyReason.catalogItemMissing,
      );
    }

    if (entitlement.fxId != selectedFxId || entitlement.fxId != item.fxId) {
      return _deny(
        AvoraRoomEntryBroadcastDenyReason.entitlementMismatch,
      );
    }

    if (entitlement.audience != AvoraRoomEntryFxAudience.roomWide) {
      return _deny(
        AvoraRoomEntryBroadcastDenyReason.notRoomWide,
      );
    }

    final presentation = AvoraRoomEntryFxEngine.resolve(
      entitlement: entitlement,
      policy: policy,
      viewer: viewer,
    );

    if (!presentation.showAnimation && !presentation.playSound) {
      return _deny(
        AvoraRoomEntryBroadcastDenyReason.presentationSuppressed,
      );
    }

    final assets = AvoraRoomEntryFxCatalogEngine.resolveAssets(
      item: item,
      lowDeviceMode: presentation.useLiteMode,
    );

    return AvoraRoomEntryBroadcastDecision(
      allowed: true,
      reason: AvoraRoomEntryBroadcastDenyReason.none,
      roomId: roomId,
      entrantAvoraId: entrantAvoraId,
      fxId: item.fxId,
      fxVersion: item.version,
      animationAssetRef: assets.animationAssetRef,
      soundAssetRef: assets.soundAssetRef,
      avatarOverlayAssetRef: assets.avatarOverlayAssetRef,
      emojiOverlayAssetRef: assets.emojiOverlayAssetRef,
      showAnimation: presentation.showAnimation,
      playSound: presentation.playSound,
      useLiteMode: presentation.useLiteMode,
      durationSeconds: presentation.resolvedDurationSeconds,
      soundSeconds: presentation.resolvedSoundSeconds,
    );
  }

  static AvoraRoomEntryBroadcastDecision _deny(
    AvoraRoomEntryBroadcastDenyReason reason,
  ) {
    return AvoraRoomEntryBroadcastDecision(
      allowed: false,
      reason: reason,
    );
  }

  /// Entry FX fires from an authoritative room-join event.
  static bool authoritativeJoinEventRequired() => true;

  /// Renderer/playback plumbing may be shared with room effects.
  static bool existingRoomRendererShouldBeReused() => true;

  /// PK/live emojis remain a separate product domain.
  static bool pkLiveEmojiCatalogIsSeparate() => true;

  /// Entry presentation can never create moderation/admin authority.
  static bool entryEffectGrantsAuthority() => false;

  /// Client cannot forge another user's selected premium entry.
  static bool clientCanForgeEntryEntitlement() => false;
}
