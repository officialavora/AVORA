enum AvoraReactionSurface {
  room,
  audioPk,
  live,
  livePk,
  profile,
  inbox,
  custom,
}

enum AvoraReactionTargetType {
  self,
  user,
  seat,
  room,
}

enum AvoraReactionHorizontalSide {
  left,
  center,
  right,
  unknown,
}

enum AvoraReactionDenyReason {
  none,
  featureDisabled,
  reactionDisabled,
  surfaceNotAllowed,
  targetTypeNotAllowed,
  directedReactionDisabled,
  blocked,
  moderationDenied,
  invalidBurstCount,
  cooldownActive,
  rateLimited,
  noMappedEffect,
}

class AvoraReactionEffectVariants {
  /// Generic fallback effect.
  final String? defaultEffectId;

  /// Optional directional variants.
  final String? leftEffectId;
  final String? centerEffectId;
  final String? rightEffectId;

  const AvoraReactionEffectVariants({
    this.defaultEffectId,
    this.leftEffectId,
    this.centerEffectId,
    this.rightEffectId,
  });

  String? resolve(
    AvoraReactionHorizontalSide side,
  ) {
    switch (side) {
      case AvoraReactionHorizontalSide.left:
        return leftEffectId ?? centerEffectId ?? defaultEffectId;

      case AvoraReactionHorizontalSide.center:
        return centerEffectId ?? defaultEffectId;

      case AvoraReactionHorizontalSide.right:
        return rightEffectId ?? centerEffectId ?? defaultEffectId;

      case AvoraReactionHorizontalSide.unknown:
        return centerEffectId ?? defaultEffectId;
    }
  }
}

class AvoraReactionDefinition {
  final String reactionId;

  /// Open-ended semantic reference such as:
  /// kiss, hammer, slipper, chili, banana, lollipop,
  /// wink, laugh, cry, broken_heart, etc.
  final String semanticKey;

  final String displayName;

  final bool enabled;

  /// Effect IDs resolve through the shared entertainment effect engine.
  final AvoraReactionEffectVariants effectVariants;

  final Set<AvoraReactionSurface> allowedSurfaces;

  final Set<AvoraReactionTargetType> allowedTargetTypes;

  /// Reaction-specific anti-spam limit.
  final int maximumBurstCount;

  /// Minimum time before the same actor can trigger this
  /// exact reaction again when cooldown is enabled.
  final Duration cooldown;

  const AvoraReactionDefinition({
    required this.reactionId,
    required this.semanticKey,
    required this.displayName,
    required this.enabled,
    required this.effectVariants,
    required this.allowedSurfaces,
    required this.allowedTargetTypes,
    required this.maximumBurstCount,
    required this.cooldown,
  }) : assert(maximumBurstCount >= 1);
}

class AvoraReactionPolicy {
  final bool enabled;

  /// Master burst ceiling regardless of reaction definition.
  final int maximumBurstCount;

  /// Rate limit for all reactions by one actor.
  final int maximumEventsPerWindow;

  final Duration rateWindow;

  final bool allowDirectedReactions;

  const AvoraReactionPolicy({
    required this.maximumBurstCount,
    required this.maximumEventsPerWindow,
    required this.rateWindow,
    this.enabled = true,
    this.allowDirectedReactions = true,
  })  : assert(maximumBurstCount >= 1),
        assert(maximumEventsPerWindow >= 1);
}

class AvoraReactionRequest {
  final String reactionEventId;

  final String reactionId;

  /// Authoritative immutable AVORA ID.
  final String actorAvoraId;

  final AvoraReactionSurface surface;

  final AvoraReactionTargetType targetType;

  final String? targetAvoraId;

  final int? targetSeatNumber;

  /// Resolved by the actual responsive room/live layout.
  /// Do not derive visual direction from seat number alone.
  final AvoraReactionHorizontalSide targetHorizontalSide;

  final int burstCount;

  final DateTime occurredAt;

  const AvoraReactionRequest({
    required this.reactionEventId,
    required this.reactionId,
    required this.actorAvoraId,
    required this.surface,
    required this.targetType,
    required this.targetHorizontalSide,
    required this.burstCount,
    required this.occurredAt,
    this.targetAvoraId,
    this.targetSeatNumber,
  }) : assert(burstCount >= 1);
}

class AvoraReactionHistoryEntry {
  final String actorAvoraId;
  final String reactionId;
  final DateTime occurredAt;

  const AvoraReactionHistoryEntry({
    required this.actorAvoraId,
    required this.reactionId,
    required this.occurredAt,
  });
}

class AvoraReactionDecision {
  final bool allowed;

  final AvoraReactionDenyReason reason;

  /// Step 9B effect ID selected for this reaction.
  final String? effectId;

  final int approvedBurstCount;

  const AvoraReactionDecision({
    required this.allowed,
    required this.reason,
    required this.effectId,
    required this.approvedBurstCount,
  });
}

class AvoraReactionRuntimeEngine {
  const AvoraReactionRuntimeEngine._();

  static AvoraReactionDecision evaluate({
    required AvoraReactionDefinition definition,
    required AvoraReactionRequest request,
    required AvoraReactionPolicy policy,
    required bool actorBlockedByTarget,
    required bool moderationAllowsReaction,
    required List<AvoraReactionHistoryEntry> recentHistory,
    required DateTime now,
  }) {
    if (!policy.enabled) {
      return _deny(
        AvoraReactionDenyReason.featureDisabled,
      );
    }

    if (!definition.enabled) {
      return _deny(
        AvoraReactionDenyReason.reactionDisabled,
      );
    }

    if (!definition.allowedSurfaces.contains(request.surface)) {
      return _deny(
        AvoraReactionDenyReason.surfaceNotAllowed,
      );
    }

    if (!definition.allowedTargetTypes.contains(
      request.targetType,
    )) {
      return _deny(
        AvoraReactionDenyReason.targetTypeNotAllowed,
      );
    }

    final directed = request.targetType == AvoraReactionTargetType.user ||
        request.targetType == AvoraReactionTargetType.seat;

    if (directed && !policy.allowDirectedReactions) {
      return _deny(
        AvoraReactionDenyReason.directedReactionDisabled,
      );
    }

    if (actorBlockedByTarget) {
      return _deny(
        AvoraReactionDenyReason.blocked,
      );
    }

    if (!moderationAllowsReaction) {
      return _deny(
        AvoraReactionDenyReason.moderationDenied,
      );
    }

    final burstLimit = definition.maximumBurstCount < policy.maximumBurstCount
        ? definition.maximumBurstCount
        : policy.maximumBurstCount;

    if (request.burstCount > burstLimit) {
      return _deny(
        AvoraReactionDenyReason.invalidBurstCount,
      );
    }

    if (definition.cooldown > Duration.zero) {
      for (final history in recentHistory) {
        if (history.actorAvoraId != request.actorAvoraId ||
            history.reactionId != request.reactionId) {
          continue;
        }

        final elapsed = now.difference(history.occurredAt);

        if (!elapsed.isNegative && elapsed < definition.cooldown) {
          return _deny(
            AvoraReactionDenyReason.cooldownActive,
          );
        }
      }
    }

    final rateWindowStart = now.subtract(policy.rateWindow);

    final actorEventsInWindow = recentHistory.where(
      (history) =>
          history.actorAvoraId == request.actorAvoraId &&
          !history.occurredAt.isBefore(rateWindowStart) &&
          !history.occurredAt.isAfter(now),
    );

    if (actorEventsInWindow.length >= policy.maximumEventsPerWindow) {
      return _deny(
        AvoraReactionDenyReason.rateLimited,
      );
    }

    final effectId = definition.effectVariants.resolve(
      request.targetHorizontalSide,
    );

    if (effectId == null) {
      return _deny(
        AvoraReactionDenyReason.noMappedEffect,
      );
    }

    return AvoraReactionDecision(
      allowed: true,
      reason: AvoraReactionDenyReason.none,
      effectId: effectId,
      approvedBurstCount: request.burstCount,
    );
  }

  static AvoraReactionDecision _deny(
    AvoraReactionDenyReason reason,
  ) {
    return AvoraReactionDecision(
      allowed: false,
      reason: reason,
      effectId: null,
      approvedBurstCount: 0,
    );
  }

  /// 5/10/25/50-seat layouts may place the same seat number
  /// differently, so direction must come from layout context.
  static bool seatNumberAloneDeterminesReactionDirection() {
    return false;
  }

  /// Reaction audio/animation comes from the shared Step 9B engine.
  static bool reactionRuntimeDuplicatesEffectPlaybackEngine() {
    return false;
  }

  /// A reaction cannot alter gifting/settlement economics.
  static bool reactionChangesGiftSettlement() {
    return false;
  }

  /// Reactions do not grant staff or moderation authority.
  static bool reactionGrantsAuthority() {
    return false;
  }

  /// Muting reaction effects does not mute room voice/music.
  static bool reactionMuteMutesCoreRoomAudio() {
    return false;
  }

  /// Live/PK core audio remains separate from reaction SFX.
  static bool reactionMuteMutesLiveOrPkAudio() {
    return false;
  }

  /// Individual funny/romantic reaction names remain data-driven.
  static bool everyNewReactionRequiresCoreEnumChange() {
    return false;
  }

  /// Unlimited future reaction content may be mapped by data/catalog.
  static bool supportsExtensibleReactionCatalog() {
    return true;
  }
}
