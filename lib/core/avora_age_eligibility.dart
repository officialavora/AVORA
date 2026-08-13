enum AvoraAgeAssuranceStatus {
  declared,
  verifiedAdult,
  suspectedMinor,
  confirmedMinor,
}

enum AvoraAgeFeature {
  basicAccount,
  voiceRoom,
  gifting,
  recharge,
  audioPk,
  videoLive,
  videoPk,
  privateAudioCall,
  privateVideoCall,
  hostCreatorMonetization,
  withdrawal,
  luckyGift,
  luckyPocket,
}

enum AvoraAgeEligibilityAction {
  allow,
  requireAgeVerification,
  warnAndRestrictFeature,
  restrictFeature,
  restrictAccount,
}

class AvoraAgeProfile {
  final String userId;

  /// Captured once during account creation.
  final DateTime dateOfBirth;

  final AvoraAgeAssuranceStatus assuranceStatus;

  final String? countryCode;

  final DateTime createdAt;

  /// Last successful trusted age verification.
  final DateTime? verifiedAt;

  const AvoraAgeProfile({
    required this.userId,
    required this.dateOfBirth,
    required this.assuranceStatus,
    required this.createdAt,
    this.countryCode,
    this.verifiedAt,
  });

  int ageAt(DateTime date) {
    var age = date.year - dateOfBirth.year;

    final birthdayPassed = date.month > dateOfBirth.month ||
        (date.month == dateOfBirth.month && date.day >= dateOfBirth.day);

    if (!birthdayPassed) {
      age--;
    }

    return age;
  }
}

class AvoraAgePolicyConfig {
  final int minimumAdultAge;

  final int suspectedMinorWarningLimit;

  final bool requireVerifiedAgeForHighRisk;

  const AvoraAgePolicyConfig({
    this.minimumAdultAge = 18,
    this.suspectedMinorWarningLimit = 2,
    this.requireVerifiedAgeForHighRisk = true,
  })  : assert(minimumAdultAge >= 13),
        assert(suspectedMinorWarningLimit > 0);
}

class AvoraAgeEligibilityDecision {
  final bool allowed;

  final AvoraAgeEligibilityAction action;

  final String reason;

  final bool requiresHumanReview;

  const AvoraAgeEligibilityDecision({
    required this.allowed,
    required this.action,
    required this.reason,
    this.requiresHumanReview = false,
  });
}

class AvoraAgeEligibilityEngine {
  const AvoraAgeEligibilityEngine._();

  static AvoraAgeEligibilityDecision evaluate({
    required AvoraAgeProfile profile,
    required AvoraAgeFeature feature,
    required DateTime now,
    int priorAgeWarnings = 0,
    AvoraAgePolicyConfig config = const AvoraAgePolicyConfig(),
  }) {
    final age = profile.ageAt(now);

    if (profile.assuranceStatus == AvoraAgeAssuranceStatus.confirmedMinor ||
        age < config.minimumAdultAge) {
      return const AvoraAgeEligibilityDecision(
        allowed: false,
        action: AvoraAgeEligibilityAction.restrictAccount,
        reason: 'confirmed_underage',
      );
    }

    if (profile.assuranceStatus == AvoraAgeAssuranceStatus.suspectedMinor) {
      if (priorAgeWarnings < config.suspectedMinorWarningLimit) {
        return const AvoraAgeEligibilityDecision(
          allowed: false,
          action: AvoraAgeEligibilityAction.warnAndRestrictFeature,
          reason: 'suspected_minor_requires_reverification',
        );
      }

      return const AvoraAgeEligibilityDecision(
        allowed: false,
        action: AvoraAgeEligibilityAction.restrictAccount,
        reason: 'repeated_age_risk',
        requiresHumanReview: true,
      );
    }

    if (_isHighRiskFeature(feature) &&
        config.requireVerifiedAgeForHighRisk &&
        profile.assuranceStatus != AvoraAgeAssuranceStatus.verifiedAdult) {
      return const AvoraAgeEligibilityDecision(
        allowed: false,
        action: AvoraAgeEligibilityAction.requireAgeVerification,
        reason: 'verified_age_required',
      );
    }

    return const AvoraAgeEligibilityDecision(
      allowed: true,
      action: AvoraAgeEligibilityAction.allow,
      reason: 'eligible',
    );
  }

  static bool _isHighRiskFeature(
    AvoraAgeFeature feature,
  ) {
    switch (feature) {
      case AvoraAgeFeature.audioPk:
      case AvoraAgeFeature.videoLive:
      case AvoraAgeFeature.videoPk:
      case AvoraAgeFeature.privateAudioCall:
      case AvoraAgeFeature.privateVideoCall:
      case AvoraAgeFeature.hostCreatorMonetization:
      case AvoraAgeFeature.withdrawal:
        return true;

      case AvoraAgeFeature.basicAccount:
      case AvoraAgeFeature.voiceRoom:
      case AvoraAgeFeature.gifting:
      case AvoraAgeFeature.recharge:
      case AvoraAgeFeature.luckyGift:
      case AvoraAgeFeature.luckyPocket:
        return false;
    }
  }
}
