enum AvoraProfileAudioEntitlementSource {
  free,
  adminGranted,
  achievement,
  event,
  vip,
  svip,
  purchase,
  seasonal,
  creator,
  custom,
}

enum AvoraProfileAudioReviewStatus {
  draft,
  submitted,
  underReview,
  approved,
  rejected,
  revoked,
  expired,
}

enum AvoraProfileAudioPlaybackAction {
  play,
  availableButDoNotAutoplay,
  mutedByUser,
  blockedByPlatform,
  entitlementInactive,
  assetNotApproved,
  featureDisabled,
}

class AvoraProfileAudioAsset {
  final String assetId;

  /// Immutable owner authority.
  final String ownerAvoraId;

  /// Approved storage/CDN reference only.
  final String audioAssetRef;

  final String? displayTitle;

  /// Clip length is policy-configurable.
  final int durationSeconds;

  final int version;

  const AvoraProfileAudioAsset({
    required this.assetId,
    required this.ownerAvoraId,
    required this.audioAssetRef,
    required this.durationSeconds,
    required this.version,
    this.displayTitle,
  })  : assert(durationSeconds > 0),
        assert(version >= 1);
}

class AvoraProfileAudioSubmission {
  final String submissionId;

  final String ownerAvoraId;

  final AvoraProfileAudioAsset asset;

  final AvoraProfileAudioReviewStatus reviewStatus;

  /// User confirms they have permission/right to use the audio.
  final bool rightsConfirmed;

  /// Optional licensing/moderation reference.
  final String? rightsOrLicenseReference;

  final String? reviewerAvoraId;

  final String? reviewReason;

  final DateTime submittedAt;

  final DateTime? approvedAt;

  final DateTime? approvalExpiresAt;

  const AvoraProfileAudioSubmission({
    required this.submissionId,
    required this.ownerAvoraId,
    required this.asset,
    required this.reviewStatus,
    required this.rightsConfirmed,
    required this.submittedAt,
    this.rightsOrLicenseReference,
    this.reviewerAvoraId,
    this.reviewReason,
    this.approvedAt,
    this.approvalExpiresAt,
  });

  bool approvedAtTime(DateTime now) {
    if (reviewStatus != AvoraProfileAudioReviewStatus.approved) {
      return false;
    }

    final expiry = approvalExpiresAt;

    if (expiry != null && !now.isBefore(expiry)) {
      return false;
    }

    return true;
  }
}

class AvoraProfileAudioEntitlement {
  final String entitlementId;

  final String ownerAvoraId;

  final AvoraProfileAudioEntitlementSource source;

  final DateTime startsAt;

  final DateTime? expiresAt;

  final bool revoked;

  final String? sourceReference;

  const AvoraProfileAudioEntitlement({
    required this.entitlementId,
    required this.ownerAvoraId,
    required this.source,
    required this.startsAt,
    required this.revoked,
    this.expiresAt,
    this.sourceReference,
  });

  bool activeAt(DateTime now) {
    if (revoked || now.isBefore(startsAt)) {
      return false;
    }

    final expiry = expiresAt;

    if (expiry != null && !now.isBefore(expiry)) {
      return false;
    }

    return true;
  }
}

class AvoraProfileAudioPolicy {
  final bool enabled;

  /// Maximum uploaded/approved profile audio clip length.
  final int maximumAudioDurationSeconds;

  /// Whether AVORA may attempt autoplay when all other
  /// platform/user conditions also allow it.
  final bool allowAutoplay;

  /// Whether paid profile-audio entitlements are enabled.
  final bool allowPurchaseEntitlements;

  const AvoraProfileAudioPolicy({
    required this.maximumAudioDurationSeconds,
    this.enabled = true,
    this.allowAutoplay = true,
    this.allowPurchaseEntitlements = true,
  }) : assert(maximumAudioDurationSeconds > 0);
}

class AvoraProfileAudioUserPreference {
  final String userAvoraId;

  /// Listener preference, not profile-owner authority.
  final bool profileAudioMuted;

  final bool allowProfileAudioAutoplay;

  const AvoraProfileAudioUserPreference({
    required this.userAvoraId,
    this.profileAudioMuted = false,
    this.allowProfileAudioAutoplay = true,
  });
}

class AvoraProfileAudioActivationDecision {
  final bool allowed;

  final String? reason;

  const AvoraProfileAudioActivationDecision({
    required this.allowed,
    required this.reason,
  });
}

class AvoraProfileAudioPlaybackDecision {
  final AvoraProfileAudioPlaybackAction action;

  final String? audioAssetRef;

  final int assetVersion;

  const AvoraProfileAudioPlaybackDecision({
    required this.action,
    required this.audioAssetRef,
    required this.assetVersion,
  });

  bool get shouldPlay => action == AvoraProfileAudioPlaybackAction.play;
}

class AvoraProfileAudioHistoricalReference {
  final String eventId;

  final String ownerAvoraId;

  final String assetId;

  final int assetVersion;

  final DateTime occurredAt;

  const AvoraProfileAudioHistoricalReference({
    required this.eventId,
    required this.ownerAvoraId,
    required this.assetId,
    required this.assetVersion,
    required this.occurredAt,
  }) : assert(assetVersion >= 1);
}

class AvoraProfileAudioEngine {
  const AvoraProfileAudioEngine._();

  static AvoraProfileAudioActivationDecision evaluateActivation({
    required AvoraProfileAudioSubmission submission,
    required AvoraProfileAudioEntitlement entitlement,
    required AvoraProfileAudioPolicy policy,
    required DateTime now,
  }) {
    if (!policy.enabled) {
      return const AvoraProfileAudioActivationDecision(
        allowed: false,
        reason: 'feature_disabled',
      );
    }

    if (submission.ownerAvoraId != entitlement.ownerAvoraId ||
        submission.asset.ownerAvoraId != entitlement.ownerAvoraId) {
      return const AvoraProfileAudioActivationDecision(
        allowed: false,
        reason: 'owner_mismatch',
      );
    }

    if (!entitlement.activeAt(now)) {
      return const AvoraProfileAudioActivationDecision(
        allowed: false,
        reason: 'entitlement_inactive',
      );
    }

    if (!submission.approvedAtTime(now)) {
      return const AvoraProfileAudioActivationDecision(
        allowed: false,
        reason: 'asset_not_approved',
      );
    }

    if (!submission.rightsConfirmed) {
      return const AvoraProfileAudioActivationDecision(
        allowed: false,
        reason: 'rights_not_confirmed',
      );
    }

    if (submission.asset.durationSeconds > policy.maximumAudioDurationSeconds) {
      return const AvoraProfileAudioActivationDecision(
        allowed: false,
        reason: 'audio_too_long',
      );
    }

    if (entitlement.source == AvoraProfileAudioEntitlementSource.purchase &&
        !policy.allowPurchaseEntitlements) {
      return const AvoraProfileAudioActivationDecision(
        allowed: false,
        reason: 'purchase_entitlement_disabled',
      );
    }

    return const AvoraProfileAudioActivationDecision(
      allowed: true,
      reason: null,
    );
  }

  static AvoraProfileAudioPlaybackDecision resolvePlayback({
    required AvoraProfileAudioSubmission submission,
    required AvoraProfileAudioEntitlement entitlement,
    required AvoraProfileAudioPolicy policy,
    required AvoraProfileAudioUserPreference listenerPreference,
    required bool platformAllowsAudioPlayback,
    required bool platformAllowsAutoplay,
    required DateTime now,
  }) {
    final activation = evaluateActivation(
      submission: submission,
      entitlement: entitlement,
      policy: policy,
      now: now,
    );

    if (!activation.allowed) {
      final action = activation.reason == 'feature_disabled'
          ? AvoraProfileAudioPlaybackAction.featureDisabled
          : activation.reason == 'entitlement_inactive'
              ? AvoraProfileAudioPlaybackAction.entitlementInactive
              : AvoraProfileAudioPlaybackAction.assetNotApproved;

      return AvoraProfileAudioPlaybackDecision(
        action: action,
        audioAssetRef: null,
        assetVersion: submission.asset.version,
      );
    }

    if (listenerPreference.profileAudioMuted) {
      return AvoraProfileAudioPlaybackDecision(
        action: AvoraProfileAudioPlaybackAction.mutedByUser,
        audioAssetRef: submission.asset.audioAssetRef,
        assetVersion: submission.asset.version,
      );
    }

    if (!platformAllowsAudioPlayback) {
      return AvoraProfileAudioPlaybackDecision(
        action: AvoraProfileAudioPlaybackAction.blockedByPlatform,
        audioAssetRef: submission.asset.audioAssetRef,
        assetVersion: submission.asset.version,
      );
    }

    final mayAutoplay = policy.allowAutoplay &&
        listenerPreference.allowProfileAudioAutoplay &&
        platformAllowsAutoplay;

    if (!mayAutoplay) {
      return AvoraProfileAudioPlaybackDecision(
        action: AvoraProfileAudioPlaybackAction.availableButDoNotAutoplay,
        audioAssetRef: submission.asset.audioAssetRef,
        assetVersion: submission.asset.version,
      );
    }

    return AvoraProfileAudioPlaybackDecision(
      action: AvoraProfileAudioPlaybackAction.play,
      audioAssetRef: submission.asset.audioAssetRef,
      assetVersion: submission.asset.version,
    );
  }

  /// Profile audio is independent from Room/PK/Live media buses.
  static bool profileAudioMuteAlsoMutesRoomAudio() {
    return false;
  }

  static bool profileAudioIsRoomMusicBus() {
    return false;
  }

  static bool profileAudioIsGiftAudio() {
    return false;
  }

  /// Vanity UID changes never transfer entitlement ownership.
  static bool vanityUidOwnsProfileAudioEntitlement() {
    return false;
  }

  /// Upload alone never publishes/activates profile audio.
  static bool uploadImmediatelyActivatesProfileAudio() {
    return false;
  }

  /// Historical audit/version references never silently move
  /// to the latest asset version.
  static bool historicalReferenceUsesLatestVersionRetroactively() {
    return false;
  }
}
