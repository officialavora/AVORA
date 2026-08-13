import 'avora_creator_acquisition.dart';

enum AvoraCreatorProofMethod {
  providerOauth,
  guidedScreenCapture,
  manualReview,
}

enum AvoraCreatorProofStatus {
  pending,
  capturing,
  submitted,
  verified,
  manualReview,
  rejected,
  expired,
  revoked,
}

enum AvoraCreatorProofFailure {
  none,
  challengeExpired,
  wrongCreator,
  wrongPlatform,
  wrongHandle,
  invalidCaptureDuration,
  galleryEvidenceNotAllowed,
  captureConsentMissing,
  challengeNotShown,
  profileNotShown,
  controlActionNotVerified,
  livenessNotVerified,
  integrityFailed,
  duplicateEvidence,
  providerVerificationFailed,
}

class AvoraCreatorProofConfig {
  /// Default guided recording window: 1–2 minutes.
  final int minimumCaptureSeconds;
  final int maximumCaptureSeconds;

  final bool allowGalleryEvidence;
  final bool requireLivenessForGuidedCapture;
  final bool requireControlAction;

  const AvoraCreatorProofConfig({
    this.minimumCaptureSeconds = 60,
    this.maximumCaptureSeconds = 120,
    this.allowGalleryEvidence = false,
    this.requireLivenessForGuidedCapture = true,
    this.requireControlAction = true,
  })  : assert(minimumCaptureSeconds > 0),
        assert(maximumCaptureSeconds >= minimumCaptureSeconds);
}

class AvoraCreatorProofChallenge {
  final String id;
  final String creatorUserId;

  final AvoraCreatorSourcePlatform platform;
  final String externalHandle;

  /// Short-lived server-issued nonce/code.
  final String challengeCode;

  final DateTime issuedAt;
  final DateTime expiresAt;

  const AvoraCreatorProofChallenge({
    required this.id,
    required this.creatorUserId,
    required this.platform,
    required this.externalHandle,
    required this.challengeCode,
    required this.issuedAt,
    required this.expiresAt,
  });

  bool isActiveAt(DateTime time) =>
      !time.isBefore(issuedAt) && !time.isAfter(expiresAt);
}

class AvoraCreatorProofEvidence {
  final String creatorUserId;
  final AvoraCreatorSourcePlatform platform;
  final String externalHandle;

  final AvoraCreatorProofMethod method;

  final DateTime startedAt;
  final DateTime endedAt;

  /// Guided capture must originate from the active AVORA session.
  final bool capturedInAvora;
  final bool importedFromGallery;

  final bool screenCaptureConsentGranted;

  /// Challenge/session watermark was visible in evidence.
  final bool challengeShown;

  /// Claimed external profile/handle was actually shown.
  final bool externalProfileShown;

  /// Dynamic ownership action was successfully verified.
  ///
  /// Example: temporary challenge code/action performed
  /// from the claimed external account.
  final bool controlActionVerified;

  final bool livenessVerified;

  /// Server/device evidence integrity check.
  final bool integrityVerified;

  /// True when the same evidence/hash was already submitted.
  final bool duplicateEvidence;

  /// Provider OAuth/account link succeeded server-side.
  final bool providerAccountVerified;

  /// Hash/reference only; raw evidence storage policy is separate.
  final String? evidenceHash;

  const AvoraCreatorProofEvidence({
    required this.creatorUserId,
    required this.platform,
    required this.externalHandle,
    required this.method,
    required this.startedAt,
    required this.endedAt,
    this.capturedInAvora = false,
    this.importedFromGallery = false,
    this.screenCaptureConsentGranted = false,
    this.challengeShown = false,
    this.externalProfileShown = false,
    this.controlActionVerified = false,
    this.livenessVerified = false,
    this.integrityVerified = false,
    this.duplicateEvidence = false,
    this.providerAccountVerified = false,
    this.evidenceHash,
  });

  Duration get duration => endedAt.difference(startedAt);
}

class AvoraCreatorProofDecision {
  final AvoraCreatorProofStatus status;
  final AvoraCreatorProofFailure failure;

  const AvoraCreatorProofDecision({
    required this.status,
    required this.failure,
  });

  bool get verified => status == AvoraCreatorProofStatus.verified;
}

class AvoraCreatorProofEngine {
  const AvoraCreatorProofEngine._();

  static AvoraCreatorProofDecision evaluate({
    required AvoraCreatorProofChallenge challenge,
    required AvoraCreatorProofEvidence evidence,
    required DateTime now,
    AvoraCreatorProofConfig config = const AvoraCreatorProofConfig(),
  }) {
    AvoraCreatorProofDecision fail(
      AvoraCreatorProofFailure failure,
    ) {
      return AvoraCreatorProofDecision(
        status: AvoraCreatorProofStatus.rejected,
        failure: failure,
      );
    }

    if (!challenge.isActiveAt(now)) {
      return const AvoraCreatorProofDecision(
        status: AvoraCreatorProofStatus.expired,
        failure: AvoraCreatorProofFailure.challengeExpired,
      );
    }

    if (evidence.creatorUserId != challenge.creatorUserId) {
      return fail(AvoraCreatorProofFailure.wrongCreator);
    }

    if (evidence.platform != challenge.platform) {
      return fail(AvoraCreatorProofFailure.wrongPlatform);
    }

    if (evidence.externalHandle.trim().toLowerCase() !=
        challenge.externalHandle.trim().toLowerCase()) {
      return fail(AvoraCreatorProofFailure.wrongHandle);
    }

    if (evidence.method == AvoraCreatorProofMethod.providerOauth) {
      if (!evidence.providerAccountVerified) {
        return fail(
          AvoraCreatorProofFailure.providerVerificationFailed,
        );
      }

      return const AvoraCreatorProofDecision(
        status: AvoraCreatorProofStatus.verified,
        failure: AvoraCreatorProofFailure.none,
      );
    }

    if (evidence.method == AvoraCreatorProofMethod.manualReview) {
      return const AvoraCreatorProofDecision(
        status: AvoraCreatorProofStatus.manualReview,
        failure: AvoraCreatorProofFailure.none,
      );
    }

    final seconds = evidence.duration.inSeconds;

    if (seconds < config.minimumCaptureSeconds ||
        seconds > config.maximumCaptureSeconds) {
      return fail(
        AvoraCreatorProofFailure.invalidCaptureDuration,
      );
    }

    if (evidence.importedFromGallery && !config.allowGalleryEvidence) {
      return fail(
        AvoraCreatorProofFailure.galleryEvidenceNotAllowed,
      );
    }

    if (!evidence.capturedInAvora || !evidence.screenCaptureConsentGranted) {
      return fail(
        AvoraCreatorProofFailure.captureConsentMissing,
      );
    }

    if (!evidence.challengeShown) {
      return fail(
        AvoraCreatorProofFailure.challengeNotShown,
      );
    }

    if (!evidence.externalProfileShown) {
      return fail(
        AvoraCreatorProofFailure.profileNotShown,
      );
    }

    if (config.requireControlAction && !evidence.controlActionVerified) {
      return fail(
        AvoraCreatorProofFailure.controlActionNotVerified,
      );
    }

    if (config.requireLivenessForGuidedCapture && !evidence.livenessVerified) {
      return fail(
        AvoraCreatorProofFailure.livenessNotVerified,
      );
    }

    if (!evidence.integrityVerified) {
      return fail(
        AvoraCreatorProofFailure.integrityFailed,
      );
    }

    if (evidence.duplicateEvidence) {
      return fail(
        AvoraCreatorProofFailure.duplicateEvidence,
      );
    }

    return const AvoraCreatorProofDecision(
      status: AvoraCreatorProofStatus.verified,
      failure: AvoraCreatorProofFailure.none,
    );
  }
}
