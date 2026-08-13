enum AvoraInviteDestinationType {
  room,
  audioPk,
  livePk,
  live,
  game,
  event,
  profile,
  community,
  custom,
}

enum AvoraInviteDeliveryChannel {
  inApp,
  systemShare,
  copyLink,
  qrCode,
}

enum AvoraInviteRecipientSource {
  friend,
  following,
  follower,
  addFriend,
  search,
  contact,
  roomParticipant,
  external,
}

enum AvoraInviteStatus {
  active,
  revoked,
  expired,
}

enum AvoraInviteOutcome {
  sent,
  opened,
  accepted,
  joined,
  declined,
  failed,
  expired,
}

enum AvoraInviteDenyReason {
  none,
  invitesDisabled,
  inviterRestricted,
  recipientBlocked,
  privacyDenied,
  rateLimited,
  targetUnavailable,
  targetCountryRestricted,
  complianceRestricted,
  roomBanned,
  targetFull,
  recipientNotEligible,
  channelNotAllowed,
  sourceNotAllowed,
}

enum AvoraInviteOpenAction {
  openDestination,
  requireAuthenticationThenContinue,
  requirePasswordThenContinue,
  denied,
  expired,
  revoked,
}

class AvoraInviteDestination {
  final AvoraInviteDestinationType type;

  /// Immutable backend target ID.
  final String targetId;

  /// Optional public alias/room number/etc.
  final String? publicAlias;

  const AvoraInviteDestination({
    required this.type,
    required this.targetId,
    this.publicAlias,
  });
}

class AvoraInviteToken {
  /// Opaque server-issued token.
  final String token;

  final String inviterAvoraId;

  final AvoraInviteDestination destination;

  final AvoraInviteDeliveryChannel deliveryChannel;

  final DateTime createdAt;
  final DateTime expiresAt;

  final AvoraInviteStatus status;

  /// Optional referral metadata.
  /// Referral attribution itself remains a separate record/module.
  final String? referralCode;

  final String? campaignId;

  /// Optional external share-target hint for analytics only.
  /// Actual installed share apps come from the device/OS.
  final String? shareTargetHint;

  const AvoraInviteToken({
    required this.token,
    required this.inviterAvoraId,
    required this.destination,
    required this.deliveryChannel,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    this.referralCode,
    this.campaignId,
    this.shareTargetHint,
  });

  bool isActiveAt(DateTime now) {
    if (status != AvoraInviteStatus.active) {
      return false;
    }

    return now.isBefore(expiresAt);
  }
}

class AvoraInvitePolicy {
  final bool enabled;

  final bool allowInApp;
  final bool allowSystemShare;
  final bool allowCopyLink;
  final bool allowQrCode;

  final Set<AvoraInviteRecipientSource> allowedRecipientSources;

  /// Spam/rate-limit control.
  final int maximumInvitesPerWindow;

  final Duration rateLimitWindow;

  /// Default token lifetime.
  final Duration tokenLifetime;

  /// Only successful eligible outcomes count for invite rewards.
  final Set<AvoraInviteOutcome> rewardEligibleOutcomes;

  const AvoraInvitePolicy({
    this.enabled = true,
    this.allowInApp = true,
    this.allowSystemShare = true,
    this.allowCopyLink = true,
    this.allowQrCode = true,
    this.allowedRecipientSources = const {
      AvoraInviteRecipientSource.friend,
      AvoraInviteRecipientSource.following,
      AvoraInviteRecipientSource.follower,
      AvoraInviteRecipientSource.addFriend,
      AvoraInviteRecipientSource.search,
      AvoraInviteRecipientSource.contact,
      AvoraInviteRecipientSource.roomParticipant,
      AvoraInviteRecipientSource.external,
    },
    this.maximumInvitesPerWindow = 30,
    this.rateLimitWindow = const Duration(minutes: 10),
    this.tokenLifetime = const Duration(hours: 24),
    this.rewardEligibleOutcomes = const {
      AvoraInviteOutcome.joined,
    },
  }) : assert(maximumInvitesPerWindow > 0);
}

class AvoraInviteSendContext {
  final String inviterAvoraId;

  final String? recipientAvoraId;

  final AvoraInviteDestination destination;

  final AvoraInviteDeliveryChannel deliveryChannel;

  final AvoraInviteRecipientSource recipientSource;

  final bool inviterRestricted;

  final bool recipientBlockedInviter;
  final bool inviterBlockedRecipient;

  final bool recipientPrivacyAllowsInvite;

  /// Number already sent inside the configured rate-limit window.
  final int invitesSentInCurrentWindow;

  final bool targetAvailable;

  final bool countryAllowed;
  final bool complianceAllowed;

  final bool recipientRoomBanned;

  final bool targetAtCapacity;

  final bool recipientEligibleForDestination;

  const AvoraInviteSendContext({
    required this.inviterAvoraId,
    required this.recipientAvoraId,
    required this.destination,
    required this.deliveryChannel,
    required this.recipientSource,
    required this.inviterRestricted,
    required this.recipientBlockedInviter,
    required this.inviterBlockedRecipient,
    required this.recipientPrivacyAllowsInvite,
    required this.invitesSentInCurrentWindow,
    required this.targetAvailable,
    required this.countryAllowed,
    required this.complianceAllowed,
    required this.recipientRoomBanned,
    required this.targetAtCapacity,
    required this.recipientEligibleForDestination,
  }) : assert(invitesSentInCurrentWindow >= 0);
}

class AvoraInviteSendDecision {
  final bool allowed;
  final AvoraInviteDenyReason reason;

  const AvoraInviteSendDecision({
    required this.allowed,
    required this.reason,
  });
}

class AvoraInviteOpenContext {
  final bool signedIn;

  final bool targetAvailable;

  final bool countryAllowed;
  final bool complianceAllowed;

  final bool userBlockedFromTarget;

  final bool targetAtCapacity;

  final bool userEligibleForDestination;

  /// Invite never silently bypasses target password.
  final bool targetRequiresPassword;

  final bool passwordSatisfied;

  const AvoraInviteOpenContext({
    required this.signedIn,
    required this.targetAvailable,
    required this.countryAllowed,
    required this.complianceAllowed,
    required this.userBlockedFromTarget,
    required this.targetAtCapacity,
    required this.userEligibleForDestination,
    required this.targetRequiresPassword,
    required this.passwordSatisfied,
  });
}

class AvoraInviteOpenDecision {
  final AvoraInviteOpenAction action;
  final AvoraInviteDenyReason denyReason;

  /// Destination is retained through login/signup when possible.
  final AvoraInviteDestination? continueDestination;

  const AvoraInviteOpenDecision({
    required this.action,
    required this.denyReason,
    required this.continueDestination,
  });
}

class AvoraInviteOutcomeRecord {
  final String inviteToken;

  final String inviterAvoraId;

  final String? recipientAvoraId;

  final AvoraInviteOutcome outcome;

  final DateTime occurredAt;

  /// Verified/valid outcome, not merely a sent share.
  final bool identityEligible;

  final bool fraudOrAbuseInvalidated;

  const AvoraInviteOutcomeRecord({
    required this.inviteToken,
    required this.inviterAvoraId,
    required this.recipientAvoraId,
    required this.outcome,
    required this.occurredAt,
    required this.identityEligible,
    required this.fraudOrAbuseInvalidated,
  });
}

class AvoraInviteRewardDecision {
  final bool countForInviteLeaderboard;
  final bool rewardEligible;

  const AvoraInviteRewardDecision({
    required this.countForInviteLeaderboard,
    required this.rewardEligible,
  });
}

class AvoraInviteShareEngine {
  const AvoraInviteShareEngine._();

  static bool _channelAllowed({
    required AvoraInviteDeliveryChannel channel,
    required AvoraInvitePolicy policy,
  }) {
    return switch (channel) {
      AvoraInviteDeliveryChannel.inApp => policy.allowInApp,
      AvoraInviteDeliveryChannel.systemShare => policy.allowSystemShare,
      AvoraInviteDeliveryChannel.copyLink => policy.allowCopyLink,
      AvoraInviteDeliveryChannel.qrCode => policy.allowQrCode,
    };
  }

  static AvoraInviteSendDecision evaluateSend({
    required AvoraInviteSendContext context,
    required AvoraInvitePolicy policy,
  }) {
    if (!policy.enabled) {
      return const AvoraInviteSendDecision(
        allowed: false,
        reason: AvoraInviteDenyReason.invitesDisabled,
      );
    }

    if (!_channelAllowed(
      channel: context.deliveryChannel,
      policy: policy,
    )) {
      return const AvoraInviteSendDecision(
        allowed: false,
        reason: AvoraInviteDenyReason.channelNotAllowed,
      );
    }

    if (!policy.allowedRecipientSources.contains(
      context.recipientSource,
    )) {
      return const AvoraInviteSendDecision(
        allowed: false,
        reason: AvoraInviteDenyReason.sourceNotAllowed,
      );
    }

    if (context.inviterRestricted) {
      return const AvoraInviteSendDecision(
        allowed: false,
        reason: AvoraInviteDenyReason.inviterRestricted,
      );
    }

    if (context.recipientBlockedInviter || context.inviterBlockedRecipient) {
      return const AvoraInviteSendDecision(
        allowed: false,
        reason: AvoraInviteDenyReason.recipientBlocked,
      );
    }

    if (!context.recipientPrivacyAllowsInvite &&
        context.deliveryChannel == AvoraInviteDeliveryChannel.inApp) {
      return const AvoraInviteSendDecision(
        allowed: false,
        reason: AvoraInviteDenyReason.privacyDenied,
      );
    }

    if (context.invitesSentInCurrentWindow >= policy.maximumInvitesPerWindow) {
      return const AvoraInviteSendDecision(
        allowed: false,
        reason: AvoraInviteDenyReason.rateLimited,
      );
    }

    if (!context.targetAvailable) {
      return const AvoraInviteSendDecision(
        allowed: false,
        reason: AvoraInviteDenyReason.targetUnavailable,
      );
    }

    if (!context.countryAllowed) {
      return const AvoraInviteSendDecision(
        allowed: false,
        reason: AvoraInviteDenyReason.targetCountryRestricted,
      );
    }

    if (!context.complianceAllowed) {
      return const AvoraInviteSendDecision(
        allowed: false,
        reason: AvoraInviteDenyReason.complianceRestricted,
      );
    }

    if (context.recipientRoomBanned) {
      return const AvoraInviteSendDecision(
        allowed: false,
        reason: AvoraInviteDenyReason.roomBanned,
      );
    }

    if (context.targetAtCapacity) {
      return const AvoraInviteSendDecision(
        allowed: false,
        reason: AvoraInviteDenyReason.targetFull,
      );
    }

    if (!context.recipientEligibleForDestination) {
      return const AvoraInviteSendDecision(
        allowed: false,
        reason: AvoraInviteDenyReason.recipientNotEligible,
      );
    }

    return const AvoraInviteSendDecision(
      allowed: true,
      reason: AvoraInviteDenyReason.none,
    );
  }

  static AvoraInviteOpenDecision resolveOpen({
    required AvoraInviteToken invite,
    required AvoraInviteOpenContext context,
    required DateTime now,
  }) {
    if (invite.status == AvoraInviteStatus.revoked) {
      return const AvoraInviteOpenDecision(
        action: AvoraInviteOpenAction.revoked,
        denyReason: AvoraInviteDenyReason.targetUnavailable,
        continueDestination: null,
      );
    }

    if (!invite.isActiveAt(now)) {
      return const AvoraInviteOpenDecision(
        action: AvoraInviteOpenAction.expired,
        denyReason: AvoraInviteDenyReason.targetUnavailable,
        continueDestination: null,
      );
    }

    if (!context.targetAvailable) {
      return const AvoraInviteOpenDecision(
        action: AvoraInviteOpenAction.denied,
        denyReason: AvoraInviteDenyReason.targetUnavailable,
        continueDestination: null,
      );
    }

    if (!context.countryAllowed) {
      return const AvoraInviteOpenDecision(
        action: AvoraInviteOpenAction.denied,
        denyReason: AvoraInviteDenyReason.targetCountryRestricted,
        continueDestination: null,
      );
    }

    if (!context.complianceAllowed) {
      return const AvoraInviteOpenDecision(
        action: AvoraInviteOpenAction.denied,
        denyReason: AvoraInviteDenyReason.complianceRestricted,
        continueDestination: null,
      );
    }

    if (context.userBlockedFromTarget) {
      return const AvoraInviteOpenDecision(
        action: AvoraInviteOpenAction.denied,
        denyReason: AvoraInviteDenyReason.roomBanned,
        continueDestination: null,
      );
    }

    if (context.targetAtCapacity) {
      return const AvoraInviteOpenDecision(
        action: AvoraInviteOpenAction.denied,
        denyReason: AvoraInviteDenyReason.targetFull,
        continueDestination: null,
      );
    }

    if (!context.userEligibleForDestination) {
      return const AvoraInviteOpenDecision(
        action: AvoraInviteOpenAction.denied,
        denyReason: AvoraInviteDenyReason.recipientNotEligible,
        continueDestination: null,
      );
    }

    if (!context.signedIn) {
      return AvoraInviteOpenDecision(
        action: AvoraInviteOpenAction.requireAuthenticationThenContinue,
        denyReason: AvoraInviteDenyReason.none,
        continueDestination: invite.destination,
      );
    }

    if (context.targetRequiresPassword && !context.passwordSatisfied) {
      return AvoraInviteOpenDecision(
        action: AvoraInviteOpenAction.requirePasswordThenContinue,
        denyReason: AvoraInviteDenyReason.none,
        continueDestination: invite.destination,
      );
    }

    return AvoraInviteOpenDecision(
      action: AvoraInviteOpenAction.openDestination,
      denyReason: AvoraInviteDenyReason.none,
      continueDestination: invite.destination,
    );
  }

  static AvoraInviteRewardDecision rewardEligibility({
    required AvoraInviteOutcomeRecord outcome,
    required AvoraInvitePolicy policy,
  }) {
    final eligible = policy.rewardEligibleOutcomes.contains(outcome.outcome) &&
        outcome.identityEligible &&
        !outcome.fraudOrAbuseInvalidated;

    return AvoraInviteRewardDecision(
      countForInviteLeaderboard: eligible,
      rewardEligible: eligible,
    );
  }

  /// Sharing alone is not a successful invite outcome.
  static bool sentInviteImmediatelyCountsForReward() {
    return false;
  }

  /// Referral attribution and destination invitation stay separate.
  static bool inviteActionEqualsReferralAttribution() {
    return false;
  }

  /// Existing signed-in users may route directly to destination.
  static bool supportsDirectDestinationOpen() {
    return true;
  }

  /// New users may authenticate/install and then continue.
  static bool supportsPostAuthenticationContinuation() {
    return true;
  }

  /// Invite links do not bypass room/password/safety restrictions.
  static bool inviteBypassesDestinationRestrictions() {
    return false;
  }
}
