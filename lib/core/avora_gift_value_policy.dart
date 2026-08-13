class AvoraGiftMetricKeys {
  const AvoraGiftMetricKeys._();

  static const senderProgress = 'sender_progress';
  static const receiverProgress = 'receiver_progress';
  static const roomTarget = 'room_target';
  static const relationshipAffinity = 'relationship_affinity';
  static const cpProgress = 'cp_progress';
  static const eventScore = 'event_score';
  static const festivalScore = 'festival_score';
  static const leaderboardScore = 'leaderboard_score';
  static const hostTarget = 'host_target';
  static const agencyTarget = 'agency_target';
  static const bdTarget = 'bd_target';
  static const rewardCounter = 'reward_counter';
  static const custom = 'custom';
}

class AvoraGiftMetricRule {
  final String metricKey;

  final bool enabled;

  /// 10000 = 100%
  /// 5000  = 50%
  /// 15000 = 150%
  ///
  /// Values above 100% are allowed because some events or
  /// promotions may intentionally grant boosted counting.
  final int multiplierBps;

  /// Optional fixed adjustment after percentage calculation.
  /// May be positive or negative.
  final int fixedAdjustmentUnits;

  final int? minimumOutputUnits;
  final int? maximumOutputUnits;

  const AvoraGiftMetricRule({
    required this.metricKey,
    this.enabled = true,
    this.multiplierBps = 10000,
    this.fixedAdjustmentUnits = 0,
    this.minimumOutputUnits,
    this.maximumOutputUnits,
  })  : assert(multiplierBps >= 0),
        assert(
          minimumOutputUnits == null ||
              maximumOutputUnits == null ||
              maximumOutputUnits >= minimumOutputUnits,
        );
}

class AvoraGiftValuePolicyVersion {
  final String versionId;

  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;

  final bool enabled;

  /// Raw counting value for one gift unit.
  /// This is independent from the catalog purchase price.
  final int baseValueUnits;

  /// Existing settlement/economy implementation may be referenced
  /// without duplicating settlement logic here.
  final String settlementProfileRef;

  final List<AvoraGiftMetricRule> metricRules;

  const AvoraGiftValuePolicyVersion({
    required this.versionId,
    required this.effectiveFrom,
    required this.enabled,
    required this.baseValueUnits,
    required this.settlementProfileRef,
    required this.metricRules,
    this.effectiveUntil,
  }) : assert(baseValueUnits >= 0);

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

class AvoraGiftValueOverride {
  final String overrideId;

  /// Null means all countries at this override level.
  final String? countryCode;

  /// Optional festival/event targeting.
  final String? festivalId;
  final String? eventId;

  final bool? enabledOverride;

  final int? baseValueUnitsOverride;

  /// Matching metric keys replace earlier rules.
  final List<AvoraGiftMetricRule> metricRuleOverrides;

  const AvoraGiftValueOverride({
    required this.overrideId,
    this.countryCode,
    this.festivalId,
    this.eventId,
    this.enabledOverride,
    this.baseValueUnitsOverride,
    this.metricRuleOverrides = const [],
  }) : assert(
          baseValueUnitsOverride == null || baseValueUnitsOverride >= 0,
        );

  bool matches({
    required String countryCode,
    required String? festivalId,
    required String? eventId,
  }) {
    final configuredCountry = this.countryCode;

    if (configuredCountry != null &&
        configuredCountry.trim().toUpperCase() !=
            countryCode.trim().toUpperCase()) {
      return false;
    }

    final configuredFestival = this.festivalId;

    if (configuredFestival != null && configuredFestival != festivalId) {
      return false;
    }

    final configuredEvent = this.eventId;

    if (configuredEvent != null && configuredEvent != eventId) {
      return false;
    }

    return true;
  }

  int get specificity {
    var value = 0;

    if (countryCode != null) {
      value++;
    }

    if (festivalId != null) {
      value++;
    }

    if (eventId != null) {
      value++;
    }

    return value;
  }
}

class AvoraGiftValuePolicyDefinition {
  final String policyId;

  final List<AvoraGiftValuePolicyVersion> versions;

  final List<AvoraGiftValueOverride> overrides;

  const AvoraGiftValuePolicyDefinition({
    required this.policyId,
    required this.versions,
    this.overrides = const [],
  });
}

class AvoraResolvedGiftValuePolicy {
  final String policyId;
  final String versionId;

  final bool enabled;

  final int baseValueUnits;

  final String settlementProfileRef;

  final Map<String, AvoraGiftMetricRule> metricRules;

  final List<String> appliedOverrideIds;

  const AvoraResolvedGiftValuePolicy({
    required this.policyId,
    required this.versionId,
    required this.enabled,
    required this.baseValueUnits,
    required this.settlementProfileRef,
    required this.metricRules,
    required this.appliedOverrideIds,
  });

  AvoraGiftMetricRule? ruleFor(String metricKey) {
    return metricRules[metricKey];
  }
}

class AvoraGiftCountingContext {
  final String giftId;

  final int quantity;

  final String countryCode;

  final String? festivalId;
  final String? eventId;

  /// If the originating gift/economic event is invalid,
  /// nothing should be credited.
  final bool validForCounting;

  final bool refundedOrReversed;
  final bool fraudInvalidated;

  const AvoraGiftCountingContext({
    required this.giftId,
    required this.quantity,
    required this.countryCode,
    required this.validForCounting,
    required this.refundedOrReversed,
    required this.fraudInvalidated,
    this.festivalId,
    this.eventId,
  }) : assert(quantity >= 1);
}

class AvoraGiftMetricCountingResult {
  final String metricKey;

  final int rawBaseUnits;

  final int multiplierBps;

  final int fixedAdjustmentUnits;

  final int countedUnits;

  const AvoraGiftMetricCountingResult({
    required this.metricKey,
    required this.rawBaseUnits,
    required this.multiplierBps,
    required this.fixedAdjustmentUnits,
    required this.countedUnits,
  });
}

class AvoraGiftCountingResult {
  final String giftId;

  final String policyId;
  final String policyVersionId;

  final int quantity;

  final int baseValueUnitsPerGift;

  final bool valid;

  final Map<String, AvoraGiftMetricCountingResult> metrics;

  const AvoraGiftCountingResult({
    required this.giftId,
    required this.policyId,
    required this.policyVersionId,
    required this.quantity,
    required this.baseValueUnitsPerGift,
    required this.valid,
    required this.metrics,
  });

  int valueFor(String metricKey) {
    return metrics[metricKey]?.countedUnits ?? 0;
  }
}

class AvoraGiftHistoricalCountingReference {
  final String giftEventId;

  final String giftId;

  final String policyId;
  final String policyVersionId;

  final String countryCode;

  final String? festivalId;
  final String? eventId;

  final int quantity;

  final int baseValueUnitsPerGift;

  /// Exact outputs used when the gift was sent.
  final Map<String, int> metricValuesAtSend;

  final DateTime sentAt;

  const AvoraGiftHistoricalCountingReference({
    required this.giftEventId,
    required this.giftId,
    required this.policyId,
    required this.policyVersionId,
    required this.countryCode,
    required this.quantity,
    required this.baseValueUnitsPerGift,
    required this.metricValuesAtSend,
    required this.sentAt,
    this.festivalId,
    this.eventId,
  });
}

class AvoraGiftValuePolicyEngine {
  const AvoraGiftValuePolicyEngine._();

  static AvoraGiftValuePolicyVersion? effectiveVersion({
    required AvoraGiftValuePolicyDefinition policy,
    required DateTime now,
  }) {
    final active = policy.versions
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

  static AvoraResolvedGiftValuePolicy? resolve({
    required AvoraGiftValuePolicyDefinition policy,
    required String countryCode,
    required String? festivalId,
    required String? eventId,
    required DateTime now,
  }) {
    final version = effectiveVersion(
      policy: policy,
      now: now,
    );

    if (version == null) {
      return null;
    }

    var enabled = version.enabled;
    var baseValueUnits = version.baseValueUnits;

    final rules = <String, AvoraGiftMetricRule>{
      for (final rule in version.metricRules) rule.metricKey: rule,
    };

    final matchingOverrides = policy.overrides
        .where(
          (override) => override.matches(
            countryCode: countryCode,
            festivalId: festivalId,
            eventId: eventId,
          ),
        )
        .toList(growable: false)
      ..sort(
        (a, b) => a.specificity.compareTo(b.specificity),
      );

    final appliedOverrideIds = <String>[];

    for (final override in matchingOverrides) {
      appliedOverrideIds.add(override.overrideId);

      final enabledOverride = override.enabledOverride;

      if (enabledOverride != null) {
        enabled = enabledOverride;
      }

      final baseOverride = override.baseValueUnitsOverride;

      if (baseOverride != null) {
        baseValueUnits = baseOverride;
      }

      for (final rule in override.metricRuleOverrides) {
        rules[rule.metricKey] = rule;
      }
    }

    return AvoraResolvedGiftValuePolicy(
      policyId: policy.policyId,
      versionId: version.versionId,
      enabled: enabled,
      baseValueUnits: baseValueUnits,
      settlementProfileRef: version.settlementProfileRef,
      metricRules: Map.unmodifiable(rules),
      appliedOverrideIds: List.unmodifiable(appliedOverrideIds),
    );
  }

  static int _applyRule({
    required int rawBaseUnits,
    required AvoraGiftMetricRule rule,
  }) {
    if (!rule.enabled) {
      return 0;
    }

    var value = (rawBaseUnits * rule.multiplierBps) ~/ 10000;

    value += rule.fixedAdjustmentUnits;

    final minimum = rule.minimumOutputUnits;

    if (minimum != null && value < minimum) {
      value = minimum;
    }

    final maximum = rule.maximumOutputUnits;

    if (maximum != null && value > maximum) {
      value = maximum;
    }

    if (value < 0) {
      value = 0;
    }

    return value;
  }

  static AvoraGiftCountingResult calculate({
    required AvoraGiftCountingContext context,
    required AvoraResolvedGiftValuePolicy policy,
  }) {
    final valid = policy.enabled &&
        context.validForCounting &&
        !context.refundedOrReversed &&
        !context.fraudInvalidated;

    final rawBaseUnits = policy.baseValueUnits * context.quantity;

    final results = <String, AvoraGiftMetricCountingResult>{};

    for (final entry in policy.metricRules.entries) {
      final rule = entry.value;

      final counted = valid
          ? _applyRule(
              rawBaseUnits: rawBaseUnits,
              rule: rule,
            )
          : 0;

      results[entry.key] = AvoraGiftMetricCountingResult(
        metricKey: entry.key,
        rawBaseUnits: rawBaseUnits,
        multiplierBps: rule.multiplierBps,
        fixedAdjustmentUnits: rule.fixedAdjustmentUnits,
        countedUnits: counted,
      );
    }

    return AvoraGiftCountingResult(
      giftId: context.giftId,
      policyId: policy.policyId,
      policyVersionId: policy.versionId,
      quantity: context.quantity,
      baseValueUnitsPerGift: policy.baseValueUnits,
      valid: valid,
      metrics: Map.unmodifiable(results),
    );
  }

  /// Different gift types may use different percentages/counting.
  static bool allGiftKindsMustShareSameCountingPolicy() {
    return false;
  }

  /// Combo quantity does not force one universal percentage.
  static bool comboForcesSharedCountingEconomics() {
    return false;
  }

  /// Admin commercial configuration cannot bypass compliance.
  static bool adminPercentagesBypassCompliance() {
    return false;
  }

  /// Admin configuration cannot make fraudulent/reversed gifts count.
  static bool adminCanForceInvalidGiftToCount() {
    return false;
  }

  /// Policy updates never rewrite historical gift counting.
  static bool policyUpdateRewritesHistoricalCounting() {
    return false;
  }

  /// New metric keys can be introduced through configuration/integration.
  static bool supportsExtensibleMetricKeys() {
    return true;
  }
}
