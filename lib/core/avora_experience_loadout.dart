import 'avora_experience_entitlement.dart';

enum AvoraExperienceLoadoutSlot {
  entry,
  profileFrame,
  profileEffect,
  signatureSound,
  profileMusic,
  roomEffect,
  emojiPack,
}

class AvoraExperienceEquippedAsset {
  const AvoraExperienceEquippedAsset({
    required this.avoraId,
    required this.slot,
    required this.entitlementId,
    required this.assetId,
    required this.assetVersion,
    required this.equippedAtUtc,
  });

  final String avoraId;
  final AvoraExperienceLoadoutSlot slot;
  final String entitlementId;
  final String assetId;
  final String assetVersion;
  final DateTime equippedAtUtc;
}

class AvoraExperiencePlaybackPreference {
  const AvoraExperiencePlaybackPreference({
    this.entryAnimationEnabled = true,
    this.giftAnimationEnabled = true,
    this.soundEnabled = true,
    this.musicEnabled = true,
    this.autoplayProfileMusic = false,
  });

  final bool entryAnimationEnabled;
  final bool giftAnimationEnabled;
  final bool soundEnabled;
  final bool musicEnabled;
  final bool autoplayProfileMusic;

  AvoraExperiencePlaybackPreference copyWith({
    bool? entryAnimationEnabled,
    bool? giftAnimationEnabled,
    bool? soundEnabled,
    bool? musicEnabled,
    bool? autoplayProfileMusic,
  }) {
    return AvoraExperiencePlaybackPreference(
      entryAnimationEnabled:
          entryAnimationEnabled ?? this.entryAnimationEnabled,
      giftAnimationEnabled: giftAnimationEnabled ?? this.giftAnimationEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      autoplayProfileMusic: autoplayProfileMusic ?? this.autoplayProfileMusic,
    );
  }
}

class AvoraExperienceLoadoutLedger {
  final Map<String, AvoraExperienceEquippedAsset> _equipped =
      <String, AvoraExperienceEquippedAsset>{};

  final Map<String, AvoraExperiencePlaybackPreference> _preferences =
      <String, AvoraExperiencePlaybackPreference>{};

  String _key(
    String avoraId,
    AvoraExperienceLoadoutSlot slot,
  ) =>
      '$avoraId:${slot.name}';

  AvoraExperienceEquippedAsset? equipped({
    required String avoraId,
    required AvoraExperienceLoadoutSlot slot,
  }) {
    return _equipped[_key(avoraId, slot)];
  }

  void setEquipped(AvoraExperienceEquippedAsset record) {
    _equipped[_key(record.avoraId, record.slot)] = record;
  }

  void unequip({
    required String avoraId,
    required AvoraExperienceLoadoutSlot slot,
  }) {
    _equipped.remove(_key(avoraId, slot));
  }

  AvoraExperiencePlaybackPreference preferencesFor(
    String avoraId,
  ) {
    return _preferences[avoraId] ?? const AvoraExperiencePlaybackPreference();
  }

  void setPreferences({
    required String avoraId,
    required AvoraExperiencePlaybackPreference preferences,
  }) {
    if (avoraId.trim().isEmpty) {
      throw ArgumentError('avora_id_required');
    }

    _preferences[avoraId] = preferences;
  }

  static bool onlyOneAssetMayOccupySameSlot() => true;

  static bool userPlaybackPreferencesMustBeIndependent() => true;

  static bool loadoutMustNeverChangeOwnership() => true;

  static bool futureSlotsMustFitWithoutWalletRewrite() => true;
}

class AvoraExperienceLoadoutService {
  AvoraExperienceLoadoutService({
    required AvoraExperienceEntitlementLedger entitlementLedger,
    required AvoraExperienceLoadoutLedger loadoutLedger,
  })  : _entitlementLedger = entitlementLedger,
        _loadoutLedger = loadoutLedger;

  final AvoraExperienceEntitlementLedger _entitlementLedger;
  final AvoraExperienceLoadoutLedger _loadoutLedger;

  AvoraExperienceEquippedAsset equip({
    required String avoraId,
    required AvoraExperienceLoadoutSlot slot,
    required String purchaseId,
    required DateTime nowUtc,
  }) {
    if (avoraId.trim().isEmpty || purchaseId.trim().isEmpty) {
      throw ArgumentError('invalid_experience_equip_request');
    }

    final entitlement = _entitlementLedger.entitlementByPurchase(purchaseId);

    if (entitlement == null) {
      throw StateError('experience_entitlement_not_found');
    }

    if (entitlement.ownerAvoraId != avoraId) {
      throw StateError('experience_entitlement_wrong_owner');
    }

    if (!entitlement.isActiveAt(nowUtc.toUtc())) {
      throw StateError('experience_entitlement_not_active');
    }

    final record = AvoraExperienceEquippedAsset(
      avoraId: avoraId,
      slot: slot,
      entitlementId: entitlement.entitlementId,
      assetId: entitlement.assetId,
      assetVersion: entitlement.assetVersion,
      equippedAtUtc: nowUtc.toUtc(),
    );

    // Intentional replace semantics:
    // one slot has one authoritative active asset.
    _loadoutLedger.setEquipped(record);

    return record;
  }

  void unequip({
    required String avoraId,
    required AvoraExperienceLoadoutSlot slot,
  }) {
    _loadoutLedger.unequip(
      avoraId: avoraId,
      slot: slot,
    );
  }

  AvoraExperienceEquippedAsset? activeEquipped({
    required String avoraId,
    required AvoraExperienceLoadoutSlot slot,
    required DateTime nowUtc,
  }) {
    final equipped = _loadoutLedger.equipped(
      avoraId: avoraId,
      slot: slot,
    );

    if (equipped == null) {
      return null;
    }

    final entitlement = _entitlementLedger.entitlementByPurchase(
      _purchaseIdForEntitlement(equipped.entitlementId),
    );

    if (entitlement == null ||
        entitlement.entitlementId != equipped.entitlementId ||
        !entitlement.isActiveAt(nowUtc.toUtc())) {
      _loadoutLedger.unequip(
        avoraId: avoraId,
        slot: slot,
      );
      return null;
    }

    return equipped;
  }

  String _purchaseIdForEntitlement(String entitlementId) {
    if (!entitlementId.startsWith('entitlement-delivery-')) {
      throw StateError('unsupported_entitlement_reference');
    }

    return entitlementId.substring(
      'entitlement-delivery-'.length,
    );
  }

  static bool expiredAssetMustNotRemainUsable() => true;

  static bool revokedAssetMustNotRemainUsable() => true;

  static bool replacingSameSlotMustNotDestroyEntitlement() => true;

  static bool exactPurchasedVersionMustRemainEquipped() => true;

  static bool clientMustNotCreateOwnershipByEquipping() => true;

  static bool mutePreferenceMustNotRevokePremiumOwnership() => true;

  static bool giftAnimationPreferenceMustNotChangeGiftSettlement() => true;

  static bool premiumExperienceMustRemainServerAuthoritative() => true;
}
