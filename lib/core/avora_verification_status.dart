enum AvoraIdentityVerificationStatus {
  notStarted,
  pending,
  underReview,
  verified,
  rejected,
  reverificationRequired,
  restricted,
}

enum AvoraHostEligibilityStatus {
  notEvaluated,
  pendingReview,
  conditionallyEligible,
  eligible,
  notEligible,
  suspended,
}

enum AvoraHostRequirement {
  verifiedAdultIdentity,
  profileComplete,
  countryPolicyAllows,
  agencyRequirementMet,
  trainingCompleted,
  agreementAccepted,
  riskClear,
  deviceIntegrityPassed,
}

class AvoraIdentityVerificationRecord {
  final String userAvoraId;

  final AvoraIdentityVerificationStatus status;

  /// Adult eligibility result is separate from simple face match.
  final bool adultVerified;

  /// Internal verification-provider reference.
  final String? providerReferenceId;

  final DateTime? submittedAt;
  final DateTime? verifiedAt;
  final DateTime? expiresAt;

  /// Safe text suitable for the user.
  final String? safeStatusMessage;

  final bool retryAllowed;
  final bool appealAllowed;

  const AvoraIdentityVerificationRecord({
    required this.userAvoraId,
    required this.status,
    required this.adultVerified,
    this.providerReferenceId,
    this.submittedAt,
    this.verifiedAt,
    this.expiresAt,
    this.safeStatusMessage,
    this.retryAllowed = false,
    this.appealAllowed = false,
  });

  bool isVerifiedAt(DateTime now) {
    if (status != AvoraIdentityVerificationStatus.verified || !adultVerified) {
      return false;
    }

    final expiry = expiresAt;

    if (expiry != null && !now.isBefore(expiry)) {
      return false;
    }

    return true;
  }
}

class AvoraHostEligibilityConfig {
  final String id;

  final Set<AvoraHostRequirement> requiredRequirements;

  const AvoraHostEligibilityConfig({
    required this.id,
    required this.requiredRequirements,
  });
}

class AvoraHostEligibilityContext {
  final bool profileComplete;
  final bool countryPolicyAllows;
  final bool agencyRequirementMet;
  final bool trainingCompleted;
  final bool agreementAccepted;
  final bool riskClear;
  final bool deviceIntegrityPassed;

  /// Separate explicit suspension state.
  final bool hostingSuspended;

  const AvoraHostEligibilityContext({
    this.profileComplete = false,
    this.countryPolicyAllows = false,
    this.agencyRequirementMet = false,
    this.trainingCompleted = false,
    this.agreementAccepted = false,
    this.riskClear = true,
    this.deviceIntegrityPassed = true,
    this.hostingSuspended = false,
  });
}

class AvoraHostEligibilityResult {
  final AvoraHostEligibilityStatus status;

  final Set<AvoraHostRequirement> missingRequirements;

  /// Safe next-step labels shown to the user.
  final List<String> nextActions;

  const AvoraHostEligibilityResult({
    required this.status,
    required this.missingRequirements,
    required this.nextActions,
  });

  bool get canHost => status == AvoraHostEligibilityStatus.eligible;
}

class AvoraVerificationPresentation {
  final String title;
  final String message;
  final bool showVerifiedBadge;
  final bool showRetry;
  final bool showAppeal;

  const AvoraVerificationPresentation({
    required this.title,
    required this.message,
    required this.showVerifiedBadge,
    required this.showRetry,
    required this.showAppeal,
  });
}

class AvoraVerificationAndHostPolicy {
  const AvoraVerificationAndHostPolicy._();

  static AvoraVerificationPresentation identityPresentation(
    AvoraIdentityVerificationRecord record,
  ) {
    final title = switch (record.status) {
      AvoraIdentityVerificationStatus.notStarted => 'Verification Not Started',
      AvoraIdentityVerificationStatus.pending => 'Verification Pending',
      AvoraIdentityVerificationStatus.underReview => 'Under Review',
      AvoraIdentityVerificationStatus.verified => 'Verified',
      AvoraIdentityVerificationStatus.rejected => 'Verification Failed',
      AvoraIdentityVerificationStatus.reverificationRequired =>
        'Reverification Required',
      AvoraIdentityVerificationStatus.restricted => 'Verification Restricted',
    };

    final defaultMessage = switch (record.status) {
      AvoraIdentityVerificationStatus.notStarted =>
        'Complete identity and face verification.',
      AvoraIdentityVerificationStatus.pending =>
        'Your verification has been submitted.',
      AvoraIdentityVerificationStatus.underReview =>
        'Your verification is being reviewed.',
      AvoraIdentityVerificationStatus.verified =>
        'Your AVORA identity is verified.',
      AvoraIdentityVerificationStatus.rejected =>
        'Verification could not be approved.',
      AvoraIdentityVerificationStatus.reverificationRequired =>
        'Please complete verification again.',
      AvoraIdentityVerificationStatus.restricted =>
        'Verification is currently restricted.',
    };

    return AvoraVerificationPresentation(
      title: title,
      message: record.safeStatusMessage ?? defaultMessage,
      showVerifiedBadge:
          record.status == AvoraIdentityVerificationStatus.verified,
      showRetry: record.retryAllowed,
      showAppeal: record.appealAllowed,
    );
  }

  static AvoraHostEligibilityResult evaluateHostEligibility({
    required AvoraIdentityVerificationRecord identity,
    required AvoraHostEligibilityConfig config,
    required AvoraHostEligibilityContext context,
    required DateTime now,
  }) {
    if (context.hostingSuspended) {
      return const AvoraHostEligibilityResult(
        status: AvoraHostEligibilityStatus.suspended,
        missingRequirements: {},
        nextActions: [
          'Review your Host Center status.',
        ],
      );
    }

    if (identity.status == AvoraIdentityVerificationStatus.pending ||
        identity.status == AvoraIdentityVerificationStatus.underReview) {
      return const AvoraHostEligibilityResult(
        status: AvoraHostEligibilityStatus.pendingReview,
        missingRequirements: {
          AvoraHostRequirement.verifiedAdultIdentity,
        },
        nextActions: [
          'Wait for identity verification to complete.',
        ],
      );
    }

    final missing = <AvoraHostRequirement>{};

    bool satisfied(AvoraHostRequirement requirement) {
      return switch (requirement) {
        AvoraHostRequirement.verifiedAdultIdentity =>
          identity.isVerifiedAt(now),
        AvoraHostRequirement.profileComplete => context.profileComplete,
        AvoraHostRequirement.countryPolicyAllows => context.countryPolicyAllows,
        AvoraHostRequirement.agencyRequirementMet =>
          context.agencyRequirementMet,
        AvoraHostRequirement.trainingCompleted => context.trainingCompleted,
        AvoraHostRequirement.agreementAccepted => context.agreementAccepted,
        AvoraHostRequirement.riskClear => context.riskClear,
        AvoraHostRequirement.deviceIntegrityPassed =>
          context.deviceIntegrityPassed,
      };
    }

    for (final requirement in config.requiredRequirements) {
      if (!satisfied(requirement)) {
        missing.add(requirement);
      }
    }

    if (missing.isEmpty) {
      return const AvoraHostEligibilityResult(
        status: AvoraHostEligibilityStatus.eligible,
        missingRequirements: {},
        nextActions: [],
      );
    }

    final identityMissing = missing.contains(
      AvoraHostRequirement.verifiedAdultIdentity,
    );

    if (identityMissing) {
      return AvoraHostEligibilityResult(
        status: AvoraHostEligibilityStatus.notEligible,
        missingRequirements: Set.unmodifiable(missing),
        nextActions: const [
          'Complete or renew identity verification.',
        ],
      );
    }

    return AvoraHostEligibilityResult(
      status: AvoraHostEligibilityStatus.conditionallyEligible,
      missingRequirements: Set.unmodifiable(missing),
      nextActions: _safeNextActions(missing),
    );
  }

  static List<String> _safeNextActions(
    Set<AvoraHostRequirement> missing,
  ) {
    final actions = <String>[];

    if (missing.contains(
      AvoraHostRequirement.profileComplete,
    )) {
      actions.add('Complete your profile.');
    }

    if (missing.contains(
      AvoraHostRequirement.countryPolicyAllows,
    )) {
      actions.add('Check Host availability in your country.');
    }

    if (missing.contains(
      AvoraHostRequirement.agencyRequirementMet,
    )) {
      actions.add('Complete the required agency step.');
    }

    if (missing.contains(
      AvoraHostRequirement.trainingCompleted,
    )) {
      actions.add('Complete Host training.');
    }

    if (missing.contains(
      AvoraHostRequirement.agreementAccepted,
    )) {
      actions.add('Review and accept the Host agreement.');
    }

    if (missing.contains(
          AvoraHostRequirement.riskClear,
        ) ||
        missing.contains(
          AvoraHostRequirement.deviceIntegrityPassed,
        )) {
      /// Do not disclose sensitive internal risk signals.
      actions.add('Your Host eligibility requires review.');
    }

    return List.unmodifiable(actions);
  }

  /// Identity verification and Host eligibility are separate.
  static bool identityVerifiedAutomaticallyMeansHostEligible() {
    return false;
  }

  /// Creator authenticity is also a separate verification track.
  static bool identityVerificationEqualsCreatorVerification() {
    return false;
  }
}
