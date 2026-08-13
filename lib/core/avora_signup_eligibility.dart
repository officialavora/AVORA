enum AvoraAdultVerificationStatus {
  notStarted,
  pending,
  verifiedAdult,
  underage,
  livenessFailed,
  identityMismatch,
  manualReview,
}

enum AvoraSignupEligibilityAction {
  allowCreateAvoraId,
  requireLiveVerification,
  retryLiveVerification,
  rejectUnderage,
  rejectInvalidDob,
  manualReview,
}

class AvoraAdultSignupPolicy {
  /// AVORA launch default: adults only.
  /// May later be overridden by country/versioned policy.
  final int minimumAge;

  /// Failed/uncertain camera verification attempts
  /// before manual review.
  final int maxVerificationAttempts;

  final bool requireLiveVerification;

  const AvoraAdultSignupPolicy({
    this.minimumAge = 18,
    this.maxVerificationAttempts = 2,
    this.requireLiveVerification = true,
  })  : assert(minimumAge >= 18),
        assert(maxVerificationAttempts > 0);
}

class AvoraSignupAgeInput {
  /// Entered once during signup.
  final DateTime dateOfBirth;

  final String? countryCode;

  /// Result from trusted server/provider verification.
  final AvoraAdultVerificationStatus verificationStatus;

  /// Number of completed failed/uncertain verification attempts.
  final int verificationAttempts;

  const AvoraSignupAgeInput({
    required this.dateOfBirth,
    this.countryCode,
    this.verificationStatus = AvoraAdultVerificationStatus.notStarted,
    this.verificationAttempts = 0,
  }) : assert(verificationAttempts >= 0);

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

class AvoraSignupEligibilityDecision {
  final bool canCreateAvoraId;

  final AvoraSignupEligibilityAction action;

  final String reason;

  final bool requiresHumanReview;

  const AvoraSignupEligibilityDecision({
    required this.canCreateAvoraId,
    required this.action,
    required this.reason,
    this.requiresHumanReview = false,
  });
}

class AvoraAdultSignupGate {
  const AvoraAdultSignupGate._();

  static AvoraSignupEligibilityDecision evaluate({
    required AvoraSignupAgeInput input,
    required DateTime now,
    AvoraAdultSignupPolicy policy = const AvoraAdultSignupPolicy(),
  }) {
    if (input.dateOfBirth.isAfter(now)) {
      return const AvoraSignupEligibilityDecision(
        canCreateAvoraId: false,
        action: AvoraSignupEligibilityAction.rejectInvalidDob,
        reason: 'invalid_date_of_birth',
      );
    }

    final age = input.ageAt(now);

    if (age < policy.minimumAge ||
        input.verificationStatus == AvoraAdultVerificationStatus.underage) {
      return const AvoraSignupEligibilityDecision(
        canCreateAvoraId: false,
        action: AvoraSignupEligibilityAction.rejectUnderage,
        reason: 'adult_age_required',
      );
    }

    if (!policy.requireLiveVerification) {
      return const AvoraSignupEligibilityDecision(
        canCreateAvoraId: true,
        action: AvoraSignupEligibilityAction.allowCreateAvoraId,
        reason: 'adult_age_eligible',
      );
    }

    switch (input.verificationStatus) {
      case AvoraAdultVerificationStatus.verifiedAdult:
        return const AvoraSignupEligibilityDecision(
          canCreateAvoraId: true,
          action: AvoraSignupEligibilityAction.allowCreateAvoraId,
          reason: 'adult_verified',
        );

      case AvoraAdultVerificationStatus.notStarted:
      case AvoraAdultVerificationStatus.pending:
        return const AvoraSignupEligibilityDecision(
          canCreateAvoraId: false,
          action: AvoraSignupEligibilityAction.requireLiveVerification,
          reason: 'live_adult_verification_required',
        );

      case AvoraAdultVerificationStatus.livenessFailed:
      case AvoraAdultVerificationStatus.identityMismatch:
        if (input.verificationAttempts < policy.maxVerificationAttempts) {
          return const AvoraSignupEligibilityDecision(
            canCreateAvoraId: false,
            action: AvoraSignupEligibilityAction.retryLiveVerification,
            reason: 'verification_retry_required',
          );
        }

        return const AvoraSignupEligibilityDecision(
          canCreateAvoraId: false,
          action: AvoraSignupEligibilityAction.manualReview,
          reason: 'verification_review_required',
          requiresHumanReview: true,
        );

      case AvoraAdultVerificationStatus.manualReview:
        return const AvoraSignupEligibilityDecision(
          canCreateAvoraId: false,
          action: AvoraSignupEligibilityAction.manualReview,
          reason: 'manual_review_pending',
          requiresHumanReview: true,
        );

      case AvoraAdultVerificationStatus.underage:
        return const AvoraSignupEligibilityDecision(
          canCreateAvoraId: false,
          action: AvoraSignupEligibilityAction.rejectUnderage,
          reason: 'adult_age_required',
        );
    }
  }
}
