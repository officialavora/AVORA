enum AvoraReferralSource {
  signupCode,
  inviteDeepLink,
  qrCode,
  campaignLink,
  manualLater,
}

enum AvoraReferralStatus {
  pendingVerification,
  eligibleLocked,
  rejected,
  cancelled,
}

enum AvoraReferralDenyReason {
  none,
  referralDisabled,
  codeMissing,
  codeInvalid,
  codeInactive,
  codeNotStarted,
  codeExpired,
  countryNotAllowed,
  sourceNotAllowed,
  selfReferral,
  attributionAlreadyLocked,
  manualEntryNotAllowed,
  manualEntryWindowExpired,
  lifecycleAlreadyDisqualified,
  circularReferral,
  highConfidenceDeviceAbuse,
  policyExcluded,
  inviteCodeUseLimitReached,
}

class AvoraInviteCode {
  final String code;

  final String inviterAvoraId;

  final bool active;

  final DateTime startsAt;
  final DateTime? endsAt;

  final String? campaignId;

  /// Empty = global unless another policy layer restricts it.
  final Set<String> allowedCountryCodes;

  /// Null = no code-level cap.
  final int? maximumAcceptedUses;

  const AvoraInviteCode({
    required this.code,
    required this.inviterAvoraId,
    required this.active,
    required this.startsAt,
    this.endsAt,
    this.campaignId,
    this.allowedCountryCodes = const {},
    this.maximumAcceptedUses,
  }) : assert(
          maximumAcceptedUses == null || maximumAcceptedUses >= 0,
        );

  bool activeAt(DateTime now) {
    if (!active) {
      return false;
    }

    if (now.isBefore(startsAt)) {
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
        .map((code) => code.trim().toUpperCase())
        .contains(normalized);
  }
}

class AvoraReferralPolicy {
  final bool enabled;

  final bool allowSignupCode;
  final bool allowDeepLink;
  final bool allowQrCode;
  final bool allowCampaignLink;
  final bool allowManualLater;

  /// How long after AVORA-ID creation the user may add a code
  /// if it was forgotten at signup.
  final Duration manualEntryWindow;

  /// Verified users only count for invite targets/rewards.
  final bool requireVerifiedInviteeForReward;

  /// Once valid attribution is accepted, inviter cannot be
  /// freely changed.
  final bool lockValidAttribution;

  const AvoraReferralPolicy({
    this.enabled = true,
    this.allowSignupCode = true,
    this.allowDeepLink = true,
    this.allowQrCode = true,
    this.allowCampaignLink = true,
    this.allowManualLater = true,
    this.manualEntryWindow = const Duration(days: 7),
    this.requireVerifiedInviteeForReward = true,
    this.lockValidAttribution = true,
  });
}

class AvoraReferralAttribution {
  final String id;

  final String inviterAvoraId;
  final String inviteeAvoraId;

  final String inviteCode;

  final AvoraReferralSource source;

  final String? campaignId;

  final String inviteeCountryCode;

  final DateTime attributedAt;

  final AvoraReferralStatus status;

  /// Attribution source is immutable once accepted when policy says so,
  /// even if reward remains pending identity verification.
  final bool attributionLocked;

  final bool inviteeIdentityVerified;

  final DateTime? verifiedAt;

  const AvoraReferralAttribution({
    required this.id,
    required this.inviterAvoraId,
    required this.inviteeAvoraId,
    required this.inviteCode,
    required this.source,
    required this.inviteeCountryCode,
    required this.attributedAt,
    required this.status,
    required this.attributionLocked,
    required this.inviteeIdentityVerified,
    this.campaignId,
    this.verifiedAt,
  });

  bool get rewardEligible =>
      status == AvoraReferralStatus.eligibleLocked && inviteeIdentityVerified;
}

class AvoraReferralAttempt {
  final String inviteeAvoraId;

  final DateTime inviteeCreatedAt;

  final String inviteeCountryCode;

  final String? enteredCode;

  final AvoraReferralSource source;

  final DateTime attemptedAt;

  final bool inviteeIdentityVerified;

  /// Examples: account passed a point after which adding/changing
  /// referral is no longer allowed under configured policy.
  final bool disqualifyingLifecycleEventOccurred;

  /// This means device-abuse evidence is already high-confidence;
  /// simple shared-device coincidence should not be passed as true.
  final bool highConfidenceDeviceAbuse;

  final bool policyExcluded;

  const AvoraReferralAttempt({
    required this.inviteeAvoraId,
    required this.inviteeCreatedAt,
    required this.inviteeCountryCode,
    required this.enteredCode,
    required this.source,
    required this.attemptedAt,
    required this.inviteeIdentityVerified,
    this.disqualifyingLifecycleEventOccurred = false,
    this.highConfidenceDeviceAbuse = false,
    this.policyExcluded = false,
  });
}

class AvoraReferralDecision {
  final bool allowed;

  final AvoraReferralDenyReason reason;

  final AvoraInviteCode? inviteCode;

  final AvoraReferralStatus? initialStatus;

  final bool lockAttribution;

  const AvoraReferralDecision({
    required this.allowed,
    required this.reason,
    required this.inviteCode,
    required this.initialStatus,
    required this.lockAttribution,
  });
}

class AvoraReferralRewardEligibility {
  final bool countForInviteTarget;
  final bool rewardEligible;

  const AvoraReferralRewardEligibility({
    required this.countForInviteTarget,
    required this.rewardEligible,
  });
}

class AvoraReferralAttributionEngine {
  const AvoraReferralAttributionEngine._();

  static String normalizeCode(String code) {
    return code.trim().toUpperCase();
  }

  static bool sourceAllowed({
    required AvoraReferralSource source,
    required AvoraReferralPolicy policy,
  }) {
    return switch (source) {
      AvoraReferralSource.signupCode => policy.allowSignupCode,
      AvoraReferralSource.inviteDeepLink => policy.allowDeepLink,
      AvoraReferralSource.qrCode => policy.allowQrCode,
      AvoraReferralSource.campaignLink => policy.allowCampaignLink,
      AvoraReferralSource.manualLater => policy.allowManualLater,
    };
  }

  static AvoraInviteCode? findCode({
    required String enteredCode,
    required List<AvoraInviteCode> inviteCodes,
  }) {
    final normalized = normalizeCode(enteredCode);

    for (final inviteCode in inviteCodes) {
      if (normalizeCode(inviteCode.code) == normalized) {
        return inviteCode;
      }
    }

    return null;
  }

  static bool createsCircularReferral({
    required String inviterAvoraId,
    required String inviteeAvoraId,
    required List<AvoraReferralAttribution> existingAttributions,
  }) {
    if (inviterAvoraId == inviteeAvoraId) {
      return true;
    }

    var current = inviterAvoraId;
    final visited = <String>{};

    while (visited.add(current)) {
      AvoraReferralAttribution? parent;

      for (final attribution in existingAttributions) {
        final usable = attribution.status != AvoraReferralStatus.rejected &&
            attribution.status != AvoraReferralStatus.cancelled;

        if (usable && attribution.inviteeAvoraId == current) {
          parent = attribution;
          break;
        }
      }

      if (parent == null) {
        return false;
      }

      current = parent.inviterAvoraId;

      if (current == inviteeAvoraId) {
        return true;
      }
    }

    return true;
  }

  static bool _hasLockedAttribution({
    required String inviteeAvoraId,
    required List<AvoraReferralAttribution> existingAttributions,
  }) {
    return existingAttributions.any(
      (attribution) =>
          attribution.inviteeAvoraId == inviteeAvoraId &&
          attribution.attributionLocked &&
          attribution.status != AvoraReferralStatus.rejected &&
          attribution.status != AvoraReferralStatus.cancelled,
    );
  }

  static int _acceptedUseCount({
    required String inviteCode,
    required List<AvoraReferralAttribution> existingAttributions,
  }) {
    final normalized = normalizeCode(inviteCode);

    return existingAttributions
        .where(
          (attribution) =>
              normalizeCode(attribution.inviteCode) == normalized &&
              attribution.status != AvoraReferralStatus.rejected &&
              attribution.status != AvoraReferralStatus.cancelled,
        )
        .length;
  }

  static AvoraReferralDecision evaluate({
    required AvoraReferralAttempt attempt,
    required AvoraReferralPolicy policy,
    required List<AvoraInviteCode> inviteCodes,
    required List<AvoraReferralAttribution> existingAttributions,
  }) {
    if (!policy.enabled) {
      return const AvoraReferralDecision(
        allowed: false,
        reason: AvoraReferralDenyReason.referralDisabled,
        inviteCode: null,
        initialStatus: null,
        lockAttribution: false,
      );
    }

    if (!sourceAllowed(
      source: attempt.source,
      policy: policy,
    )) {
      return const AvoraReferralDecision(
        allowed: false,
        reason: AvoraReferralDenyReason.sourceNotAllowed,
        inviteCode: null,
        initialStatus: null,
        lockAttribution: false,
      );
    }

    final rawCode = attempt.enteredCode?.trim();

    if (rawCode == null || rawCode.isEmpty) {
      return const AvoraReferralDecision(
        allowed: false,
        reason: AvoraReferralDenyReason.codeMissing,
        inviteCode: null,
        initialStatus: null,
        lockAttribution: false,
      );
    }

    if (_hasLockedAttribution(
      inviteeAvoraId: attempt.inviteeAvoraId,
      existingAttributions: existingAttributions,
    )) {
      return const AvoraReferralDecision(
        allowed: false,
        reason: AvoraReferralDenyReason.attributionAlreadyLocked,
        inviteCode: null,
        initialStatus: null,
        lockAttribution: false,
      );
    }

    if (attempt.source == AvoraReferralSource.manualLater) {
      if (!policy.allowManualLater) {
        return const AvoraReferralDecision(
          allowed: false,
          reason: AvoraReferralDenyReason.manualEntryNotAllowed,
          inviteCode: null,
          initialStatus: null,
          lockAttribution: false,
        );
      }

      final deadline = attempt.inviteeCreatedAt.add(policy.manualEntryWindow);

      if (attempt.attemptedAt.isAfter(deadline)) {
        return const AvoraReferralDecision(
          allowed: false,
          reason: AvoraReferralDenyReason.manualEntryWindowExpired,
          inviteCode: null,
          initialStatus: null,
          lockAttribution: false,
        );
      }

      if (attempt.disqualifyingLifecycleEventOccurred) {
        return const AvoraReferralDecision(
          allowed: false,
          reason: AvoraReferralDenyReason.lifecycleAlreadyDisqualified,
          inviteCode: null,
          initialStatus: null,
          lockAttribution: false,
        );
      }
    }

    final inviteCode = findCode(
      enteredCode: rawCode,
      inviteCodes: inviteCodes,
    );

    if (inviteCode == null) {
      return const AvoraReferralDecision(
        allowed: false,
        reason: AvoraReferralDenyReason.codeInvalid,
        inviteCode: null,
        initialStatus: null,
        lockAttribution: false,
      );
    }

    if (!inviteCode.active) {
      return AvoraReferralDecision(
        allowed: false,
        reason: AvoraReferralDenyReason.codeInactive,
        inviteCode: inviteCode,
        initialStatus: null,
        lockAttribution: false,
      );
    }

    if (attempt.attemptedAt.isBefore(inviteCode.startsAt)) {
      return AvoraReferralDecision(
        allowed: false,
        reason: AvoraReferralDenyReason.codeNotStarted,
        inviteCode: inviteCode,
        initialStatus: null,
        lockAttribution: false,
      );
    }

    final end = inviteCode.endsAt;

    if (end != null && !attempt.attemptedAt.isBefore(end)) {
      return AvoraReferralDecision(
        allowed: false,
        reason: AvoraReferralDenyReason.codeExpired,
        inviteCode: inviteCode,
        initialStatus: null,
        lockAttribution: false,
      );
    }

    if (!inviteCode.countryAllowed(
      attempt.inviteeCountryCode,
    )) {
      return AvoraReferralDecision(
        allowed: false,
        reason: AvoraReferralDenyReason.countryNotAllowed,
        inviteCode: inviteCode,
        initialStatus: null,
        lockAttribution: false,
      );
    }

    if (inviteCode.inviterAvoraId == attempt.inviteeAvoraId) {
      return AvoraReferralDecision(
        allowed: false,
        reason: AvoraReferralDenyReason.selfReferral,
        inviteCode: inviteCode,
        initialStatus: null,
        lockAttribution: false,
      );
    }

    if (createsCircularReferral(
      inviterAvoraId: inviteCode.inviterAvoraId,
      inviteeAvoraId: attempt.inviteeAvoraId,
      existingAttributions: existingAttributions,
    )) {
      return AvoraReferralDecision(
        allowed: false,
        reason: AvoraReferralDenyReason.circularReferral,
        inviteCode: inviteCode,
        initialStatus: null,
        lockAttribution: false,
      );
    }

    if (attempt.highConfidenceDeviceAbuse) {
      return AvoraReferralDecision(
        allowed: false,
        reason: AvoraReferralDenyReason.highConfidenceDeviceAbuse,
        inviteCode: inviteCode,
        initialStatus: null,
        lockAttribution: false,
      );
    }

    if (attempt.policyExcluded) {
      return AvoraReferralDecision(
        allowed: false,
        reason: AvoraReferralDenyReason.policyExcluded,
        inviteCode: inviteCode,
        initialStatus: null,
        lockAttribution: false,
      );
    }

    final maximumUses = inviteCode.maximumAcceptedUses;

    if (maximumUses != null) {
      final used = _acceptedUseCount(
        inviteCode: inviteCode.code,
        existingAttributions: existingAttributions,
      );

      if (used >= maximumUses) {
        return AvoraReferralDecision(
          allowed: false,
          reason: AvoraReferralDenyReason.inviteCodeUseLimitReached,
          inviteCode: inviteCode,
          initialStatus: null,
          lockAttribution: false,
        );
      }
    }

    final status = policy.requireVerifiedInviteeForReward &&
            !attempt.inviteeIdentityVerified
        ? AvoraReferralStatus.pendingVerification
        : AvoraReferralStatus.eligibleLocked;

    return AvoraReferralDecision(
      allowed: true,
      reason: AvoraReferralDenyReason.none,
      inviteCode: inviteCode,
      initialStatus: status,
      lockAttribution: policy.lockValidAttribution,
    );
  }

  static AvoraReferralAttribution createAttribution({
    required String attributionId,
    required AvoraReferralAttempt attempt,
    required AvoraReferralDecision decision,
  }) {
    if (!decision.allowed ||
        decision.inviteCode == null ||
        decision.initialStatus == null) {
      throw StateError(
        'A denied referral decision cannot create attribution.',
      );
    }

    final inviteCode = decision.inviteCode!;

    return AvoraReferralAttribution(
      id: attributionId,
      inviterAvoraId: inviteCode.inviterAvoraId,
      inviteeAvoraId: attempt.inviteeAvoraId,
      inviteCode: normalizeCode(inviteCode.code),
      source: attempt.source,
      campaignId: inviteCode.campaignId,
      inviteeCountryCode: attempt.inviteeCountryCode,
      attributedAt: attempt.attemptedAt,
      status: decision.initialStatus!,
      attributionLocked: decision.lockAttribution,
      inviteeIdentityVerified: attempt.inviteeIdentityVerified,
      verifiedAt: attempt.inviteeIdentityVerified ? attempt.attemptedAt : null,
    );
  }

  static AvoraReferralAttribution markIdentityVerified({
    required AvoraReferralAttribution attribution,
    required DateTime verifiedAt,
  }) {
    if (attribution.status == AvoraReferralStatus.rejected ||
        attribution.status == AvoraReferralStatus.cancelled) {
      return attribution;
    }

    return AvoraReferralAttribution(
      id: attribution.id,
      inviterAvoraId: attribution.inviterAvoraId,
      inviteeAvoraId: attribution.inviteeAvoraId,
      inviteCode: attribution.inviteCode,
      source: attribution.source,
      campaignId: attribution.campaignId,
      inviteeCountryCode: attribution.inviteeCountryCode,
      attributedAt: attribution.attributedAt,
      status: AvoraReferralStatus.eligibleLocked,
      attributionLocked: attribution.attributionLocked,
      inviteeIdentityVerified: true,
      verifiedAt: verifiedAt,
    );
  }

  static AvoraReferralRewardEligibility rewardEligibility({
    required AvoraReferralAttribution attribution,
    required bool policyRewardEnabled,
    required bool fraudOrRiskInvalidated,
  }) {
    final eligible = policyRewardEnabled &&
        attribution.rewardEligible &&
        !fraudOrRiskInvalidated;

    return AvoraReferralRewardEligibility(
      countForInviteTarget: eligible,
      rewardEligible: eligible,
    );
  }

  /// Invite/deep-link attribution may be prefilled automatically.
  static bool deepLinkCanPrefillReferralCode() {
    return true;
  }

  /// Forgetting the code at signup can be repaired only inside
  /// the configured manual-entry window.
  static bool supportsControlledManualEntryLater() {
    return true;
  }

  /// A simple IP/network match alone must not reject a referral.
  static bool ipMatchAloneRejectsReferral() {
    return false;
  }

  /// Only verified eligible invitees count toward rewards/targets.
  static bool unverifiedInviteImmediatelyCountsForReward() {
    return false;
  }
}
