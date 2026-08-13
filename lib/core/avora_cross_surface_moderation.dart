enum AvoraModerationSurface {
  roomText,
  roomAnnouncement,
  inbox,
  profile,
  externalLink,
  roomImage,
  roomVideo,
  microphone,
  musicAudio,
  liveVideo,
  personalVideoCall,
  frontCamera,
  backCamera,
}

enum AvoraModerationModality {
  text,
  link,
  image,
  qrCode,
  audio,
  video,
  camera,
  mixed,
}

enum AvoraCrossSurfaceViolation {
  externalAppPromotion,
  repeatedSolicitation,
  spam,
  abusiveLanguage,
  harassment,
  sexualMisconduct,
  unsafeMedia,
  fraudPromotion,
  filterEvasion,
  other,
}

enum AvoraModerationEvidenceSource {
  textClassifier,
  linkParser,
  qrVision,
  imageVision,
  speechRecognition,
  audioClassifier,
  videoVision,
  userReport,
  moderatorReview,
}

enum AvoraCrossSurfaceAction {
  allow,
  queueForReview,
  warning,
  removeContent,
  disableLink,
  stopAudio,
  stopVideo,
  temporaryMute,
  kickFromRoom,
  temporaryRestriction,
  escalateForManualReview,
}

class AvoraCrossSurfaceModerationConfig {
  /// Confidence values use basis points:
  /// 5000 = 50%, 10000 = 100%.
  final int reviewThresholdBps;
  final int warningThresholdBps;
  final int contentStopThresholdBps;
  final int restrictionThresholdBps;
  final int severeThresholdBps;

  final int repeatRestrictionCount;
  final int repeatEscalationCount;

  const AvoraCrossSurfaceModerationConfig({
    this.reviewThresholdBps = 3500,
    this.warningThresholdBps = 5000,
    this.contentStopThresholdBps = 7000,
    this.restrictionThresholdBps = 8500,
    this.severeThresholdBps = 9500,
    this.repeatRestrictionCount = 3,
    this.repeatEscalationCount = 5,
  })  : assert(reviewThresholdBps >= 0),
        assert(warningThresholdBps >= reviewThresholdBps),
        assert(contentStopThresholdBps >= warningThresholdBps),
        assert(restrictionThresholdBps >= contentStopThresholdBps),
        assert(severeThresholdBps >= restrictionThresholdBps),
        assert(severeThresholdBps <= 10000),
        assert(repeatRestrictionCount > 0),
        assert(repeatEscalationCount >= repeatRestrictionCount);
}

class AvoraCrossSurfaceSignal {
  final String eventId;
  final String userAvoraId;

  final AvoraModerationSurface surface;
  final AvoraModerationModality modality;
  final AvoraCrossSurfaceViolation violation;

  final Set<AvoraModerationEvidenceSource> evidenceSources;

  final int confidenceBps;

  /// Previous relevant confirmed/high-confidence incidents.
  final int repeatCount;

  final bool humanConfirmed;
  final bool coordinatedAbuse;
  final bool fraudulentIntent;

  const AvoraCrossSurfaceSignal({
    required this.eventId,
    required this.userAvoraId,
    required this.surface,
    required this.modality,
    required this.violation,
    required this.evidenceSources,
    required this.confidenceBps,
    this.repeatCount = 0,
    this.humanConfirmed = false,
    this.coordinatedAbuse = false,
    this.fraudulentIntent = false,
  })  : assert(confidenceBps >= 0 && confidenceBps <= 10000),
        assert(repeatCount >= 0);
}

class AvoraPromotionExceptionContext {
  final bool approvedPartner;
  final bool officialCampaign;
  final bool whitelistedDomain;
  final bool authorizedSupportOrBusinessContact;

  const AvoraPromotionExceptionContext({
    this.approvedPartner = false,
    this.officialCampaign = false,
    this.whitelistedDomain = false,
    this.authorizedSupportOrBusinessContact = false,
  });

  bool get hasApprovedException =>
      approvedPartner ||
      officialCampaign ||
      whitelistedDomain ||
      authorizedSupportOrBusinessContact;
}

class AvoraCrossSurfaceDecision {
  final bool violationActionRequired;

  final bool approvedExceptionApplied;

  final Set<AvoraCrossSurfaceAction> actions;

  /// Permanent punishment is intentionally not automatic here.
  final bool requiresAuthorizedPermanentBanReview;

  const AvoraCrossSurfaceDecision({
    required this.violationActionRequired,
    required this.approvedExceptionApplied,
    required this.actions,
    required this.requiresAuthorizedPermanentBanReview,
  });
}

class AvoraCrossSurfaceModerationPolicy {
  const AvoraCrossSurfaceModerationPolicy._();

  static bool _isPromotionViolation(
    AvoraCrossSurfaceViolation violation,
  ) {
    return violation == AvoraCrossSurfaceViolation.externalAppPromotion ||
        violation == AvoraCrossSurfaceViolation.repeatedSolicitation ||
        violation == AvoraCrossSurfaceViolation.fraudPromotion;
  }

  static AvoraCrossSurfaceAction _contentStopAction(
    AvoraModerationModality modality,
  ) {
    switch (modality) {
      case AvoraModerationModality.audio:
        return AvoraCrossSurfaceAction.stopAudio;

      case AvoraModerationModality.video:
      case AvoraModerationModality.camera:
        return AvoraCrossSurfaceAction.stopVideo;

      case AvoraModerationModality.link:
      case AvoraModerationModality.qrCode:
        return AvoraCrossSurfaceAction.disableLink;

      case AvoraModerationModality.text:
      case AvoraModerationModality.image:
      case AvoraModerationModality.mixed:
        return AvoraCrossSurfaceAction.removeContent;
    }
  }

  static AvoraCrossSurfaceDecision evaluate({
    required AvoraCrossSurfaceSignal signal,
    required AvoraCrossSurfaceModerationConfig config,
    required AvoraPromotionExceptionContext promotionException,
  }) {
    if (_isPromotionViolation(signal.violation) &&
        promotionException.hasApprovedException) {
      return const AvoraCrossSurfaceDecision(
        violationActionRequired: false,
        approvedExceptionApplied: true,
        actions: {
          AvoraCrossSurfaceAction.allow,
        },
        requiresAuthorizedPermanentBanReview: false,
      );
    }

    final actions = <AvoraCrossSurfaceAction>{};

    if (signal.confidenceBps < config.reviewThresholdBps &&
        !signal.humanConfirmed) {
      actions.add(AvoraCrossSurfaceAction.allow);

      return AvoraCrossSurfaceDecision(
        violationActionRequired: false,
        approvedExceptionApplied: false,
        actions: Set.unmodifiable(actions),
        requiresAuthorizedPermanentBanReview: false,
      );
    }

    if (signal.confidenceBps < config.warningThresholdBps &&
        !signal.humanConfirmed) {
      actions.add(AvoraCrossSurfaceAction.queueForReview);

      return AvoraCrossSurfaceDecision(
        violationActionRequired: true,
        approvedExceptionApplied: false,
        actions: Set.unmodifiable(actions),
        requiresAuthorizedPermanentBanReview: false,
      );
    }

    actions.add(AvoraCrossSurfaceAction.warning);

    if (signal.confidenceBps >= config.contentStopThresholdBps ||
        signal.humanConfirmed) {
      actions.add(
        _contentStopAction(signal.modality),
      );
    }

    if (signal.confidenceBps >= config.restrictionThresholdBps ||
        signal.repeatCount >= config.repeatRestrictionCount) {
      switch (signal.modality) {
        case AvoraModerationModality.audio:
          actions.add(AvoraCrossSurfaceAction.temporaryMute);

        case AvoraModerationModality.video:
        case AvoraModerationModality.camera:
        case AvoraModerationModality.image:
        case AvoraModerationModality.mixed:
          actions.add(
            AvoraCrossSurfaceAction.temporaryRestriction,
          );

        case AvoraModerationModality.text:
        case AvoraModerationModality.link:
        case AvoraModerationModality.qrCode:
          actions.add(
            AvoraCrossSurfaceAction.temporaryRestriction,
          );
      }
    }

    final severe = signal.confidenceBps >= config.severeThresholdBps &&
        (signal.humanConfirmed ||
            signal.coordinatedAbuse ||
            signal.fraudulentIntent ||
            signal.repeatCount >= config.repeatEscalationCount);

    if (severe) {
      actions.add(
        AvoraCrossSurfaceAction.escalateForManualReview,
      );

      actions.add(
        AvoraCrossSurfaceAction.temporaryRestriction,
      );
    }

    return AvoraCrossSurfaceDecision(
      violationActionRequired: true,
      approvedExceptionApplied: false,
      actions: Set.unmodifiable(actions),
      requiresAuthorizedPermanentBanReview: severe,
    );
  }

  /// Room image/video posting defaults to authorized staff/admin.
  static bool canPostRoomMedia({
    required bool authorizedRoomStaff,
  }) {
    return authorizedRoomStaff;
  }

  /// External microphone, headset, voice changer, music,
  /// radio or audio playback cannot bypass moderation.
  static bool externalAudioMethodBypassesModeration() {
    return false;
  }

  /// Front/back camera are both subject to the same policy.
  static bool cameraDirectionBypassesModeration() {
    return false;
  }

  /// Uncertain automated recognition must never directly
  /// create a permanent ban.
  static bool uncertainAutomationCanPermanentlyBan() {
    return false;
  }

  /// Permanent account enforcement requires appropriate
  /// confidence/evidence and authorized policy review.
  static bool permanentBanRequiresAuthorizedReview() {
    return true;
  }
}
