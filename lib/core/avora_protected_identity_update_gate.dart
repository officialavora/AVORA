import 'avora_identity_impersonation_guard.dart';
import 'avora_protected_identity_registry.dart';

class AvoraProtectedIdentityUpdateRequest {
  const AvoraProtectedIdentityUpdateRequest({
    required this.auditId,
    required this.actorAvoraId,
    required this.targetAvoraId,
    required this.requestedDisplayName,
    required this.requestedProfileMediaFingerprint,
    required this.authorizedTitles,
    required this.actorIsVerifiedOwner,
    required this.reason,
    required this.createdAtUtc,
  });

  final String auditId;
  final String actorAvoraId;
  final String targetAvoraId;

  final String requestedDisplayName;
  final String requestedProfileMediaFingerprint;

  final Set<String> authorizedTitles;

  final bool actorIsVerifiedOwner;

  final String reason;
  final DateTime createdAtUtc;
}

class AvoraProtectedIdentityUpdateDecision {
  const AvoraProtectedIdentityUpdateDecision({
    required this.allowed,
    required this.reason,
    required this.reviewRequired,
  });

  final bool allowed;
  final String reason;
  final bool reviewRequired;
}

class AvoraProtectedIdentityUpdateGate {
  AvoraProtectedIdentityUpdateGate({
    required AvoraIdentityImpersonationGuard guard,
    required AvoraProtectedIdentityRegistry registry,
  })  : _guard = guard,
        _registry = registry;

  final AvoraIdentityImpersonationGuard _guard;
  final AvoraProtectedIdentityRegistry _registry;

  AvoraProtectedIdentityUpdateDecision update(
    AvoraProtectedIdentityUpdateRequest request,
  ) {
    if (request.auditId.trim().isEmpty ||
        request.actorAvoraId.trim().isEmpty ||
        request.targetAvoraId.trim().isEmpty ||
        request.requestedDisplayName.trim().isEmpty ||
        request.reason.trim().isEmpty) {
      return const AvoraProtectedIdentityUpdateDecision(
        allowed: false,
        reason: 'invalid_identity_update_request',
        reviewRequired: false,
      );
    }

    final titleDecision = _guard.validateTitleUse(
      requestedIdentityText: request.requestedDisplayName,
      authorizedTitles: request.authorizedTitles,
      actorIsVerifiedOwner: request.actorIsVerifiedOwner,
    );

    if (!titleDecision.allowed) {
      return AvoraProtectedIdentityUpdateDecision(
        allowed: false,
        reason: titleDecision.reason,
        reviewRequired: titleDecision.reviewRequired,
      );
    }

    final nameDecision = _guard.validateProtectedName(
      actorAvoraId: request.targetAvoraId,
      requestedDisplayName: request.requestedDisplayName,
      protectedProfiles: _registry.protectedProfiles,
      actorIsVerifiedOwner: request.actorIsVerifiedOwner,
    );

    if (!nameDecision.allowed) {
      return AvoraProtectedIdentityUpdateDecision(
        allowed: false,
        reason: nameDecision.reason,
        reviewRequired: nameDecision.reviewRequired,
      );
    }

    final mediaDecision = _guard.validateProfileMedia(
      actorAvoraId: request.targetAvoraId,
      requestedFingerprint: request.requestedProfileMediaFingerprint,
      protectedProfiles: _registry.protectedProfiles,
      actorIsVerifiedOwner: request.actorIsVerifiedOwner,
    );

    if (!mediaDecision.allowed) {
      return AvoraProtectedIdentityUpdateDecision(
        allowed: false,
        reason: mediaDecision.reason,
        reviewRequired: mediaDecision.reviewRequired,
      );
    }

    final previous = _registry.profileFor(
      request.targetAvoraId,
    );

    final normalizedName = _guard.normalize(
      request.requestedDisplayName,
    );

    final next = AvoraProtectedIdentityProfile(
      avoraId: request.targetAvoraId,
      authorizedTitles: request.authorizedTitles,
      normalizedDisplayName: normalizedName,
      profileMediaFingerprint: request.requestedProfileMediaFingerprint.trim(),
    );

    if (previous == null) {
      _registry.register(
        profile: next,
        auditId: request.auditId,
        actorAvoraId: request.actorAvoraId,
        reason: request.reason,
        createdAtUtc: request.createdAtUtc,
      );
    } else {
      _registry.replace(
        profile: next,
        auditId: request.auditId,
        actorAvoraId: request.actorAvoraId,
        changeType: request.actorIsVerifiedOwner
            ? AvoraProtectedIdentityChangeType.ownerOverride
            : AvoraProtectedIdentityChangeType.displayNameChange,
        beforeValue: previous.normalizedDisplayName,
        afterValue: normalizedName,
        reason: request.reason,
        createdAtUtc: request.createdAtUtc,
      );
    }

    return const AvoraProtectedIdentityUpdateDecision(
      allowed: true,
      reason: 'protected_identity_update_allowed',
      reviewRequired: false,
    );
  }

  static bool titleCheckMustRunBeforeProfileUpdate() => true;

  static bool protectedNameCheckMustRunBeforeProfileUpdate() => true;

  static bool protectedMediaCheckMustRunBeforeProfileUpdate() => true;

  static bool blockedImpersonationMustNeverUpdateRegistry() => true;

  static bool successfulProtectedUpdateMustBeAudited() => true;

  static bool ownerOverrideMustRemainAudited() => true;

  static bool futureIdentitySurfacesMustUseSameGate() => true;
}
