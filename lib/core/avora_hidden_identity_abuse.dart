enum AvoraIdentityPresentationMode {
  normal,
  intentionallyAnonymous,
  hiddenByUiBug,
  hiddenByRenderFailure,
  clientManipulationSuspected,
}

enum AvoraHiddenIdentityRestriction {
  none,
  warning,
  temporaryMute,
  temporaryChatRestriction,
  temporarySeatRestriction,
  temporaryLiveRestriction,
  temporaryRoomRestriction,
  manualReview,
}

enum AvoraHiddenIdentityRiskReason {
  none,
  abuseDetected,
  identityHiddenDuringAbuse,
  repeatedHiddenAbuse,
  clientManipulationSuspected,
  authoritativeIdentityMismatch,
  sessionBindingMissing,
}

class AvoraModerationSessionIdentity {
  const AvoraModerationSessionIdentity({
    required this.sessionId,
    required this.immutableAvoraId,
    required this.roomId,
    required this.serverBound,
  });

  final String sessionId;

  /// This ID remains authoritative even when UI/display identity is hidden.
  final String immutableAvoraId;

  final String roomId;

  /// Must be established by trusted backend/session infrastructure.
  final bool serverBound;

  bool get valid =>
      sessionId.trim().isNotEmpty &&
      immutableAvoraId.trim().isNotEmpty &&
      roomId.trim().isNotEmpty &&
      serverBound;
}

class AvoraHiddenIdentityAbuseSignal {
  const AvoraHiddenIdentityAbuseSignal({
    required this.presentationMode,
    required this.abuseDetected,
    required this.abuseConfidenceBps,
    required this.repeatAbuseCount,
    required this.authoritativeIdentityMismatch,
  });

  final AvoraIdentityPresentationMode presentationMode;

  final bool abuseDetected;

  /// 0..10000. Must originate from trusted moderation evidence/pipeline.
  final int abuseConfidenceBps;

  final int repeatAbuseCount;

  /// Visible/rendered identity disagreed with server-bound immutable identity.
  final bool authoritativeIdentityMismatch;

  bool get valid =>
      abuseConfidenceBps >= 0 &&
      abuseConfidenceBps <= 10000 &&
      repeatAbuseCount >= 0;
}

class AvoraHiddenIdentityAbusePolicy {
  const AvoraHiddenIdentityAbusePolicy({
    required this.policyVersion,
    required this.warningThresholdBps,
    required this.restrictionThresholdBps,
    required this.reviewThresholdBps,
    required this.repeatEscalationCount,
    required this.temporaryRestrictionMinutes,
  });

  final String policyVersion;

  final int warningThresholdBps;
  final int restrictionThresholdBps;
  final int reviewThresholdBps;

  final int repeatEscalationCount;
  final int temporaryRestrictionMinutes;

  bool get valid =>
      policyVersion.trim().isNotEmpty &&
      warningThresholdBps >= 0 &&
      restrictionThresholdBps >= warningThresholdBps &&
      reviewThresholdBps >= restrictionThresholdBps &&
      reviewThresholdBps <= 10000 &&
      repeatEscalationCount > 0 &&
      temporaryRestrictionMinutes > 0;
}

class AvoraHiddenIdentityAbuseDecision {
  const AvoraHiddenIdentityAbuseDecision({
    required this.restriction,
    required this.riskScoreBps,
    required this.reasons,
    required this.immutableAvoraId,
    required this.sessionId,
    required this.restrictionMinutes,
    required this.requiresAudit,
  });

  final AvoraHiddenIdentityRestriction restriction;
  final int riskScoreBps;
  final Set<AvoraHiddenIdentityRiskReason> reasons;

  final String immutableAvoraId;
  final String sessionId;

  final int restrictionMinutes;
  final bool requiresAudit;

  bool get restricted =>
      restriction != AvoraHiddenIdentityRestriction.none &&
      restriction != AvoraHiddenIdentityRestriction.warning;
}

class AvoraHiddenIdentityAbuseEngine {
  const AvoraHiddenIdentityAbuseEngine._();

  static AvoraHiddenIdentityAbuseDecision evaluate({
    required AvoraModerationSessionIdentity identity,
    required AvoraHiddenIdentityAbuseSignal signal,
    required AvoraHiddenIdentityAbusePolicy policy,
  }) {
    final reasons = <AvoraHiddenIdentityRiskReason>{};

    if (!identity.valid) {
      reasons.add(AvoraHiddenIdentityRiskReason.sessionBindingMissing);

      return AvoraHiddenIdentityAbuseDecision(
        restriction: AvoraHiddenIdentityRestriction.manualReview,
        riskScoreBps: 10000,
        reasons: Set.unmodifiable(reasons),
        immutableAvoraId: identity.immutableAvoraId,
        sessionId: identity.sessionId,
        restrictionMinutes: 0,
        requiresAudit: true,
      );
    }

    if (!signal.valid || !policy.valid) {
      return AvoraHiddenIdentityAbuseDecision(
        restriction: AvoraHiddenIdentityRestriction.manualReview,
        riskScoreBps: 0,
        reasons: const {
          AvoraHiddenIdentityRiskReason.none,
        },
        immutableAvoraId: identity.immutableAvoraId,
        sessionId: identity.sessionId,
        restrictionMinutes: 0,
        requiresAudit: true,
      );
    }

    if (!signal.abuseDetected) {
      return AvoraHiddenIdentityAbuseDecision(
        restriction: AvoraHiddenIdentityRestriction.none,
        riskScoreBps: 0,
        reasons: const {
          AvoraHiddenIdentityRiskReason.none,
        },
        immutableAvoraId: identity.immutableAvoraId,
        sessionId: identity.sessionId,
        restrictionMinutes: 0,
        requiresAudit: false,
      );
    }

    reasons.add(AvoraHiddenIdentityRiskReason.abuseDetected);

    var risk = signal.abuseConfidenceBps;

    final hidden =
        signal.presentationMode != AvoraIdentityPresentationMode.normal;

    if (hidden) {
      risk += 1200;
      reasons.add(
        AvoraHiddenIdentityRiskReason.identityHiddenDuringAbuse,
      );
    }

    if (signal.presentationMode ==
        AvoraIdentityPresentationMode.clientManipulationSuspected) {
      risk += 1800;
      reasons.add(
        AvoraHiddenIdentityRiskReason.clientManipulationSuspected,
      );
    }

    if (signal.authoritativeIdentityMismatch) {
      risk += 2200;
      reasons.add(
        AvoraHiddenIdentityRiskReason.authoritativeIdentityMismatch,
      );
    }

    if (signal.repeatAbuseCount >= policy.repeatEscalationCount) {
      risk += 1800;
      reasons.add(
        AvoraHiddenIdentityRiskReason.repeatedHiddenAbuse,
      );
    }

    risk = risk.clamp(0, 10000);

    AvoraHiddenIdentityRestriction restriction;

    if (risk >= policy.reviewThresholdBps) {
      restriction = AvoraHiddenIdentityRestriction.manualReview;
    } else if (risk >= policy.restrictionThresholdBps) {
      if (signal.repeatAbuseCount >= policy.repeatEscalationCount) {
        restriction = AvoraHiddenIdentityRestriction.temporaryRoomRestriction;
      } else {
        restriction = AvoraHiddenIdentityRestriction.temporaryChatRestriction;
      }
    } else if (risk >= policy.warningThresholdBps) {
      restriction = AvoraHiddenIdentityRestriction.warning;
    } else {
      restriction = AvoraHiddenIdentityRestriction.none;
    }

    return AvoraHiddenIdentityAbuseDecision(
      restriction: restriction,
      riskScoreBps: risk,
      reasons: Set.unmodifiable(reasons),
      immutableAvoraId: identity.immutableAvoraId,
      sessionId: identity.sessionId,
      restrictionMinutes: restriction == AvoraHiddenIdentityRestriction.none ||
              restriction == AvoraHiddenIdentityRestriction.warning ||
              restriction == AvoraHiddenIdentityRestriction.manualReview
          ? 0
          : policy.temporaryRestrictionMinutes,
      requiresAudit: restriction != AvoraHiddenIdentityRestriction.none,
    );
  }

  static bool visibleIdIsAuthoritativeForModeration() => false;

  static bool immutableAvoraIdRemainsAuthoritativeWhenUiHidden() => true;

  static bool hiddenPresentationAloneCanPunishUser() => false;

  static bool hiddenPresentationAloneCanCausePermanentBan() => false;

  static bool temporaryRestrictionMustBeReversible() => true;

  static bool clientCanOverrideAuthoritativeModerationIdentity() => false;

  static bool serverAuthoritativeSessionBindingRequired() => true;

  static bool moderationActionRequiresAudit() => true;
}

class AvoraHiddenIdentityAbuseAuditEvent {
  const AvoraHiddenIdentityAbuseAuditEvent({
    required this.auditId,
    required this.sessionId,
    required this.immutableAvoraId,
    required this.roomId,
    required this.presentationMode,
    required this.restriction,
    required this.riskScoreBps,
    required this.policyVersion,
    required this.occurredAtUtc,
  });

  final String auditId;
  final String sessionId;
  final String immutableAvoraId;
  final String roomId;

  final AvoraIdentityPresentationMode presentationMode;
  final AvoraHiddenIdentityRestriction restriction;

  final int riskScoreBps;
  final String policyVersion;
  final DateTime occurredAtUtc;

  bool get valid =>
      auditId.trim().isNotEmpty &&
      sessionId.trim().isNotEmpty &&
      immutableAvoraId.trim().isNotEmpty &&
      roomId.trim().isNotEmpty &&
      riskScoreBps >= 0 &&
      riskScoreBps <= 10000 &&
      policyVersion.trim().isNotEmpty &&
      occurredAtUtc.isUtc;
}
