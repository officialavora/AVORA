enum AvoraSignatureGiftEligibilityType {
  topSender,
  topPurchaser,
  achievement,
  eventWinner,
  vipPrestige,
  adminGranted,
  custom,
}

enum AvoraSignatureGiftAudioType {
  none,
  songClip,
  dialogue,
  shayari,
  voiceLine,
  customSound,
}

enum AvoraSignatureGiftReviewStatus {
  draft,
  submitted,
  underReview,
  approved,
  rejected,
  revoked,
  expired,
}

enum AvoraSignatureGiftPublicationStatus {
  draft,
  active,
  paused,
  retired,
  revoked,
}

enum AvoraSignatureGiftDenyReason {
  none,
  featureDisabled,
  userNotEligible,
  countryNotAllowed,
  eventNotAllowed,
  submissionNotApproved,
  rightsNotConfirmed,
  consentNotConfirmed,
  audioTooLong,
  assetMissing,
  approvalExpired,
  publicationExpired,
  revoked,
}

class AvoraSignatureGiftEligibilityRule {
  final String id;

  final AvoraSignatureGiftEligibilityType type;

  /// Optional rank requirements. Example: Top 1 / Top 10.
  final int? maximumSenderRank;
  final int? maximumPurchaserRank;

  /// Optional server-authoritative milestone/target units.
  final int minimumEligibleUnits;

  /// Empty means not country-restricted at this layer.
  final Set<String> allowedCountryCodes;

  /// Empty means not event-restricted.
  final Set<String> allowedEventIds;

  final DateTime? startsAt;
  final DateTime? endsAt;

  const AvoraSignatureGiftEligibilityRule({
    required this.id,
    required this.type,
    this.maximumSenderRank,
    this.maximumPurchaserRank,
    this.minimumEligibleUnits = 0,
    this.allowedCountryCodes = const {},
    this.allowedEventIds = const {},
    this.startsAt,
    this.endsAt,
  })  : assert(
          maximumSenderRank == null || maximumSenderRank > 0,
        ),
        assert(
          maximumPurchaserRank == null || maximumPurchaserRank > 0,
        ),
        assert(minimumEligibleUnits >= 0);

  bool activeAt(DateTime now) {
    final start = startsAt;

    if (start != null && now.isBefore(start)) {
      return false;
    }

    final end = endsAt;

    if (end != null && !now.isBefore(end)) {
      return false;
    }

    return true;
  }

  bool countryAllowed(String countryCode) {
    if (allowedCountryCodes.isEmpty) {
      return true;
    }

    final normalized = countryCode.trim().toUpperCase();

    return allowedCountryCodes
        .map((value) => value.trim().toUpperCase())
        .contains(normalized);
  }

  bool eventAllowed(String? eventId) {
    if (allowedEventIds.isEmpty) {
      return true;
    }

    if (eventId == null) {
      return false;
    }

    return allowedEventIds.contains(eventId);
  }
}

class AvoraSignatureGiftEligibilityContext {
  final String userAvoraId;

  final String countryCode;

  final String? eventId;

  final int? senderRank;
  final int? purchaserRank;

  final int eligibleUnits;

  final Set<AvoraSignatureGiftEligibilityType> grantedEligibilityTypes;

  const AvoraSignatureGiftEligibilityContext({
    required this.userAvoraId,
    required this.countryCode,
    required this.eventId,
    required this.senderRank,
    required this.purchaserRank,
    required this.eligibleUnits,
    required this.grantedEligibilityTypes,
  }) : assert(eligibleUnits >= 0);
}

class AvoraSignatureGiftEligibilityDecision {
  final bool eligible;
  final AvoraSignatureGiftDenyReason reason;

  const AvoraSignatureGiftEligibilityDecision({
    required this.eligible,
    required this.reason,
  });
}

class AvoraSignatureGiftAssetBundle {
  /// Approved storage/media references only.
  final String? portraitAssetRef;
  final String? giftAnimationAssetRef;
  final String? frameAssetRef;
  final String? entryEffectAssetRef;
  final String? badgeAssetRef;
  final String? titleAssetRef;

  final String? audioAssetRef;

  final AvoraSignatureGiftAudioType audioType;

  /// Zero when there is no audio.
  final int audioDurationSeconds;

  const AvoraSignatureGiftAssetBundle({
    this.portraitAssetRef,
    this.giftAnimationAssetRef,
    this.frameAssetRef,
    this.entryEffectAssetRef,
    this.badgeAssetRef,
    this.titleAssetRef,
    this.audioAssetRef,
    this.audioType = AvoraSignatureGiftAudioType.none,
    this.audioDurationSeconds = 0,
  }) : assert(audioDurationSeconds >= 0);

  bool get hasPrimaryVisual =>
      portraitAssetRef != null || giftAnimationAssetRef != null;

  bool get hasAudio =>
      audioType != AvoraSignatureGiftAudioType.none && audioAssetRef != null;
}

class AvoraSignatureGiftSubmission {
  final String submissionId;

  /// Immutable owner identity.
  final String ownerAvoraId;

  final String requestedGiftName;

  final AvoraSignatureGiftAssetBundle assets;

  final AvoraSignatureGiftReviewStatus reviewStatus;

  /// User confirms they are permitted to submit/use this media.
  final bool rightsConfirmed;

  /// Consent for submitted photo/voice/personality media.
  final bool consentConfirmed;

  /// Optional licensing/review reference.
  final String? rightsOrLicenseReference;

  final DateTime submittedAt;

  final DateTime? approvedAt;

  /// Optional approval expiry.
  final DateTime? approvalExpiresAt;

  final String? reviewerAvoraId;

  /// Safe public/user-facing review reason.
  final String? reviewReason;

  const AvoraSignatureGiftSubmission({
    required this.submissionId,
    required this.ownerAvoraId,
    required this.requestedGiftName,
    required this.assets,
    required this.reviewStatus,
    required this.rightsConfirmed,
    required this.consentConfirmed,
    required this.submittedAt,
    this.approvedAt,
    this.approvalExpiresAt,
    this.rightsOrLicenseReference,
    this.reviewerAvoraId,
    this.reviewReason,
  });

  bool approvedAtTime(DateTime now) {
    if (reviewStatus != AvoraSignatureGiftReviewStatus.approved) {
      return false;
    }

    final expiry = approvalExpiresAt;

    if (expiry != null && !now.isBefore(expiry)) {
      return false;
    }

    return true;
  }
}

class AvoraSignatureGiftPolicy {
  final bool enabled;

  /// Admin-configurable.
  final int maximumAudioDurationSeconds;

  /// Whether approved custom audio is allowed at all.
  final bool allowCustomAudio;

  /// Publication duration is separately configurable per entitlement.
  final int defaultEntitlementDays;

  const AvoraSignatureGiftPolicy({
    required this.maximumAudioDurationSeconds,
    required this.defaultEntitlementDays,
    this.enabled = true,
    this.allowCustomAudio = true,
  })  : assert(maximumAudioDurationSeconds >= 0),
        assert(defaultEntitlementDays > 0);
}

class AvoraSignatureGiftDefinition {
  /// Stable gift identity.
  final String signatureGiftId;

  final String ownerAvoraId;

  final String displayName;

  final AvoraSignatureGiftPublicationStatus publicationStatus;

  /// Latest published version number.
  final int currentVersion;

  final DateTime createdAt;

  final DateTime? publicationExpiresAt;

  const AvoraSignatureGiftDefinition({
    required this.signatureGiftId,
    required this.ownerAvoraId,
    required this.displayName,
    required this.publicationStatus,
    required this.currentVersion,
    required this.createdAt,
    this.publicationExpiresAt,
  }) : assert(currentVersion >= 1);

  bool activeAt(DateTime now) {
    if (publicationStatus != AvoraSignatureGiftPublicationStatus.active) {
      return false;
    }

    final expiry = publicationExpiresAt;

    if (expiry != null && !now.isBefore(expiry)) {
      return false;
    }

    return true;
  }
}

class AvoraSignatureGiftVersion {
  final String signatureGiftId;

  /// Immutable historical version number.
  final int version;

  final AvoraSignatureGiftAssetBundle assets;

  final String sourceSubmissionId;

  final String approvedByAvoraId;

  final DateTime publishedAt;

  final String moderationReference;

  const AvoraSignatureGiftVersion({
    required this.signatureGiftId,
    required this.version,
    required this.assets,
    required this.sourceSubmissionId,
    required this.approvedByAvoraId,
    required this.publishedAt,
    required this.moderationReference,
  }) : assert(version >= 1);
}

class AvoraSignatureGiftPublicationDecision {
  final bool allowed;

  final AvoraSignatureGiftDenyReason reason;

  const AvoraSignatureGiftPublicationDecision({
    required this.allowed,
    required this.reason,
  });
}

class AvoraSignatureGiftHistoricalSendReference {
  final String giftEventId;

  final String signatureGiftId;

  /// Historical sends always retain the exact version used.
  final int signatureGiftVersion;

  final String senderAvoraId;
  final String receiverAvoraId;

  final DateTime sentAt;

  const AvoraSignatureGiftHistoricalSendReference({
    required this.giftEventId,
    required this.signatureGiftId,
    required this.signatureGiftVersion,
    required this.senderAvoraId,
    required this.receiverAvoraId,
    required this.sentAt,
  }) : assert(signatureGiftVersion >= 1);
}

class AvoraSignatureGiftEngine {
  const AvoraSignatureGiftEngine._();

  static AvoraSignatureGiftEligibilityDecision evaluateEligibility({
    required AvoraSignatureGiftEligibilityRule rule,
    required AvoraSignatureGiftEligibilityContext context,
    required DateTime now,
  }) {
    if (!rule.activeAt(now)) {
      return const AvoraSignatureGiftEligibilityDecision(
        eligible: false,
        reason: AvoraSignatureGiftDenyReason.userNotEligible,
      );
    }

    if (!rule.countryAllowed(context.countryCode)) {
      return const AvoraSignatureGiftEligibilityDecision(
        eligible: false,
        reason: AvoraSignatureGiftDenyReason.countryNotAllowed,
      );
    }

    if (!rule.eventAllowed(context.eventId)) {
      return const AvoraSignatureGiftEligibilityDecision(
        eligible: false,
        reason: AvoraSignatureGiftDenyReason.eventNotAllowed,
      );
    }

    if (!context.grantedEligibilityTypes.contains(rule.type)) {
      return const AvoraSignatureGiftEligibilityDecision(
        eligible: false,
        reason: AvoraSignatureGiftDenyReason.userNotEligible,
      );
    }

    final senderLimit = rule.maximumSenderRank;

    if (senderLimit != null) {
      final senderRank = context.senderRank;

      if (senderRank == null || senderRank > senderLimit) {
        return const AvoraSignatureGiftEligibilityDecision(
          eligible: false,
          reason: AvoraSignatureGiftDenyReason.userNotEligible,
        );
      }
    }

    final purchaserLimit = rule.maximumPurchaserRank;

    if (purchaserLimit != null) {
      final purchaserRank = context.purchaserRank;

      if (purchaserRank == null || purchaserRank > purchaserLimit) {
        return const AvoraSignatureGiftEligibilityDecision(
          eligible: false,
          reason: AvoraSignatureGiftDenyReason.userNotEligible,
        );
      }
    }

    if (context.eligibleUnits < rule.minimumEligibleUnits) {
      return const AvoraSignatureGiftEligibilityDecision(
        eligible: false,
        reason: AvoraSignatureGiftDenyReason.userNotEligible,
      );
    }

    return const AvoraSignatureGiftEligibilityDecision(
      eligible: true,
      reason: AvoraSignatureGiftDenyReason.none,
    );
  }

  static AvoraSignatureGiftPublicationDecision evaluatePublication({
    required AvoraSignatureGiftSubmission submission,
    required AvoraSignatureGiftPolicy policy,
    required bool userStillEligible,
    required DateTime now,
  }) {
    if (!policy.enabled) {
      return const AvoraSignatureGiftPublicationDecision(
        allowed: false,
        reason: AvoraSignatureGiftDenyReason.featureDisabled,
      );
    }

    if (!userStillEligible) {
      return const AvoraSignatureGiftPublicationDecision(
        allowed: false,
        reason: AvoraSignatureGiftDenyReason.userNotEligible,
      );
    }

    if (!submission.approvedAtTime(now)) {
      if (submission.reviewStatus == AvoraSignatureGiftReviewStatus.revoked) {
        return const AvoraSignatureGiftPublicationDecision(
          allowed: false,
          reason: AvoraSignatureGiftDenyReason.revoked,
        );
      }

      return const AvoraSignatureGiftPublicationDecision(
        allowed: false,
        reason: AvoraSignatureGiftDenyReason.submissionNotApproved,
      );
    }

    if (!submission.rightsConfirmed) {
      return const AvoraSignatureGiftPublicationDecision(
        allowed: false,
        reason: AvoraSignatureGiftDenyReason.rightsNotConfirmed,
      );
    }

    if (!submission.consentConfirmed) {
      return const AvoraSignatureGiftPublicationDecision(
        allowed: false,
        reason: AvoraSignatureGiftDenyReason.consentNotConfirmed,
      );
    }

    if (!submission.assets.hasPrimaryVisual) {
      return const AvoraSignatureGiftPublicationDecision(
        allowed: false,
        reason: AvoraSignatureGiftDenyReason.assetMissing,
      );
    }

    if (submission.assets.hasAudio) {
      if (!policy.allowCustomAudio) {
        return const AvoraSignatureGiftPublicationDecision(
          allowed: false,
          reason: AvoraSignatureGiftDenyReason.assetMissing,
        );
      }

      if (submission.assets.audioDurationSeconds >
          policy.maximumAudioDurationSeconds) {
        return const AvoraSignatureGiftPublicationDecision(
          allowed: false,
          reason: AvoraSignatureGiftDenyReason.audioTooLong,
        );
      }
    }

    return const AvoraSignatureGiftPublicationDecision(
      allowed: true,
      reason: AvoraSignatureGiftDenyReason.none,
    );
  }

  static AvoraSignatureGiftVersion createPublishedVersion({
    required String signatureGiftId,
    required int version,
    required AvoraSignatureGiftSubmission submission,
    required String approvedByAvoraId,
    required String moderationReference,
    required DateTime publishedAt,
  }) {
    if (submission.reviewStatus != AvoraSignatureGiftReviewStatus.approved) {
      throw StateError(
        'Only an approved submission can be published.',
      );
    }

    return AvoraSignatureGiftVersion(
      signatureGiftId: signatureGiftId,
      version: version,
      assets: submission.assets,
      sourceSubmissionId: submission.submissionId,
      approvedByAvoraId: approvedByAvoraId,
      publishedAt: publishedAt,
      moderationReference: moderationReference,
    );
  }

  /// Signature Gift is separate from Normal/Lucky/Lucky Pocket.
  static bool signatureGiftReplacesNormalGift() {
    return false;
  }

  /// Custom media never bypasses core settlement.
  static bool customGiftBypassesGiftSettlement() {
    return false;
  }

  /// Custom gift never bypasses refund/reversal or fraud controls.
  static bool customGiftBypassesEconomicRiskControls() {
    return false;
  }

  /// Custom audio does not automatically become public on upload.
  static bool userUploadPublishesDirectlyToGiftCatalog() {
    return false;
  }

  /// Historical sends retain the exact published version reference.
  static bool historicalSendUsesLatestVersionRetroactively() {
    return false;
  }

  /// Immutable original AVORA ID remains the owner authority.
  static bool vanityUidOwnsSignatureGift() {
    return false;
  }
}
