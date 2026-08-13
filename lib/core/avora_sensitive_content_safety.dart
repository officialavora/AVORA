import 'avora_hidden_identity_abuse.dart';

enum AvoraSensitiveContentCategory {
  none,
  selfHarm,
  suicideAttempt,
  graphicViolence,
  physicalAssault,
  bloodGore,
  dangerousAct,
  tobaccoSmoking,
  hookahShisha,
  vapingNicotine,
  distressAudio,
  custom,
}

enum AvoraSensitiveContentSurface {
  live,
  livePk,
  roomAudio,
  roomVideo,
  privateAudioCall,
  privateVideoCall,
  profileImage,
  postMedia,
  comment,
  caption,
}

enum AvoraSensitiveContentContext {
  ordinary,
  helpSeeking,
  recovery,
  prevention,
  educational,
  news,
  fictional,
  staged,
  sports,
  comedy,
  medical,
  unknown,
}

enum AvoraSensitiveSafetyState {
  normal,
  caution,
  restricted,
  blocked,
  safetyReview,
}

enum AvoraSensitiveSafetyReason {
  none,
  imminentSelfHarm,
  graphicSelfHarm,
  graphicViolence,
  bloodOrGore,
  physicalAssault,
  dangerousAct,
  distressAudio,
  tobaccoAgeGate,
  tobaccoDiscoveryRestricted,
  tobaccoCommerceRestricted,
  profileGraphicMedia,
  privateCallPrivacyGateClosed,
  authoritativeIdentityBindingMissing,
  contextualMitigation,
  manualReviewRequired,
}

class AvoraSensitiveContentPolicy {
  const AvoraSensitiveContentPolicy({
    required this.policyVersion,
    required this.cautionThresholdBps,
    required this.restrictThresholdBps,
    required this.reviewThresholdBps,
    required this.tobaccoMinimumAge,
    required this.tobaccoDiscoveryAllowedForVerifiedAdults,
    required this.tobaccoCommerceEnabled,
    required this.privateCallSafetyAnalysisEnabled,
  });

  final String policyVersion;

  final int cautionThresholdBps;
  final int restrictThresholdBps;
  final int reviewThresholdBps;

  /// Country/product policy value, not a hardcoded global legal claim.
  final int tobaccoMinimumAge;

  final bool tobaccoDiscoveryAllowedForVerifiedAdults;

  /// Safe launch default should remain false unless a future compliant
  /// jurisdiction/provider implementation explicitly enables it.
  final bool tobaccoCommerceEnabled;

  /// Even when enabled, private-call analysis still needs privacy/consent gate.
  final bool privateCallSafetyAnalysisEnabled;

  bool get valid =>
      policyVersion.trim().isNotEmpty &&
      cautionThresholdBps >= 0 &&
      restrictThresholdBps >= cautionThresholdBps &&
      reviewThresholdBps >= restrictThresholdBps &&
      reviewThresholdBps <= 10000 &&
      tobaccoMinimumAge > 0;
}

class AvoraPrivateCallSafetyPrivacy {
  const AvoraPrivateCallSafetyPrivacy({
    required this.explicitConsentGranted,
    required this.legallyAllowed,
    required this.participantReportSubmitted,
  });

  final bool explicitConsentGranted;
  final bool legallyAllowed;

  /// A participant report may route content to safety handling even when
  /// continuous automatic analysis is not enabled.
  final bool participantReportSubmitted;

  bool automaticAnalysisAllowed({
    required AvoraSensitiveContentPolicy policy,
  }) =>
      policy.privateCallSafetyAnalysisEnabled &&
      explicitConsentGranted &&
      legallyAllowed;

  bool safetyReviewMayProceed({
    required AvoraSensitiveContentPolicy policy,
  }) =>
      participantReportSubmitted || automaticAnalysisAllowed(policy: policy);
}

class AvoraSensitiveContentSignal {
  const AvoraSensitiveContentSignal({
    required this.category,
    required this.surface,
    required this.context,
    required this.confidenceBps,
    required this.imminentRisk,
    required this.graphic,
    required this.repeatedViolationCount,
    required this.viewerAge,
    required this.viewerAgeVerified,
    required this.countryAllowsAdultTobaccoDepiction,
  });

  final AvoraSensitiveContentCategory category;
  final AvoraSensitiveContentSurface surface;
  final AvoraSensitiveContentContext context;

  /// 0..10000 from trusted moderation/provider evidence.
  final int confidenceBps;

  /// Strong real-time indication of immediate danger.
  final bool imminentRisk;

  final bool graphic;

  final int repeatedViolationCount;

  /// Optional viewer age for age-gated content decisions.
  final int? viewerAge;
  final bool viewerAgeVerified;

  final bool countryAllowsAdultTobaccoDepiction;

  bool get valid =>
      confidenceBps >= 0 &&
      confidenceBps <= 10000 &&
      repeatedViolationCount >= 0;
}

class AvoraSensitiveSafetyDecision {
  const AvoraSensitiveSafetyDecision({
    required this.state,
    required this.reasons,
    required this.policyVersion,
    required this.immutableAvoraId,
    required this.requestExistingLiveSafetyInterrupt,
    required this.disableDiscovery,
    required this.disableRanking,
    required this.disableClippingOrReplay,
    required this.blurSensitiveMedia,
    required this.blockMediaUpload,
    required this.requireAgeGate,
    required this.allowTobaccoCommerce,
    required this.auditRequired,
    required this.manualReviewRequired,
  });

  final AvoraSensitiveSafetyState state;
  final Set<AvoraSensitiveSafetyReason> reasons;

  final String policyVersion;
  final String immutableAvoraId;

  /// Existing Live Safety infrastructure performs the actual interruption.
  final bool requestExistingLiveSafetyInterrupt;

  final bool disableDiscovery;
  final bool disableRanking;
  final bool disableClippingOrReplay;

  final bool blurSensitiveMedia;
  final bool blockMediaUpload;

  final bool requireAgeGate;

  final bool allowTobaccoCommerce;

  final bool auditRequired;
  final bool manualReviewRequired;
}

class AvoraSensitiveContentSafetyEngine {
  const AvoraSensitiveContentSafetyEngine._();

  static AvoraSensitiveSafetyDecision evaluate({
    required AvoraSensitiveContentSignal signal,
    required AvoraSensitiveContentPolicy policy,
    required AvoraModerationSessionIdentity? sessionIdentity,
    AvoraPrivateCallSafetyPrivacy? privateCallPrivacy,
  }) {
    final reasons = <AvoraSensitiveSafetyReason>{};

    AvoraSensitiveSafetyDecision result({
      required AvoraSensitiveSafetyState state,
      bool interrupt = false,
      bool deamplify = false,
      bool blur = false,
      bool blockUpload = false,
      bool ageGate = false,
      bool allowTobaccoCommerce = false,
      bool review = false,
      bool audit = true,
    }) {
      return AvoraSensitiveSafetyDecision(
        state: state,
        reasons: Set.unmodifiable(
          reasons.isEmpty ? {AvoraSensitiveSafetyReason.none} : reasons,
        ),
        policyVersion: policy.policyVersion,
        immutableAvoraId: sessionIdentity?.immutableAvoraId.trim() ?? '',
        requestExistingLiveSafetyInterrupt: interrupt,
        disableDiscovery: deamplify,
        disableRanking: deamplify,
        disableClippingOrReplay: deamplify,
        blurSensitiveMedia: blur,
        blockMediaUpload: blockUpload,
        requireAgeGate: ageGate,
        allowTobaccoCommerce: allowTobaccoCommerce,
        auditRequired: audit,
        manualReviewRequired: review,
      );
    }

    if (!signal.valid || !policy.valid) {
      reasons.add(AvoraSensitiveSafetyReason.manualReviewRequired);
      return result(
        state: AvoraSensitiveSafetyState.safetyReview,
        review: true,
      );
    }

    final isPrivateCall =
        signal.surface == AvoraSensitiveContentSurface.privateAudioCall ||
            signal.surface == AvoraSensitiveContentSurface.privateVideoCall;

    if (isPrivateCall) {
      final privacy = privateCallPrivacy;

      if (privacy == null || !privacy.safetyReviewMayProceed(policy: policy)) {
        reasons.add(
          AvoraSensitiveSafetyReason.privateCallPrivacyGateClosed,
        );

        return result(
          state: AvoraSensitiveSafetyState.normal,
          audit: false,
        );
      }
    }

    final contextualMitigation = _contextMitigatesPunishment(
      signal.context,
    );

    if (contextualMitigation) {
      reasons.add(AvoraSensitiveSafetyReason.contextualMitigation);
    }

    final isPublicLive = signal.surface == AvoraSensitiveContentSurface.live ||
        signal.surface == AvoraSensitiveContentSurface.livePk;

    final isProfileMedia =
        signal.surface == AvoraSensitiveContentSurface.profileImage;

    final identityRequired = isPublicLive ||
        isProfileMedia ||
        signal.confidenceBps >= policy.restrictThresholdBps;

    if (identityRequired &&
        (sessionIdentity == null || !sessionIdentity.valid)) {
      reasons.add(
        AvoraSensitiveSafetyReason.authoritativeIdentityBindingMissing,
      );

      return result(
        state: AvoraSensitiveSafetyState.safetyReview,
        review: true,
      );
    }

    if (_isTobacco(signal.category)) {
      final age = signal.viewerAge != null &&
          signal.viewerAgeVerified &&
          signal.viewerAge! >= policy.tobaccoMinimumAge;

      if (!age) {
        reasons.add(AvoraSensitiveSafetyReason.tobaccoAgeGate);

        return result(
          state: AvoraSensitiveSafetyState.restricted,
          ageGate: true,
          allowTobaccoCommerce: false,
        );
      }

      final discoveryAllowed =
          policy.tobaccoDiscoveryAllowedForVerifiedAdults &&
              signal.countryAllowsAdultTobaccoDepiction;

      if (!discoveryAllowed) {
        reasons.add(
          AvoraSensitiveSafetyReason.tobaccoDiscoveryRestricted,
        );
      }

      if (!policy.tobaccoCommerceEnabled) {
        reasons.add(
          AvoraSensitiveSafetyReason.tobaccoCommerceRestricted,
        );
      }

      return result(
        state: discoveryAllowed
            ? AvoraSensitiveSafetyState.caution
            : AvoraSensitiveSafetyState.restricted,
        deamplify: !discoveryAllowed,
        allowTobaccoCommerce: policy.tobaccoCommerceEnabled,
      );
    }

    if (signal.category == AvoraSensitiveContentCategory.distressAudio) {
      reasons.add(AvoraSensitiveSafetyReason.distressAudio);

      if (signal.imminentRisk &&
          signal.confidenceBps >= policy.reviewThresholdBps) {
        reasons.add(
          AvoraSensitiveSafetyReason.imminentSelfHarm,
        );

        return result(
          state: AvoraSensitiveSafetyState.safetyReview,
          interrupt: isPublicLive,
          deamplify: isPublicLive,
          review: true,
        );
      }

      /// Crying, noise, or vague distress alone is not punishment evidence.
      return result(
        state: signal.confidenceBps >= policy.cautionThresholdBps
            ? AvoraSensitiveSafetyState.caution
            : AvoraSensitiveSafetyState.normal,
        audit: signal.confidenceBps >= policy.cautionThresholdBps,
      );
    }

    if (signal.category == AvoraSensitiveContentCategory.selfHarm ||
        signal.category == AvoraSensitiveContentCategory.suicideAttempt) {
      if (signal.imminentRisk) {
        reasons.add(AvoraSensitiveSafetyReason.imminentSelfHarm);

        return result(
          state: AvoraSensitiveSafetyState.safetyReview,
          interrupt: isPublicLive,
          deamplify: isPublicLive,
          blur: signal.graphic,
          blockUpload: isProfileMedia && signal.graphic,
          review: true,
        );
      }

      if (signal.graphic) {
        reasons.add(AvoraSensitiveSafetyReason.graphicSelfHarm);

        if (isProfileMedia) {
          reasons.add(
            AvoraSensitiveSafetyReason.profileGraphicMedia,
          );
        }

        return result(
          state: contextualMitigation
              ? AvoraSensitiveSafetyState.restricted
              : AvoraSensitiveSafetyState.blocked,
          deamplify: isPublicLive,
          blur: true,
          blockUpload: isProfileMedia && !contextualMitigation,
          review: true,
        );
      }
    }

    if (signal.category == AvoraSensitiveContentCategory.graphicViolence ||
        signal.category == AvoraSensitiveContentCategory.physicalAssault ||
        signal.category == AvoraSensitiveContentCategory.bloodGore) {
      if (signal.category == AvoraSensitiveContentCategory.graphicViolence) {
        reasons.add(
          AvoraSensitiveSafetyReason.graphicViolence,
        );
      }

      if (signal.category == AvoraSensitiveContentCategory.physicalAssault) {
        reasons.add(
          AvoraSensitiveSafetyReason.physicalAssault,
        );
      }

      if (signal.category == AvoraSensitiveContentCategory.bloodGore) {
        reasons.add(AvoraSensitiveSafetyReason.bloodOrGore);
      }

      if (isProfileMedia && signal.graphic) {
        reasons.add(
          AvoraSensitiveSafetyReason.profileGraphicMedia,
        );
      }

      final highConfidence =
          signal.confidenceBps >= policy.restrictThresholdBps;

      if (highConfidence && !contextualMitigation) {
        return result(
          state: signal.graphic
              ? AvoraSensitiveSafetyState.blocked
              : AvoraSensitiveSafetyState.restricted,
          interrupt: isPublicLive,
          deamplify: isPublicLive,
          blur: signal.graphic,
          blockUpload: isProfileMedia && signal.graphic,
          review: signal.graphic,
        );
      }

      return result(
        state: AvoraSensitiveSafetyState.caution,
        blur: signal.graphic,
        deamplify: isPublicLive && signal.graphic,
      );
    }

    if (signal.category == AvoraSensitiveContentCategory.dangerousAct) {
      reasons.add(AvoraSensitiveSafetyReason.dangerousAct);

      if (signal.confidenceBps >= policy.reviewThresholdBps &&
          !contextualMitigation) {
        return result(
          state: AvoraSensitiveSafetyState.safetyReview,
          interrupt: isPublicLive,
          deamplify: isPublicLive,
          review: true,
        );
      }

      return result(
        state: AvoraSensitiveSafetyState.caution,
      );
    }

    if (signal.confidenceBps >= policy.reviewThresholdBps &&
        !contextualMitigation) {
      reasons.add(
        AvoraSensitiveSafetyReason.manualReviewRequired,
      );

      return result(
        state: AvoraSensitiveSafetyState.safetyReview,
        review: true,
      );
    }

    if (signal.confidenceBps >= policy.restrictThresholdBps &&
        !contextualMitigation) {
      return result(
        state: AvoraSensitiveSafetyState.restricted,
      );
    }

    if (signal.confidenceBps >= policy.cautionThresholdBps) {
      return result(
        state: AvoraSensitiveSafetyState.caution,
      );
    }

    return result(
      state: AvoraSensitiveSafetyState.normal,
      audit: false,
    );
  }

  static bool _contextMitigatesPunishment(
    AvoraSensitiveContentContext context,
  ) {
    switch (context) {
      case AvoraSensitiveContentContext.helpSeeking:
      case AvoraSensitiveContentContext.recovery:
      case AvoraSensitiveContentContext.prevention:
      case AvoraSensitiveContentContext.educational:
      case AvoraSensitiveContentContext.news:
      case AvoraSensitiveContentContext.fictional:
      case AvoraSensitiveContentContext.staged:
      case AvoraSensitiveContentContext.sports:
      case AvoraSensitiveContentContext.comedy:
      case AvoraSensitiveContentContext.medical:
        return true;

      case AvoraSensitiveContentContext.ordinary:
      case AvoraSensitiveContentContext.unknown:
        return false;
    }
  }

  static bool _isTobacco(
    AvoraSensitiveContentCategory category,
  ) =>
      category == AvoraSensitiveContentCategory.tobaccoSmoking ||
      category == AvoraSensitiveContentCategory.hookahShisha ||
      category == AvoraSensitiveContentCategory.vapingNicotine;

  /// Existing moderation/enforcement infrastructure executes restrictions.
  static bool directlyBansAccount() => false;

  /// Existing live-safety engine performs actual stream interruption.
  static bool existingLiveSafetyInterruptRemainsAuthoritative() => true;

  /// Existing audit infrastructure stores the authoritative incident record.
  static bool existingSafetyAuditRemainsAuthoritative() => true;

  /// Existing warning/notification infrastructure presents user notices.
  static bool existingContentWarningSystemRemainsAuthoritative() => true;

  /// X31 session binding keeps immutable AVORA ID authoritative even if UI ID
  /// is hidden, anonymous, broken, or manipulated.
  static bool hiddenUiCanBypassSafetyIdentityBinding() => false;

  static bool singleAiSignalCanCausePermanentBan() => false;

  static bool uncertainCryingOrNoiseCanCauseBan() => false;

  static bool safetyInterventionEqualsAccountPunishment() => false;

  static bool policySnapshotMustBeVersioned() => true;

  static bool historicalSafetyPolicyCanBeSilentlyRewritten() => false;

  static bool privateCallsAreBlanketMonitoredByDefault() => false;

  static bool tobaccoIsSameSeverityAsImminentSelfHarm() => false;

  static bool tobaccoCommerceEnabledByDefault() => false;
}
