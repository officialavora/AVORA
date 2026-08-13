enum AvoraCpGiftBroadcastScope {
  none,
  room,
  global,
}

class AvoraCpGiftBroadcastPolicy {
  const AvoraCpGiftBroadcastPolicy({
    this.enabled = true,
    this.minimumRelationLevel = 1,
    this.minimumRelationPoints = 0,
    this.minimumRoomGiftUnits = 1,
    this.minimumRoomCombo = 1,
    this.minimumGlobalGiftUnits,
    this.minimumGlobalCombo,
    this.requireVerifiedUsers = true,
    this.requireActiveCp = true,
    this.standardGiftOnly = true,
    this.cooldownSeconds = 3,
    this.roomDurationSeconds = 6,
    this.globalDurationSeconds = 8,
    this.showSenderDp = true,
    this.showReceiverDp = true,
    this.showCoupleHeart = true,
  });

  final bool enabled;

  final int minimumRelationLevel;
  final int minimumRelationPoints;

  final int minimumRoomGiftUnits;
  final int minimumRoomCombo;

  /// null disables global escalation from this policy.
  final int? minimumGlobalGiftUnits;
  final int? minimumGlobalCombo;

  final bool requireVerifiedUsers;
  final bool requireActiveCp;
  final bool standardGiftOnly;

  final int cooldownSeconds;
  final int roomDurationSeconds;
  final int globalDurationSeconds;

  final bool showSenderDp;
  final bool showReceiverDp;
  final bool showCoupleHeart;
}

class AvoraCpGiftBroadcastEvent {
  const AvoraCpGiftBroadcastEvent({
    required this.eventId,
    required this.roomId,
    required this.relationshipId,
    required this.senderAvoraId,
    required this.receiverAvoraId,
    required this.senderIsCpMember,
    required this.receiverIsCpMember,
    required this.relationshipActive,
    required this.senderVerified,
    required this.receiverVerified,
    required this.relationLevel,
    required this.relationPoints,
    required this.giftUnits,
    required this.comboCount,
    required this.isStandardGift,
    required this.serverVerifiedGift,
    required this.createdAt,
  });

  final String eventId;
  final String roomId;
  final String relationshipId;

  final String senderAvoraId;
  final String receiverAvoraId;

  final bool senderIsCpMember;
  final bool receiverIsCpMember;

  final bool relationshipActive;

  final bool senderVerified;
  final bool receiverVerified;

  final int relationLevel;
  final int relationPoints;

  final int giftUnits;
  final int comboCount;

  final bool isStandardGift;

  /// Gift event must come from authoritative settlement/event pipeline.
  final bool serverVerifiedGift;

  final DateTime createdAt;
}

class AvoraCpGiftViewerPreference {
  const AvoraCpGiftViewerPreference({
    this.roomAnimationsEnabled = true,
    this.globalAnimationsEnabled = true,
    this.giftSoundsEnabled = true,
  });

  final bool roomAnimationsEnabled;
  final bool globalAnimationsEnabled;
  final bool giftSoundsEnabled;
}

class AvoraCpGiftBroadcastDecision {
  const AvoraCpGiftBroadcastDecision({
    required this.scope,
    required this.authoritativeEligible,
    required this.showVisualToViewer,
    required this.playSoundToViewer,
    required this.reason,
    required this.durationSeconds,
  });

  final AvoraCpGiftBroadcastScope scope;

  /// Whether the authoritative gift event earned the broadcast.
  final bool authoritativeEligible;

  /// Local viewer preference may suppress animation without
  /// changing the authoritative event.
  final bool showVisualToViewer;

  final bool playSoundToViewer;
  final String reason;
  final int durationSeconds;
}

class AvoraCpGiftBroadcastEngine {
  static AvoraCpGiftBroadcastDecision evaluate({
    required AvoraCpGiftBroadcastPolicy policy,
    required AvoraCpGiftBroadcastEvent event,
    required AvoraCpGiftViewerPreference viewerPreference,
    DateTime? previousBroadcastAt,
  }) {
    if (!policy.enabled) {
      return _deny('policyDisabled');
    }

    if (!event.serverVerifiedGift) {
      return _deny('giftNotServerVerified');
    }

    if (event.eventId.trim().isEmpty ||
        event.roomId.trim().isEmpty ||
        event.relationshipId.trim().isEmpty ||
        event.senderAvoraId.trim().isEmpty ||
        event.receiverAvoraId.trim().isEmpty) {
      return _deny('missingAuthoritativeIdentity');
    }

    if (policy.requireActiveCp && !event.relationshipActive) {
      return _deny('cpNotActive');
    }

    /// Sender must be one member of the CP relationship.
    if (!event.senderIsCpMember) {
      return _deny('senderNotCpMember');
    }

    if (policy.requireVerifiedUsers &&
        (!event.senderVerified || !event.receiverVerified)) {
      return _deny('verificationRequired');
    }

    if (policy.standardGiftOnly && !event.isStandardGift) {
      return _deny('giftKindNotEligible');
    }

    if (event.relationLevel < policy.minimumRelationLevel ||
        event.relationPoints < policy.minimumRelationPoints) {
      return _deny('relationshipThresholdNotMet');
    }

    if (previousBroadcastAt != null && policy.cooldownSeconds > 0) {
      final nextAllowed = previousBroadcastAt.add(
        Duration(seconds: policy.cooldownSeconds),
      );

      if (event.createdAt.isBefore(nextAllowed)) {
        return _deny('broadcastCooldownActive');
      }
    }

    final globalGiftThreshold = policy.minimumGlobalGiftUnits;
    final globalComboThreshold = policy.minimumGlobalCombo;

    final globalByGift =
        globalGiftThreshold != null && event.giftUnits >= globalGiftThreshold;

    final globalByCombo = globalComboThreshold != null &&
        event.comboCount >= globalComboThreshold;

    if (globalByGift || globalByCombo) {
      return AvoraCpGiftBroadcastDecision(
        scope: AvoraCpGiftBroadcastScope.global,
        authoritativeEligible: true,
        showVisualToViewer: viewerPreference.globalAnimationsEnabled,
        playSoundToViewer: viewerPreference.globalAnimationsEnabled &&
            viewerPreference.giftSoundsEnabled,
        reason: 'globalCpGiftThresholdMet',
        durationSeconds: policy.globalDurationSeconds,
      );
    }

    final roomGiftEligible = event.giftUnits >= policy.minimumRoomGiftUnits;

    final roomComboEligible = event.comboCount >= policy.minimumRoomCombo;

    if (!roomGiftEligible && !roomComboEligible) {
      return _deny('roomGiftThresholdNotMet');
    }

    return AvoraCpGiftBroadcastDecision(
      scope: AvoraCpGiftBroadcastScope.room,
      authoritativeEligible: true,
      showVisualToViewer: viewerPreference.roomAnimationsEnabled,
      playSoundToViewer: viewerPreference.roomAnimationsEnabled &&
          viewerPreference.giftSoundsEnabled,
      reason: 'roomCpGiftThresholdMet',
      durationSeconds: policy.roomDurationSeconds,
    );
  }

  static AvoraCpGiftBroadcastDecision _deny(String reason) {
    return AvoraCpGiftBroadcastDecision(
      scope: AvoraCpGiftBroadcastScope.none,
      authoritativeEligible: false,
      showVisualToViewer: false,
      playSoundToViewer: false,
      reason: reason,
      durationSeconds: 0,
    );
  }

  /// CP gift ribbon does not require paired seats.
  static bool pairedSeatsRequiredForGiftRibbon() => false;

  /// Any eligible room may show the CP gift ribbon.
  static bool specialCpRoomRequired() => false;

  /// Visual suppression never cancels gift settlement or CP scoring.
  static bool localMuteChangesAuthoritativeGiftEvent() => false;

  /// Public visual effect never grants moderation/role authority.
  static bool broadcastEffectGrantsAuthority() => false;
}
