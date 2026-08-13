enum AvoraPremiumAssetType {
  entryEffect,
  profileFrame,
  noblePrestige,
  profileAnimation,
  roomEffect,
  seatEffect,
  cpEffect,
  chatBubble,
  badge,
  nameEffect,
  microphoneEffect,
  liveEffect,
  custom,
}

enum AvoraPremiumAssetAcquisitionSource {
  directPurchase,
  vipEntitlement,
  svipEntitlement,
  achievement,
  eventReward,
  seasonalPass,
  adminGrant,
  officialGrant,
  cpMilestone,
  campaign,
}

enum AvoraPremiumEntitlementStatus {
  active,
  expired,
  revoked,
  suspended,
}

class AvoraPremiumAssetDefinition {
  final String id;

  final AvoraPremiumAssetType type;

  final String displayName;

  /// Catalog asset references.
  final String? previewAssetId;
  final String? animationAssetId;
  final String? soundAssetId;

  /// Optional catalog/theme grouping:
  /// luxury, royal, romantic, neon, festival, etc.
  final Set<String> tags;

  /// Asset availability itself can be switched off.
  final bool enabled;

  /// Optional minimum prestige/VIP level.
  /// 0 means no tier requirement.
  final int minimumPrestigeTier;

  /// Country codes are ISO-style values.
  /// Empty means globally eligible unless another policy blocks it.
  final Set<String> allowedCountryCodes;

  /// Whether low-performance clients may replace this with
  /// a lighter fallback.
  final bool allowPerformanceFallback;

  final String? fallbackAssetId;

  const AvoraPremiumAssetDefinition({
    required this.id,
    required this.type,
    required this.displayName,
    this.previewAssetId,
    this.animationAssetId,
    this.soundAssetId,
    this.tags = const {},
    this.enabled = true,
    this.minimumPrestigeTier = 0,
    this.allowedCountryCodes = const {},
    this.allowPerformanceFallback = true,
    this.fallbackAssetId,
  }) : assert(minimumPrestigeTier >= 0);

  bool availableInCountry(String countryCode) {
    if (!enabled) {
      return false;
    }

    if (allowedCountryCodes.isEmpty) {
      return true;
    }

    final requested = countryCode.trim().toUpperCase();

    return allowedCountryCodes.any(
      (code) => code.trim().toUpperCase() == requested,
    );
  }
}

class AvoraPremiumAssetOffer {
  final String id;

  final String assetId;

  /// AVORA economic units, usually spend coins.
  /// The exact wallet/value type remains configurable.
  final int priceUnits;

  final String valueType;

  /// Null = permanent entitlement.
  final Duration? duration;

  final bool enabled;

  /// Optional prestige/VIP requirement for this offer.
  final int minimumPrestigeTier;

  final Set<String> allowedCountryCodes;

  final DateTime? startsAt;
  final DateTime? endsAt;

  const AvoraPremiumAssetOffer({
    required this.id,
    required this.assetId,
    required this.priceUnits,
    required this.valueType,
    this.duration,
    this.enabled = true,
    this.minimumPrestigeTier = 0,
    this.allowedCountryCodes = const {},
    this.startsAt,
    this.endsAt,
  })  : assert(priceUnits >= 0),
        assert(minimumPrestigeTier >= 0);

  bool get permanent => duration == null;

  bool isAvailableAt({
    required DateTime now,
    required String countryCode,
  }) {
    if (!enabled) {
      return false;
    }

    if (startsAt != null && now.isBefore(startsAt!)) {
      return false;
    }

    if (endsAt != null && now.isAfter(endsAt!)) {
      return false;
    }

    if (allowedCountryCodes.isEmpty) {
      return true;
    }

    final requested = countryCode.trim().toUpperCase();

    return allowedCountryCodes.any(
      (code) => code.trim().toUpperCase() == requested,
    );
  }
}

class AvoraPremiumAssetEntitlement {
  final String id;

  final String assetId;

  final String ownerUserId;

  final AvoraPremiumAssetAcquisitionSource source;

  final AvoraPremiumEntitlementStatus status;

  /// Purchase/order/event/admin grant reference.
  final String? sourceReferenceId;

  final DateTime startsAt;

  /// Null = permanent until revoked.
  final DateTime? expiresAt;

  final DateTime createdAt;

  final String? grantedByUserId;

  final String? revokedByUserId;
  final DateTime? revokedAt;
  final String? revokeReason;

  const AvoraPremiumAssetEntitlement({
    required this.id,
    required this.assetId,
    required this.ownerUserId,
    required this.source,
    required this.status,
    required this.startsAt,
    required this.createdAt,
    this.sourceReferenceId,
    this.expiresAt,
    this.grantedByUserId,
    this.revokedByUserId,
    this.revokedAt,
    this.revokeReason,
  });

  bool get permanent => expiresAt == null;

  bool isActiveAt(DateTime now) {
    if (status != AvoraPremiumEntitlementStatus.active) {
      return false;
    }

    if (now.isBefore(startsAt)) {
      return false;
    }

    final expiry = expiresAt;

    if (expiry != null && !now.isBefore(expiry)) {
      return false;
    }

    return true;
  }

  AvoraPremiumAssetEntitlement revoke({
    required String revokedByUserId,
    required DateTime revokedAt,
    required String reason,
  }) {
    return AvoraPremiumAssetEntitlement(
      id: id,
      assetId: assetId,
      ownerUserId: ownerUserId,
      source: source,
      status: AvoraPremiumEntitlementStatus.revoked,
      sourceReferenceId: sourceReferenceId,
      startsAt: startsAt,
      expiresAt: expiresAt,
      createdAt: createdAt,
      grantedByUserId: grantedByUserId,
      revokedByUserId: revokedByUserId,
      revokedAt: revokedAt,
      revokeReason: reason,
    );
  }
}

enum AvoraPremiumAssetPurchaseDenyReason {
  none,
  assetUnavailable,
  offerUnavailable,
  countryNotAllowed,
  prestigeTierRequired,
  insufficientBalance,
  valueTypeNotAllowed,
  countryPurchaseDisabled,
}

class AvoraPremiumAssetPurchaseDecision {
  final bool allowed;

  final AvoraPremiumAssetPurchaseDenyReason reason;

  final int priceUnits;

  const AvoraPremiumAssetPurchaseDecision({
    required this.allowed,
    required this.reason,
    required this.priceUnits,
  });
}

class AvoraPremiumAssetPolicy {
  const AvoraPremiumAssetPolicy._();

  static AvoraPremiumAssetPurchaseDecision evaluatePurchase({
    required AvoraPremiumAssetDefinition asset,
    required AvoraPremiumAssetOffer offer,
    required String countryCode,
    required DateTime now,
    required int userPrestigeTier,
    required int availableBalanceUnits,
    required Set<String> allowedValueTypes,
    required bool countryPurchaseEnabled,
  }) {
    AvoraPremiumAssetPurchaseDecision deny(
      AvoraPremiumAssetPurchaseDenyReason reason,
    ) {
      return AvoraPremiumAssetPurchaseDecision(
        allowed: false,
        reason: reason,
        priceUnits: offer.priceUnits,
      );
    }

    if (!asset.enabled) {
      return deny(
        AvoraPremiumAssetPurchaseDenyReason.assetUnavailable,
      );
    }

    if (!asset.availableInCountry(countryCode)) {
      return deny(
        AvoraPremiumAssetPurchaseDenyReason.countryNotAllowed,
      );
    }

    if (!offer.isAvailableAt(
      now: now,
      countryCode: countryCode,
    )) {
      return deny(
        AvoraPremiumAssetPurchaseDenyReason.offerUnavailable,
      );
    }

    final requiredTier = asset.minimumPrestigeTier > offer.minimumPrestigeTier
        ? asset.minimumPrestigeTier
        : offer.minimumPrestigeTier;

    if (userPrestigeTier < requiredTier) {
      return deny(
        AvoraPremiumAssetPurchaseDenyReason.prestigeTierRequired,
      );
    }

    if (!countryPurchaseEnabled) {
      return deny(
        AvoraPremiumAssetPurchaseDenyReason.countryPurchaseDisabled,
      );
    }

    if (!allowedValueTypes.contains(offer.valueType)) {
      return deny(
        AvoraPremiumAssetPurchaseDenyReason.valueTypeNotAllowed,
      );
    }

    if (availableBalanceUnits < offer.priceUnits) {
      return deny(
        AvoraPremiumAssetPurchaseDenyReason.insufficientBalance,
      );
    }

    return AvoraPremiumAssetPurchaseDecision(
      allowed: true,
      reason: AvoraPremiumAssetPurchaseDenyReason.none,
      priceUnits: offer.priceUnits,
    );
  }

  static AvoraPremiumAssetEntitlement createEntitlement({
    required String entitlementId,
    required String ownerUserId,
    required AvoraPremiumAssetOffer offer,
    required AvoraPremiumAssetAcquisitionSource source,
    required DateTime startsAt,
    String? sourceReferenceId,
    String? grantedByUserId,
  }) {
    final duration = offer.duration;

    return AvoraPremiumAssetEntitlement(
      id: entitlementId,
      assetId: offer.assetId,
      ownerUserId: ownerUserId,
      source: source,
      status: AvoraPremiumEntitlementStatus.active,
      sourceReferenceId: sourceReferenceId,
      startsAt: startsAt,
      expiresAt: duration == null ? null : startsAt.add(duration),
      createdAt: startsAt,
      grantedByUserId: grantedByUserId,
    );
  }

  static String? renderAssetId({
    required AvoraPremiumAssetDefinition asset,
    required AvoraPremiumAssetEntitlement entitlement,
    required DateTime now,
    required bool lowPerformanceMode,
  }) {
    if (!asset.enabled ||
        asset.id != entitlement.assetId ||
        !entitlement.isActiveAt(now)) {
      return null;
    }

    if (lowPerformanceMode &&
        asset.allowPerformanceFallback &&
        asset.fallbackAssetId != null) {
      return asset.fallbackAssetId;
    }

    return asset.animationAssetId ?? asset.previewAssetId ?? asset.id;
  }

  /// Cosmetics never grant moderation/staff authority.
  static bool grantsAuthorityPermission(
    AvoraPremiumAssetEntitlement entitlement,
  ) {
    return false;
  }
}
