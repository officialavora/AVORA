enum AvoraRechargeEventStatus {
  draft,
  active,
  paused,
  ended,
  cancelled,
}

enum AvoraRechargeClaimMode {
  /// Every reached tier can be claimed once.
  cumulative,

  /// Only the highest reached tier can be claimed.
  highestTierOnly,
}

enum AvoraRechargeRewardKind {
  promoCoins,

  /// Temporary right to choose an available Vanity/Unique ID.
  /// Never replaces the immutable AVORA ID.
  vanityIdSelection,

  noblePrestige,
  profileFrame,
  entryEffect,
  roomEffect,
  badge,
  eventToken,
  custom,
}

class AvoraRechargeTierReward {
  final String id;

  final AvoraRechargeRewardKind kind;

  /// Reward amount where applicable.
  final int amountUnits;

  /// Optional asset/catalog reference.
  final String? assetId;

  /// Optional entitlement lifetime.
  /// Null may mean permanent or non-duration reward,
  /// depending on reward kind/policy.
  final Duration? duration;

  const AvoraRechargeTierReward({
    required this.id,
    required this.kind,
    this.amountUnits = 0,
    this.assetId,
    this.duration,
  }) : assert(amountUnits >= 0);
}

class AvoraRechargeRewardTier {
  final String id;

  /// Server-authoritative normalized recharge threshold.
  ///
  /// UI may display country/local-currency equivalent.
  final int minimumRechargeUnits;

  final List<AvoraRechargeTierReward> rewards;

  final bool enabled;

  const AvoraRechargeRewardTier({
    required this.id,
    required this.minimumRechargeUnits,
    required this.rewards,
    this.enabled = true,
  }) : assert(minimumRechargeUnits > 0);
}

class AvoraMonthlyRechargeEvent {
  final String id;

  final String name;

  final AvoraRechargeEventStatus status;

  /// Example:
  /// normalized_recharge_units
  /// usd_equivalent_units
  /// Event configuration decides the accounting basis.
  final String rechargeValueType;

  /// Empty means global unless another compliance rule restricts it.
  final Set<String> allowedCountryCodes;

  final DateTime startsAt;

  /// Recharge occurring at/after this instant does not
  /// count toward this event period.
  final DateTime endsAt;

  /// User must claim before/at this configured deadline.
  /// Can equal month-end or include a later grace period.
  final DateTime claimDeadline;

  final AvoraRechargeClaimMode claimMode;

  final bool requireVerifiedId;

  final List<AvoraRechargeRewardTier> tiers;

  const AvoraMonthlyRechargeEvent({
    required this.id,
    required this.name,
    required this.status,
    required this.rechargeValueType,
    required this.startsAt,
    required this.endsAt,
    required this.claimDeadline,
    required this.claimMode,
    required this.tiers,
    this.allowedCountryCodes = const {},
    this.requireVerifiedId = true,
  });

  bool supportsCountry(String countryCode) {
    if (allowedCountryCodes.isEmpty) {
      return true;
    }

    final requested = countryCode.trim().toUpperCase();

    return allowedCountryCodes.any(
      (code) => code.trim().toUpperCase() == requested,
    );
  }

  bool rechargeFallsInsidePeriod(DateTime time) {
    return !time.isBefore(startsAt) && time.isBefore(endsAt);
  }

  bool canClaimAt(DateTime time) {
    if (status != AvoraRechargeEventStatus.active &&
        status != AvoraRechargeEventStatus.ended) {
      return false;
    }

    return !time.isAfter(claimDeadline);
  }
}

class AvoraEligibleRechargeRecord {
  final String id;

  final String userId;

  final int rechargeUnits;

  final DateTime confirmedAt;

  final bool confirmed;
  final bool refunded;
  final bool reversed;
  final bool chargebackOrDispute;
  final bool fraudOrRiskInvalidated;
  final bool eligibleSource;

  const AvoraEligibleRechargeRecord({
    required this.id,
    required this.userId,
    required this.rechargeUnits,
    required this.confirmedAt,
    this.confirmed = true,
    this.refunded = false,
    this.reversed = false,
    this.chargebackOrDispute = false,
    this.fraudOrRiskInvalidated = false,
    this.eligibleSource = true,
  }) : assert(rechargeUnits >= 0);

  bool isEligibleFor(
    AvoraMonthlyRechargeEvent event,
  ) {
    return confirmed &&
        eligibleSource &&
        !refunded &&
        !reversed &&
        !chargebackOrDispute &&
        !fraudOrRiskInvalidated &&
        event.rechargeFallsInsidePeriod(confirmedAt);
  }
}

class AvoraRechargeTierClaimRecord {
  final String id;

  final String eventId;
  final String tierId;
  final String userId;

  final int qualifiedRechargeUnits;

  final DateTime claimedAt;

  /// IDs of rewards granted by this claim.
  final List<String> rewardGrantIds;

  const AvoraRechargeTierClaimRecord({
    required this.id,
    required this.eventId,
    required this.tierId,
    required this.userId,
    required this.qualifiedRechargeUnits,
    required this.claimedAt,
    required this.rewardGrantIds,
  }) : assert(qualifiedRechargeUnits >= 0);
}

enum AvoraRechargeClaimDenyReason {
  none,
  eventUnavailable,
  countryNotAllowed,
  verificationRequired,
  claimDeadlinePassed,
  tierNotFound,
  tierDisabled,
  rechargeTargetNotReached,
  alreadyClaimed,
  higherTierOnly,
}

class AvoraRechargeEventProgress {
  final int eligibleRechargeUnits;

  final List<AvoraRechargeRewardTier> reachedTiers;

  final List<AvoraRechargeRewardTier> claimableTiers;

  const AvoraRechargeEventProgress({
    required this.eligibleRechargeUnits,
    required this.reachedTiers,
    required this.claimableTiers,
  });
}

class AvoraRechargeClaimDecision {
  final bool allowed;

  final AvoraRechargeClaimDenyReason reason;

  final int eligibleRechargeUnits;

  final AvoraRechargeRewardTier? tier;

  const AvoraRechargeClaimDecision({
    required this.allowed,
    required this.reason,
    required this.eligibleRechargeUnits,
    required this.tier,
  });
}

class AvoraMonthlyRechargeRewardEngine {
  const AvoraMonthlyRechargeRewardEngine._();

  static int eligibleRechargeTotal({
    required AvoraMonthlyRechargeEvent event,
    required String userId,
    required List<AvoraEligibleRechargeRecord> rechargeRecords,
  }) {
    return rechargeRecords
        .where(
          (record) => record.userId == userId && record.isEligibleFor(event),
        )
        .fold<int>(
          0,
          (sum, record) => sum + record.rechargeUnits,
        );
  }

  static AvoraRechargeEventProgress progress({
    required AvoraMonthlyRechargeEvent event,
    required String userId,
    required List<AvoraEligibleRechargeRecord> rechargeRecords,
    required List<AvoraRechargeTierClaimRecord> existingClaims,
  }) {
    final total = eligibleRechargeTotal(
      event: event,
      userId: userId,
      rechargeRecords: rechargeRecords,
    );

    final tiers = event.tiers
        .where(
          (tier) => tier.enabled && total >= tier.minimumRechargeUnits,
        )
        .toList(growable: true)
      ..sort(
        (a, b) => a.minimumRechargeUnits.compareTo(
          b.minimumRechargeUnits,
        ),
      );

    final claimedTierIds = existingClaims
        .where(
          (claim) => claim.eventId == event.id && claim.userId == userId,
        )
        .map((claim) => claim.tierId)
        .toSet();

    List<AvoraRechargeRewardTier> claimable;

    switch (event.claimMode) {
      case AvoraRechargeClaimMode.cumulative:
        claimable = tiers
            .where(
              (tier) => !claimedTierIds.contains(tier.id),
            )
            .toList(growable: false);

      case AvoraRechargeClaimMode.highestTierOnly:
        final hasEventClaim = existingClaims.any(
          (claim) => claim.eventId == event.id && claim.userId == userId,
        );

        if (hasEventClaim || tiers.isEmpty) {
          claimable = const [];
        } else {
          claimable = [tiers.last];
        }
    }

    return AvoraRechargeEventProgress(
      eligibleRechargeUnits: total,
      reachedTiers: List.unmodifiable(tiers),
      claimableTiers: List.unmodifiable(claimable),
    );
  }

  static AvoraRechargeClaimDecision evaluateClaim({
    required AvoraMonthlyRechargeEvent event,
    required String userId,
    required String tierId,
    required String countryCode,
    required bool identityVerified,
    required List<AvoraEligibleRechargeRecord> rechargeRecords,
    required List<AvoraRechargeTierClaimRecord> existingClaims,
    required DateTime now,
  }) {
    AvoraRechargeClaimDecision deny(
      AvoraRechargeClaimDenyReason reason, {
      int total = 0,
      AvoraRechargeRewardTier? tier,
    }) {
      return AvoraRechargeClaimDecision(
        allowed: false,
        reason: reason,
        eligibleRechargeUnits: total,
        tier: tier,
      );
    }

    if (event.status != AvoraRechargeEventStatus.active &&
        event.status != AvoraRechargeEventStatus.ended) {
      return deny(
        AvoraRechargeClaimDenyReason.eventUnavailable,
      );
    }

    if (!event.supportsCountry(countryCode)) {
      return deny(
        AvoraRechargeClaimDenyReason.countryNotAllowed,
      );
    }

    if (event.requireVerifiedId && !identityVerified) {
      return deny(
        AvoraRechargeClaimDenyReason.verificationRequired,
      );
    }

    if (!event.canClaimAt(now)) {
      return deny(
        AvoraRechargeClaimDenyReason.claimDeadlinePassed,
      );
    }

    AvoraRechargeRewardTier? selected;

    for (final tier in event.tiers) {
      if (tier.id == tierId) {
        selected = tier;
        break;
      }
    }

    if (selected == null) {
      return deny(
        AvoraRechargeClaimDenyReason.tierNotFound,
      );
    }

    if (!selected.enabled) {
      return deny(
        AvoraRechargeClaimDenyReason.tierDisabled,
        tier: selected,
      );
    }

    final progressResult = progress(
      event: event,
      userId: userId,
      rechargeRecords: rechargeRecords,
      existingClaims: existingClaims,
    );

    final total = progressResult.eligibleRechargeUnits;

    if (total < selected.minimumRechargeUnits) {
      return deny(
        AvoraRechargeClaimDenyReason.rechargeTargetNotReached,
        total: total,
        tier: selected,
      );
    }

    final alreadyClaimed = existingClaims.any(
      (claim) =>
          claim.eventId == event.id &&
          claim.userId == userId &&
          claim.tierId == selected!.id,
    );

    if (alreadyClaimed) {
      return deny(
        AvoraRechargeClaimDenyReason.alreadyClaimed,
        total: total,
        tier: selected,
      );
    }

    if (event.claimMode == AvoraRechargeClaimMode.highestTierOnly) {
      final claimable = progressResult.claimableTiers;

      if (claimable.isEmpty || claimable.single.id != selected.id) {
        return deny(
          AvoraRechargeClaimDenyReason.higherTierOnly,
          total: total,
          tier: selected,
        );
      }
    }

    return AvoraRechargeClaimDecision(
      allowed: true,
      reason: AvoraRechargeClaimDenyReason.none,
      eligibleRechargeUnits: total,
      tier: selected,
    );
  }

  /// Recharge-event rewards are benefits, not automatic
  /// cash-withdrawable liability.
  static bool rewardIsWithdrawableByDefault(
    AvoraRechargeTierReward reward,
  ) {
    return false;
  }

  /// Vanity reward only grants a temporary selection right.
  /// Immutable AVORA ID remains unchanged.
  static bool vanityRewardReplacesImmutableAvoraId(
    AvoraRechargeTierReward reward,
  ) {
    return false;
  }
}
