enum AvoraGameCategory {
  board,
  arcade,
  fishArcade,
  wheel,
  line,
  party,
  puzzle,
  card,
  casual,
  externalParty,
  custom,
}

enum AvoraGameOutcomeType {
  skill,
  chance,
  mixed,
  socialCasual,
  external,
}

enum AvoraGameMode {
  solo,
  privateInvite,
  roomParty,
  randomMatch,
  spectator,
}

enum AvoraGameRewardKind {
  leaderboardPoints,

  /// Game-only/non-cash progression value.
  gamePoints,

  /// Promotional/spend benefit.
  /// Non-withdrawable by default.
  promoCoins,

  cosmetic,
  badge,
  frame,
  eventToken,

  /// High-risk category.
  /// Disabled unless explicit country policy allows it.
  withdrawableReward,
}

class AvoraGameDefinition {
  final String id;

  /// Catalog-controlled display name.
  final String displayName;

  final AvoraGameCategory category;
  final AvoraGameOutcomeType outcomeType;

  final Set<AvoraGameMode> supportedModes;

  final int minimumPlayers;
  final int maximumPlayers;

  final bool enabled;

  /// True only when AVORA owns/controls authoritative
  /// game-state and result calculation.
  final bool serverAuthoritative;

  /// External games can be party/deep-link integrations
  /// without pretending AVORA owns the game itself.
  final String? externalProviderReference;

  const AvoraGameDefinition({
    required this.id,
    required this.displayName,
    required this.category,
    required this.outcomeType,
    required this.supportedModes,
    required this.minimumPlayers,
    required this.maximumPlayers,
    required this.serverAuthoritative,
    this.enabled = true,
    this.externalProviderReference,
  })  : assert(minimumPlayers > 0),
        assert(maximumPlayers >= minimumPlayers);

  bool supportsMode(AvoraGameMode mode) {
    return enabled && supportedModes.contains(mode);
  }

  bool get supportsSolo => supportsMode(AvoraGameMode.solo);

  bool get supportsMultiplayer =>
      supportsMode(AvoraGameMode.privateInvite) ||
      supportsMode(AvoraGameMode.roomParty) ||
      supportsMode(AvoraGameMode.randomMatch);
}

class AvoraGameRewardDefinition {
  final String id;

  final AvoraGameRewardKind kind;

  final int amount;

  /// Reward may require a verified AVORA ID.
  final bool requireVerifiedId;

  /// Keeps game economics separate from payout economics.
  final bool requiresCountryCashConversionPermission;

  const AvoraGameRewardDefinition({
    required this.id,
    required this.kind,
    required this.amount,
    this.requireVerifiedId = true,
    this.requiresCountryCashConversionPermission = false,
  }) : assert(amount >= 0);

  bool get isPotentiallyWithdrawable =>
      kind == AvoraGameRewardKind.withdrawableReward;
}

enum AvoraGameRewardDecisionReason {
  allowed,
  gameDisabled,
  userNotVerified,
  countryGameDisabled,
  cashConversionNotAllowed,
}

class AvoraGameRewardDecision {
  final bool allowed;
  final AvoraGameRewardDecisionReason reason;

  const AvoraGameRewardDecision({
    required this.allowed,
    required this.reason,
  });
}

class AvoraGameRewardPolicy {
  const AvoraGameRewardPolicy._();

  static AvoraGameRewardDecision evaluate({
    required AvoraGameDefinition game,
    required AvoraGameRewardDefinition reward,
    required bool identityVerified,
    required bool countryGameEnabled,

    /// Must come from jurisdiction/compliance policy.
    required bool countryCashConversionAllowed,
  }) {
    if (!game.enabled) {
      return const AvoraGameRewardDecision(
        allowed: false,
        reason: AvoraGameRewardDecisionReason.gameDisabled,
      );
    }

    if (!countryGameEnabled) {
      return const AvoraGameRewardDecision(
        allowed: false,
        reason: AvoraGameRewardDecisionReason.countryGameDisabled,
      );
    }

    if (reward.requireVerifiedId && !identityVerified) {
      return const AvoraGameRewardDecision(
        allowed: false,
        reason: AvoraGameRewardDecisionReason.userNotVerified,
      );
    }

    if ((reward.isPotentiallyWithdrawable ||
            reward.requiresCountryCashConversionPermission) &&
        !countryCashConversionAllowed) {
      return const AvoraGameRewardDecision(
        allowed: false,
        reason: AvoraGameRewardDecisionReason.cashConversionNotAllowed,
      );
    }

    return const AvoraGameRewardDecision(
      allowed: true,
      reason: AvoraGameRewardDecisionReason.allowed,
    );
  }
}

class AvoraGameCatalog {
  const AvoraGameCatalog._();

  static List<AvoraGameDefinition> availableForMode({
    required List<AvoraGameDefinition> games,
    required AvoraGameMode mode,
  }) {
    return games
        .where((game) => game.supportsMode(mode))
        .toList(growable: false);
  }
}
