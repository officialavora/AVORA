enum AvoraFaceVerificationOutcome {
  verified,
  retryRequired,
  manualReview,
  riskReview,
  rejected,
}

enum AvoraFaceVerificationReason {
  none,
  invalidSession,
  sessionExpired,
  nonceMismatch,
  challengeNotCompleted,
  captureNotLive,
  galleryOrImportedMedia,
  reusedMediaDetected,
  screenReplaySuspected,
  secondDeviceDisplaySuspected,
  virtualCameraSuspected,
  emulatorSuspected,
  screenRecordingSuspected,
  presentationAttackRisk,
  deepfakeOrSyntheticRisk,
  motionDepthInconsistency,
  faceCompositeAnomaly,
  poorCaptureQuality,
  authoritativeReplayMatch,
}

class AvoraFaceVerificationSession {
  const AvoraFaceVerificationSession({
    required this.sessionId,
    required this.immutableAvoraId,
    required this.serverNonce,
    required this.challengeId,
    required this.issuedAtUtc,
    required this.expiresAtUtc,
    required this.policyVersion,
    required this.attemptNumber,
  });

  final String sessionId;

  /// Verification/reverification never changes the user's immutable AVORA ID.
  final String immutableAvoraId;

  /// Single-use server-issued value bound to this exact attempt.
  final String serverNonce;

  /// Randomized active-liveness challenge selected by the server.
  final String challengeId;

  final DateTime issuedAtUtc;
  final DateTime expiresAtUtc;

  final String policyVersion;
  final int attemptNumber;

  bool get valid =>
      sessionId.trim().isNotEmpty &&
      immutableAvoraId.trim().isNotEmpty &&
      serverNonce.trim().isNotEmpty &&
      challengeId.trim().isNotEmpty &&
      policyVersion.trim().isNotEmpty &&
      attemptNumber > 0 &&
      issuedAtUtc.isUtc &&
      expiresAtUtc.isUtc &&
      expiresAtUtc.isAfter(issuedAtUtc);

  bool isActiveAt(DateTime serverNowUtc) =>
      valid &&
      serverNowUtc.isUtc &&
      !serverNowUtc.isBefore(issuedAtUtc) &&
      serverNowUtc.isBefore(expiresAtUtc);
}

class AvoraLivenessChallengeEvidence {
  const AvoraLivenessChallengeEvidence({
    required this.challengeShown,
    required this.challengeCompleted,
    required this.responseNonceMatched,
    required this.completedWithinSessionWindow,
    required this.randomizedSequenceCompleted,
  });

  final bool challengeShown;
  final bool challengeCompleted;

  /// Prevents replaying evidence from an older verification session.
  final bool responseNonceMatched;

  final bool completedWithinSessionWindow;

  /// Blink/head-turn/gesture/follow-target sequence must match this attempt.
  final bool randomizedSequenceCompleted;

  bool get passed =>
      challengeShown &&
      challengeCompleted &&
      responseNonceMatched &&
      completedWithinSessionWindow &&
      randomizedSequenceCompleted;
}

class AvoraCaptureIntegritySignals {
  const AvoraCaptureIntegritySignals({
    required this.capturedLiveInAvora,
    required this.importedFromGallery,
    required this.physicalCameraSessionTrusted,
    required this.virtualCameraSuspected,
    required this.emulatorSuspected,
    required this.screenRecordingSuspected,
    required this.deviceAttestationTrusted,
  });

  final bool capturedLiveInAvora;
  final bool importedFromGallery;

  /// Provider/platform attestation signal. Client declaration alone is not
  /// sufficient.
  final bool physicalCameraSessionTrusted;

  final bool virtualCameraSuspected;
  final bool emulatorSuspected;
  final bool screenRecordingSuspected;

  final bool deviceAttestationTrusted;
}

class AvoraPresentationAttackSignals {
  const AvoraPresentationAttackSignals({
    required this.screenReplaySuspected,
    required this.secondDeviceDisplaySuspected,
    required this.displayArtifactSuspected,
    required this.motionDepthInconsistency,
    required this.faceCompositeAnomaly,
    required this.presentationAttackRiskBps,
  });

  /// Movie/serial/video/photo displayed to the verification camera.
  final bool screenReplaySuspected;

  /// Another phone/tablet/display shown to the front camera.
  final bool secondDeviceDisplaySuspected;

  /// Moire/refresh/reflection/display-boundary type provider signals.
  final bool displayArtifactSuspected;

  /// Multi-frame motion/parallax/depth consistency signal.
  final bool motionDepthInconsistency;

  /// Face boundary/compositing/deepfake-style anomaly signal.
  final bool faceCompositeAnomaly;

  /// 0..10000, supplied by trusted server/provider analysis.
  final int presentationAttackRiskBps;

  bool get valid =>
      presentationAttackRiskBps >= 0 && presentationAttackRiskBps <= 10000;
}

class AvoraSyntheticMediaSignals {
  const AvoraSyntheticMediaSignals({
    required this.deepfakeRiskBps,
    required this.syntheticVideoRiskBps,
    required this.providerModelVersion,
  });

  /// AI/deepfake classifiers are risk signals, never sole permanent-ban proof.
  final int deepfakeRiskBps;
  final int syntheticVideoRiskBps;

  final String providerModelVersion;

  bool get valid =>
      deepfakeRiskBps >= 0 &&
      deepfakeRiskBps <= 10000 &&
      syntheticVideoRiskBps >= 0 &&
      syntheticVideoRiskBps <= 10000 &&
      providerModelVersion.trim().isNotEmpty;
}

class AvoraVerificationMediaFingerprint {
  const AvoraVerificationMediaFingerprint({
    required this.fingerprintReference,
    required this.reusedAcrossVerificationAttempts,
    required this.authoritativeReplayMatch,
  });

  /// Reference/hash only. Core policy does not need raw biometric media.
  final String fingerprintReference;

  /// Similar/reused clip seen in previous verification attempts.
  final bool reusedAcrossVerificationAttempts;

  /// Strong server-side match against previously submitted/replayed evidence.
  final bool authoritativeReplayMatch;
}

class AvoraFaceCaptureQuality {
  const AvoraFaceCaptureQuality({
    required this.faceVisible,
    required this.lightingUsable,
    required this.motionUsable,
    required this.captureDurationValid,
  });

  final bool faceVisible;
  final bool lightingUsable;
  final bool motionUsable;
  final bool captureDurationValid;

  bool get usable =>
      faceVisible && lightingUsable && motionUsable && captureDurationValid;
}

class AvoraFaceAntiSpoofPolicy {
  const AvoraFaceAntiSpoofPolicy({
    required this.policyVersion,
    required this.manualReviewThresholdBps,
    required this.riskReviewThresholdBps,
    required this.requireTrustedDeviceAttestation,
    required this.requireTrustedPhysicalCameraSession,
    required this.rejectImportedGalleryMedia,
  });

  final String policyVersion;

  final int manualReviewThresholdBps;
  final int riskReviewThresholdBps;

  final bool requireTrustedDeviceAttestation;
  final bool requireTrustedPhysicalCameraSession;
  final bool rejectImportedGalleryMedia;

  bool get valid =>
      policyVersion.trim().isNotEmpty &&
      manualReviewThresholdBps >= 0 &&
      manualReviewThresholdBps <= 10000 &&
      riskReviewThresholdBps >= manualReviewThresholdBps &&
      riskReviewThresholdBps <= 10000;
}

class AvoraFaceVerificationDecision {
  const AvoraFaceVerificationDecision({
    required this.outcome,
    required this.riskScoreBps,
    required this.reasons,
    required this.policyVersion,
    required this.immutableAvoraId,
    required this.sessionId,
  });

  final AvoraFaceVerificationOutcome outcome;
  final int riskScoreBps;
  final Set<AvoraFaceVerificationReason> reasons;

  final String policyVersion;
  final String immutableAvoraId;
  final String sessionId;

  bool get verified => outcome == AvoraFaceVerificationOutcome.verified;
}

class AvoraFaceAntiSpoofEngine {
  const AvoraFaceAntiSpoofEngine._();

  static AvoraFaceVerificationDecision evaluate({
    required AvoraFaceVerificationSession session,
    required AvoraFaceAntiSpoofPolicy policy,
    required AvoraLivenessChallengeEvidence challenge,
    required AvoraCaptureIntegritySignals capture,
    required AvoraPresentationAttackSignals presentation,
    required AvoraSyntheticMediaSignals synthetic,
    required AvoraVerificationMediaFingerprint mediaFingerprint,
    required AvoraFaceCaptureQuality quality,
    required DateTime serverNowUtc,
  }) {
    final reasons = <AvoraFaceVerificationReason>{};

    AvoraFaceVerificationDecision decision(
      AvoraFaceVerificationOutcome outcome,
      int riskScoreBps,
    ) {
      return AvoraFaceVerificationDecision(
        outcome: outcome,
        riskScoreBps: riskScoreBps.clamp(0, 10000),
        reasons: Set.unmodifiable(
          reasons.isEmpty ? {AvoraFaceVerificationReason.none} : reasons,
        ),
        policyVersion: policy.policyVersion,
        immutableAvoraId: session.immutableAvoraId,
        sessionId: session.sessionId,
      );
    }

    if (!session.valid ||
        !policy.valid ||
        !presentation.valid ||
        !synthetic.valid ||
        !serverNowUtc.isUtc) {
      reasons.add(AvoraFaceVerificationReason.invalidSession);
      return decision(
        AvoraFaceVerificationOutcome.retryRequired,
        0,
      );
    }

    if (!session.isActiveAt(serverNowUtc)) {
      reasons.add(AvoraFaceVerificationReason.sessionExpired);
      return decision(
        AvoraFaceVerificationOutcome.retryRequired,
        0,
      );
    }

    if (!quality.usable) {
      reasons.add(AvoraFaceVerificationReason.poorCaptureQuality);
      return decision(
        AvoraFaceVerificationOutcome.retryRequired,
        0,
      );
    }

    if (!challenge.responseNonceMatched) {
      reasons.add(AvoraFaceVerificationReason.nonceMismatch);
      return decision(
        AvoraFaceVerificationOutcome.riskReview,
        9000,
      );
    }

    if (!challenge.passed) {
      reasons.add(AvoraFaceVerificationReason.challengeNotCompleted);
      return decision(
        AvoraFaceVerificationOutcome.retryRequired,
        2000,
      );
    }

    if (!capture.capturedLiveInAvora) {
      reasons.add(AvoraFaceVerificationReason.captureNotLive);
    }

    if (capture.importedFromGallery && policy.rejectImportedGalleryMedia) {
      reasons.add(AvoraFaceVerificationReason.galleryOrImportedMedia);
    }

    if (capture.virtualCameraSuspected) {
      reasons.add(AvoraFaceVerificationReason.virtualCameraSuspected);
    }

    if (capture.emulatorSuspected) {
      reasons.add(AvoraFaceVerificationReason.emulatorSuspected);
    }

    if (capture.screenRecordingSuspected) {
      reasons.add(AvoraFaceVerificationReason.screenRecordingSuspected);
    }

    if (presentation.screenReplaySuspected) {
      reasons.add(AvoraFaceVerificationReason.screenReplaySuspected);
    }

    if (presentation.secondDeviceDisplaySuspected) {
      reasons.add(
        AvoraFaceVerificationReason.secondDeviceDisplaySuspected,
      );
    }

    if (presentation.motionDepthInconsistency) {
      reasons.add(
        AvoraFaceVerificationReason.motionDepthInconsistency,
      );
    }

    if (presentation.faceCompositeAnomaly) {
      reasons.add(AvoraFaceVerificationReason.faceCompositeAnomaly);
    }

    if (presentation.presentationAttackRiskBps >=
        policy.manualReviewThresholdBps) {
      reasons.add(AvoraFaceVerificationReason.presentationAttackRisk);
    }

    final syntheticRisk =
        synthetic.deepfakeRiskBps > synthetic.syntheticVideoRiskBps
            ? synthetic.deepfakeRiskBps
            : synthetic.syntheticVideoRiskBps;

    if (syntheticRisk >= policy.manualReviewThresholdBps) {
      reasons.add(AvoraFaceVerificationReason.deepfakeOrSyntheticRisk);
    }

    if (mediaFingerprint.reusedAcrossVerificationAttempts) {
      reasons.add(AvoraFaceVerificationReason.reusedMediaDetected);
    }

    if (mediaFingerprint.authoritativeReplayMatch) {
      reasons.add(AvoraFaceVerificationReason.authoritativeReplayMatch);

      /// Rejection applies to this verification attempt, not an automatic
      /// permanent account ban.
      return decision(
        AvoraFaceVerificationOutcome.rejected,
        10000,
      );
    }

    var risk = 0;

    risk += presentation.presentationAttackRiskBps ~/ 2;
    risk += syntheticRisk ~/ 3;

    if (!capture.capturedLiveInAvora) risk += 2500;
    if (capture.importedFromGallery) risk += 3000;
    if (capture.virtualCameraSuspected) risk += 3500;
    if (capture.emulatorSuspected) risk += 2500;
    if (capture.screenRecordingSuspected) risk += 2000;
    if (presentation.screenReplaySuspected) risk += 3500;
    if (presentation.secondDeviceDisplaySuspected) risk += 3500;
    if (presentation.displayArtifactSuspected) risk += 1500;
    if (presentation.motionDepthInconsistency) risk += 2000;
    if (presentation.faceCompositeAnomaly) risk += 2000;
    if (mediaFingerprint.reusedAcrossVerificationAttempts) risk += 3000;

    if (policy.requireTrustedDeviceAttestation &&
        !capture.deviceAttestationTrusted) {
      risk += 1800;
    }

    if (policy.requireTrustedPhysicalCameraSession &&
        !capture.physicalCameraSessionTrusted) {
      risk += 2200;
    }

    risk = risk.clamp(0, 10000);

    // A strong AI/deepfake signal alone must never permanently ban a user,
    // but it also must not silently pass as genuine verification.
    // Escalate at least to manual review.
    if (syntheticRisk >= policy.manualReviewThresholdBps &&
        risk < policy.manualReviewThresholdBps) {
      risk = policy.manualReviewThresholdBps;
    }

    final strongPresentationConcern = presentation.screenReplaySuspected ||
        presentation.secondDeviceDisplaySuspected ||
        capture.virtualCameraSuspected ||
        mediaFingerprint.reusedAcrossVerificationAttempts;

    if (risk >= policy.riskReviewThresholdBps || strongPresentationConcern) {
      return decision(
        AvoraFaceVerificationOutcome.riskReview,
        risk,
      );
    }

    if (risk >= policy.manualReviewThresholdBps) {
      return decision(
        AvoraFaceVerificationOutcome.manualReview,
        risk,
      );
    }

    return decision(
      AvoraFaceVerificationOutcome.verified,
      risk,
    );
  }

  static bool serverMustIssueSessionNonce() => true;

  static bool galleryVideoAloneCanVerifyIdentity() => false;

  static bool clientCanSelfDeclareVerificationSuccess() => false;

  static bool aiOrDeepfakeSignalAloneCanCausePermanentBan() => false;

  static bool poorCaptureQualityShouldCausePermanentBan() => false;

  static bool immutableAvoraIdChangesAfterReverification() => false;

  static bool backendFinalDecisionRemainsAuthoritative() => true;
}

class AvoraVerificationEvidenceRetentionPolicy {
  const AvoraVerificationEvidenceRetentionPolicy({
    required this.policyVersion,
    required this.rawCaptureRetentionDays,
    required this.derivedSignalRetentionDays,
    required this.auditRetentionDays,
    required this.accessRestricted,
    required this.deleteAfterRetention,
    required this.purposeLimited,
    required this.legalHoldOnlyWhenRequired,
  });

  final String policyVersion;

  /// Jurisdiction/provider configurable. These are policy values, not hard
  /// legal guarantees.
  final int rawCaptureRetentionDays;
  final int derivedSignalRetentionDays;
  final int auditRetentionDays;

  final bool accessRestricted;
  final bool deleteAfterRetention;
  final bool purposeLimited;
  final bool legalHoldOnlyWhenRequired;

  bool get valid =>
      policyVersion.trim().isNotEmpty &&
      rawCaptureRetentionDays >= 0 &&
      derivedSignalRetentionDays >= 0 &&
      auditRetentionDays >= 0;
}

class AvoraFaceVerificationAuditRecord {
  const AvoraFaceVerificationAuditRecord({
    required this.auditId,
    required this.sessionId,
    required this.immutableAvoraId,
    required this.outcome,
    required this.riskScoreBps,
    required this.reasonCodes,
    required this.policyVersion,
    required this.occurredAtUtc,
    required this.providerReference,
  });

  final String auditId;
  final String sessionId;
  final String immutableAvoraId;

  final AvoraFaceVerificationOutcome outcome;
  final int riskScoreBps;

  /// Store reason codes/derived metadata; raw biometric media does not belong
  /// in this audit record.
  final Set<AvoraFaceVerificationReason> reasonCodes;

  final String policyVersion;
  final DateTime occurredAtUtc;

  /// Opaque provider/backend reference, never secret credentials.
  final String providerReference;

  bool get valid =>
      auditId.trim().isNotEmpty &&
      sessionId.trim().isNotEmpty &&
      immutableAvoraId.trim().isNotEmpty &&
      riskScoreBps >= 0 &&
      riskScoreBps <= 10000 &&
      policyVersion.trim().isNotEmpty &&
      occurredAtUtc.isUtc;
}
