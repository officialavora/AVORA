enum AvoraVerificationStatus {
  unverified,
  pending,
  verified,
  rejected,
  revoked,
}

class AvoraRewardEligibilityProfile {
  final String userId;
  final AvoraVerificationStatus verificationStatus;

  final bool accountActive;

  /// Staff/risk system can temporarily block reward counting
  /// without deleting or banning the account.
  final bool rewardBlocked;

  const AvoraRewardEligibilityProfile({
    required this.userId,
    required this.verificationStatus,
    this.accountActive = true,
    this.rewardBlocked = false,
  });

  bool get verified => verificationStatus == AvoraVerificationStatus.verified;

  bool get eligibleForRewards => verified && accountActive && !rewardBlocked;
}

enum AvoraInviteQualificationStatus {
  pendingVerification,
  qualified,
  invalid,
}

class AvoraInviteQualificationResult {
  final AvoraInviteQualificationStatus status;

  final bool countsForReward;

  final String? reason;

  const AvoraInviteQualificationResult({
    required this.status,
    required this.countsForReward,
    this.reason,
  });
}

class AvoraRewardEligibilityGate {
  const AvoraRewardEligibilityGate._();

  /// Common gate for Sending, Receiving, Recharge, Gamer,
  /// event/festival and other reward/target programs.
  static bool canCountTarget(
    AvoraRewardEligibilityProfile profile,
  ) {
    return profile.eligibleForRewards;
  }

  /// Invite may appear immediately in Pending/Inviting,
  /// but reward counts only after invited ID verification.
  static AvoraInviteQualificationResult qualifyInvite({
    required AvoraRewardEligibilityProfile inviter,
    required AvoraRewardEligibilityProfile invited,
    bool selfReferral = false,
    bool duplicateIdentity = false,
    bool abuseBlocked = false,
  }) {
    if (selfReferral) {
      return const AvoraInviteQualificationResult(
        status: AvoraInviteQualificationStatus.invalid,
        countsForReward: false,
        reason: 'self_referral',
      );
    }

    if (duplicateIdentity) {
      return const AvoraInviteQualificationResult(
        status: AvoraInviteQualificationStatus.invalid,
        countsForReward: false,
        reason: 'duplicate_identity',
      );
    }

    if (abuseBlocked) {
      return const AvoraInviteQualificationResult(
        status: AvoraInviteQualificationStatus.invalid,
        countsForReward: false,
        reason: 'abuse_blocked',
      );
    }

    if (!inviter.eligibleForRewards) {
      return const AvoraInviteQualificationResult(
        status: AvoraInviteQualificationStatus.invalid,
        countsForReward: false,
        reason: 'inviter_not_eligible',
      );
    }

    if (!invited.eligibleForRewards) {
      return const AvoraInviteQualificationResult(
        status: AvoraInviteQualificationStatus.pendingVerification,
        countsForReward: false,
        reason: 'invited_not_verified',
      );
    }

    return const AvoraInviteQualificationResult(
      status: AvoraInviteQualificationStatus.qualified,
      countsForReward: true,
    );
  }
}
