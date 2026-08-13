enum AvoraGiftCatalogKind {
  standard,
  luckyGift,
  luckyPocket,
  signature,
  cpCouple,
  friend,
  relationship,
  brother,
  sister,
  bestFriend,
  festival,
  event,
  vipPrestige,
  svipPrestige,
  countryFlag,
  countryTheme,
  custom,
}

enum AvoraGiftSettlementProfile {
  standard,
  luckyGift,
  luckyPocket,
  relationship,
  signature,
  event,
  custom,
}

enum AvoraGiftSendDenyReason {
  none,
  giftDisabled,
  countryDisabled,
  noEffectivePolicy,
  quantityNotAllowed,
  comboNotAllowed,
  customComboNotAllowed,
  customComboBelowMinimum,
  customComboAboveMaximum,
  perSendLimitExceeded,
  festivalNotActive,
  eventNotActive,
}

class AvoraCountryGiftPresentation {
  final String countryCode;

  final String displayName;

  /// Optional premium/custom flag asset.
  /// ISO country-code emoji can remain the fallback.
  final String? flagAssetRef;

  const AvoraCountryGiftPresentation({
    required this.countryCode,
    required this.displayName,
    this.flagAssetRef,
  });

  String get normalizedCountryCode => countryCode.trim().toUpperCase();

  String get emojiFlag {
    final code = normalizedCountryCode;

    if (code.length != 2) {
      return '🏳️';
    }

    final units = code.codeUnits;

    final valid = units.every(
      (unit) => unit >= 65 && unit <= 90,
    );

    if (!valid) {
      return '🏳️';
    }

    return String.fromCharCodes(
      units.map(
        (unit) => 0x1F1E6 + (unit - 65),
      ),
    );
  }
}

class AvoraGiftPolicyVersion {
  final String versionId;

  final DateTime effectiveFrom;

  final DateTime? effectiveUntil;

  final bool enabled;

  /// Base gift price/value in the smallest configured economy unit.
  /// Currency/coin interpretation belongs to the economy layer.
  final int unitPrice;

  final AvoraGiftSettlementProfile settlementProfile;

  final bool allowSingleSend;

  final bool allowPresetCombos;

  final Set<int> presetComboQuantities;

  final bool allowCustomCombo;

  final int customComboMinimum;

  final int customComboMaximum;

  /// Hard safety/commerce limit per send action.
  final int maximumQuantityPerSend;

  final String? visualAssetRef;
  final String? animationAssetRef;
  final String? soundAssetRef;

  const AvoraGiftPolicyVersion({
    required this.versionId,
    required this.effectiveFrom,
    required this.enabled,
    required this.unitPrice,
    required this.settlementProfile,
    required this.allowSingleSend,
    required this.allowPresetCombos,
    required this.presetComboQuantities,
    required this.allowCustomCombo,
    required this.customComboMinimum,
    required this.customComboMaximum,
    required this.maximumQuantityPerSend,
    this.effectiveUntil,
    this.visualAssetRef,
    this.animationAssetRef,
    this.soundAssetRef,
  })  : assert(unitPrice >= 0),
        assert(customComboMinimum >= 1),
        assert(customComboMaximum >= customComboMinimum),
        assert(maximumQuantityPerSend >= 1);

  bool activeAt(DateTime now) {
    if (now.isBefore(effectiveFrom)) {
      return false;
    }

    final until = effectiveUntil;

    if (until != null && !now.isBefore(until)) {
      return false;
    }

    return true;
  }
}

class AvoraGiftCountryOverride {
  final String countryCode;

  final bool? enabledOverride;

  final int? unitPriceOverride;

  final Set<int>? presetComboQuantitiesOverride;

  final bool? allowCustomComboOverride;

  final int? customComboMinimumOverride;

  final int? customComboMaximumOverride;

  final int? maximumQuantityPerSendOverride;

  final String? visualAssetRefOverride;
  final String? animationAssetRefOverride;
  final String? soundAssetRefOverride;

  const AvoraGiftCountryOverride({
    required this.countryCode,
    this.enabledOverride,
    this.unitPriceOverride,
    this.presetComboQuantitiesOverride,
    this.allowCustomComboOverride,
    this.customComboMinimumOverride,
    this.customComboMaximumOverride,
    this.maximumQuantityPerSendOverride,
    this.visualAssetRefOverride,
    this.animationAssetRefOverride,
    this.soundAssetRefOverride,
  }) : assert(
          unitPriceOverride == null || unitPriceOverride >= 0,
        );

  String get normalizedCountryCode => countryCode.trim().toUpperCase();
}

class AvoraGiftCatalogDefinition {
  final String giftId;

  final String displayName;

  final AvoraGiftCatalogKind kind;

  /// Empty means globally available unless another policy disables it.
  final Set<String> allowedCountryCodes;

  /// Festival/event IDs are configuration references,
  /// not hardcoded UI rules.
  final Set<String> festivalIds;
  final Set<String> eventIds;

  /// Optional relationship-affinity classification.
  final String? relationshipTypeRef;

  final List<AvoraGiftPolicyVersion> policyVersions;

  final List<AvoraGiftCountryOverride> countryOverrides;

  const AvoraGiftCatalogDefinition({
    required this.giftId,
    required this.displayName,
    required this.kind,
    required this.policyVersions,
    this.allowedCountryCodes = const {},
    this.festivalIds = const {},
    this.eventIds = const {},
    this.relationshipTypeRef,
    this.countryOverrides = const [],
  });

  bool countryAllowed(String countryCode) {
    if (allowedCountryCodes.isEmpty) {
      return true;
    }

    final normalized = countryCode.trim().toUpperCase();

    return allowedCountryCodes
        .map((value) => value.trim().toUpperCase())
        .contains(normalized);
  }

  AvoraGiftCountryOverride? overrideForCountry(
    String countryCode,
  ) {
    final normalized = countryCode.trim().toUpperCase();

    for (final override in countryOverrides) {
      if (override.normalizedCountryCode == normalized) {
        return override;
      }
    }

    return null;
  }
}

class AvoraGiftCatalogResolution {
  final AvoraGiftPolicyVersion policyVersion;

  final String countryCode;

  final bool enabled;

  final int resolvedUnitPrice;

  final Set<int> resolvedPresetCombos;

  final bool resolvedAllowCustomCombo;

  final int resolvedCustomComboMinimum;

  final int resolvedCustomComboMaximum;

  final int resolvedMaximumQuantityPerSend;

  final String? resolvedVisualAssetRef;
  final String? resolvedAnimationAssetRef;
  final String? resolvedSoundAssetRef;

  const AvoraGiftCatalogResolution({
    required this.policyVersion,
    required this.countryCode,
    required this.enabled,
    required this.resolvedUnitPrice,
    required this.resolvedPresetCombos,
    required this.resolvedAllowCustomCombo,
    required this.resolvedCustomComboMinimum,
    required this.resolvedCustomComboMaximum,
    required this.resolvedMaximumQuantityPerSend,
    required this.resolvedVisualAssetRef,
    required this.resolvedAnimationAssetRef,
    required this.resolvedSoundAssetRef,
  });
}

class AvoraGiftSendDecision {
  final bool allowed;

  final AvoraGiftSendDenyReason reason;

  final int quantity;

  final int unitPrice;

  final int totalPrice;

  final String policyVersionId;

  const AvoraGiftSendDecision({
    required this.allowed,
    required this.reason,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.policyVersionId,
  });
}

class AvoraGiftHistoricalCatalogReference {
  final String giftEventId;

  final String giftId;

  final String policyVersionId;

  final String countryCode;

  final int quantity;

  final int unitPriceAtSend;

  final int totalPriceAtSend;

  final DateTime sentAt;

  const AvoraGiftHistoricalCatalogReference({
    required this.giftEventId,
    required this.giftId,
    required this.policyVersionId,
    required this.countryCode,
    required this.quantity,
    required this.unitPriceAtSend,
    required this.totalPriceAtSend,
    required this.sentAt,
  });
}

class AvoraFestivalGiftWindow {
  final String festivalId;

  final String countryCode;

  final DateTime startsAt;

  final DateTime endsAt;

  final bool enabled;

  const AvoraFestivalGiftWindow({
    required this.festivalId,
    required this.countryCode,
    required this.startsAt,
    required this.endsAt,
    required this.enabled,
  });

  bool activeAt(DateTime now) {
    return enabled && !now.isBefore(startsAt) && now.isBefore(endsAt);
  }
}

class AvoraGiftCatalogEngine {
  const AvoraGiftCatalogEngine._();

  static AvoraGiftPolicyVersion? effectivePolicy({
    required AvoraGiftCatalogDefinition gift,
    required DateTime now,
  }) {
    final active = gift.policyVersions
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

  static AvoraGiftCatalogResolution? resolve({
    required AvoraGiftCatalogDefinition gift,
    required String countryCode,
    required DateTime now,
  }) {
    if (!gift.countryAllowed(countryCode)) {
      return null;
    }

    final policy = effectivePolicy(
      gift: gift,
      now: now,
    );

    if (policy == null) {
      return null;
    }

    final countryOverride = gift.overrideForCountry(countryCode);

    final customMin = countryOverride?.customComboMinimumOverride ??
        policy.customComboMinimum;

    final customMax = countryOverride?.customComboMaximumOverride ??
        policy.customComboMaximum;

    final safeCustomMax = customMax < customMin ? customMin : customMax;

    return AvoraGiftCatalogResolution(
      policyVersion: policy,
      countryCode: countryCode.trim().toUpperCase(),
      enabled: countryOverride?.enabledOverride ?? policy.enabled,
      resolvedUnitPrice: countryOverride?.unitPriceOverride ?? policy.unitPrice,
      resolvedPresetCombos: countryOverride?.presetComboQuantitiesOverride ??
          policy.presetComboQuantities,
      resolvedAllowCustomCombo:
          countryOverride?.allowCustomComboOverride ?? policy.allowCustomCombo,
      resolvedCustomComboMinimum: customMin,
      resolvedCustomComboMaximum: safeCustomMax,
      resolvedMaximumQuantityPerSend:
          countryOverride?.maximumQuantityPerSendOverride ??
              policy.maximumQuantityPerSend,
      resolvedVisualAssetRef:
          countryOverride?.visualAssetRefOverride ?? policy.visualAssetRef,
      resolvedAnimationAssetRef: countryOverride?.animationAssetRefOverride ??
          policy.animationAssetRef,
      resolvedSoundAssetRef:
          countryOverride?.soundAssetRefOverride ?? policy.soundAssetRef,
    );
  }

  static AvoraGiftSendDecision evaluateSend({
    required AvoraGiftCatalogDefinition gift,
    required AvoraGiftCatalogResolution resolution,
    required int quantity,
  }) {
    final policy = resolution.policyVersion;

    if (!resolution.enabled) {
      return AvoraGiftSendDecision(
        allowed: false,
        reason: AvoraGiftSendDenyReason.giftDisabled,
        quantity: quantity,
        unitPrice: resolution.resolvedUnitPrice,
        totalPrice: 0,
        policyVersionId: policy.versionId,
      );
    }

    if (quantity < 1) {
      return AvoraGiftSendDecision(
        allowed: false,
        reason: AvoraGiftSendDenyReason.quantityNotAllowed,
        quantity: quantity,
        unitPrice: resolution.resolvedUnitPrice,
        totalPrice: 0,
        policyVersionId: policy.versionId,
      );
    }

    if (quantity > resolution.resolvedMaximumQuantityPerSend) {
      return AvoraGiftSendDecision(
        allowed: false,
        reason: AvoraGiftSendDenyReason.perSendLimitExceeded,
        quantity: quantity,
        unitPrice: resolution.resolvedUnitPrice,
        totalPrice: 0,
        policyVersionId: policy.versionId,
      );
    }

    if (quantity == 1) {
      if (!policy.allowSingleSend) {
        return AvoraGiftSendDecision(
          allowed: false,
          reason: AvoraGiftSendDenyReason.quantityNotAllowed,
          quantity: quantity,
          unitPrice: resolution.resolvedUnitPrice,
          totalPrice: 0,
          policyVersionId: policy.versionId,
        );
      }
    } else {
      final presetAllowed = policy.allowPresetCombos &&
          resolution.resolvedPresetCombos.contains(quantity);

      if (!presetAllowed) {
        if (!resolution.resolvedAllowCustomCombo) {
          return AvoraGiftSendDecision(
            allowed: false,
            reason: AvoraGiftSendDenyReason.customComboNotAllowed,
            quantity: quantity,
            unitPrice: resolution.resolvedUnitPrice,
            totalPrice: 0,
            policyVersionId: policy.versionId,
          );
        }

        if (quantity < resolution.resolvedCustomComboMinimum) {
          return AvoraGiftSendDecision(
            allowed: false,
            reason: AvoraGiftSendDenyReason.customComboBelowMinimum,
            quantity: quantity,
            unitPrice: resolution.resolvedUnitPrice,
            totalPrice: 0,
            policyVersionId: policy.versionId,
          );
        }

        if (quantity > resolution.resolvedCustomComboMaximum) {
          return AvoraGiftSendDecision(
            allowed: false,
            reason: AvoraGiftSendDenyReason.customComboAboveMaximum,
            quantity: quantity,
            unitPrice: resolution.resolvedUnitPrice,
            totalPrice: 0,
            policyVersionId: policy.versionId,
          );
        }
      }
    }

    final total = resolution.resolvedUnitPrice * quantity;

    return AvoraGiftSendDecision(
      allowed: true,
      reason: AvoraGiftSendDenyReason.none,
      quantity: quantity,
      unitPrice: resolution.resolvedUnitPrice,
      totalPrice: total,
      policyVersionId: policy.versionId,
    );
  }

  static bool festivalGiftActive({
    required String festivalId,
    required String countryCode,
    required DateTime now,
    required List<AvoraFestivalGiftWindow> windows,
  }) {
    final normalizedCountry = countryCode.trim().toUpperCase();

    return windows.any(
      (window) =>
          window.festivalId == festivalId &&
          window.countryCode.trim().toUpperCase() == normalizedCountry &&
          window.activeAt(now),
    );
  }

  /// Combo UI compatibility never merges settlement economics.
  static bool comboSupportMeansSameSettlementForAllGiftKinds() {
    return false;
  }

  /// Lucky Gift retains its own return/counting rules.
  static bool luckyGiftUsesStandardSettlementBecauseOfCombo() {
    return false;
  }

  /// Relationship-themed gift alone cannot create formal relation.
  static bool relationshipGiftAutomaticallyCreatesRelationship() {
    return false;
  }

  /// Changing today's price must never rewrite historical sends.
  static bool priceChangeRewritesHistoricalLedger() {
    return false;
  }

  /// Gift catalog categories remain extensible.
  static bool giftKindsAreLimitedToLaunchCategories() {
    return false;
  }

  /// Country flag is presentation metadata, not authority/scope.
  static bool countryFlagControlsStaffAuthorization() {
    return false;
  }
}
