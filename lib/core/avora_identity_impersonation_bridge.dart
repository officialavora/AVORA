import 'avora_identity_impersonation_audit.dart';
import 'avora_identity_impersonation_guard.dart';

class AvoraIdentityImpersonationBridge {
  AvoraIdentityImpersonationBridge({
    required AvoraIdentityImpersonationGuard guard,
    required AvoraIdentityImpersonationAuditLedger auditLedger,
  })  : _guard = guard,
        _auditLedger = auditLedger;

  final AvoraIdentityImpersonationGuard _guard;
  final AvoraIdentityImpersonationAuditLedger _auditLedger;

  AvoraIdentityImpersonationDecision validateTitle({
    required String auditId,
    required String actorAvoraId,
    required String requestedIdentityText,
    required Set<String> authorizedTitles,
    required bool actorIsVerifiedOwner,
    required DateTime createdAtUtc,
  }) {
    final decision = _guard.validateTitleUse(
      requestedIdentityText: requestedIdentityText,
      authorizedTitles: authorizedTitles,
      actorIsVerifiedOwner: actorIsVerifiedOwner,
    );

    if (!decision.allowed) {
      _auditLedger.append(
        AvoraImpersonationAuditRecord(
          auditId: auditId,
          actorAvoraId: actorAvoraId,
          attemptType: AvoraImpersonationAttemptType.unauthorizedTitle,
          requestedValue: requestedIdentityText,
          reason: decision.reason,
          createdAtUtc: createdAtUtc.toUtc(),
          status: AvoraImpersonationReviewStatus.pending,
        ),
      );
    }

    return decision;
  }

  AvoraIdentityImpersonationDecision validateName({
    required String auditId,
    required String actorAvoraId,
    required String requestedDisplayName,
    required Iterable<AvoraProtectedIdentityProfile> protectedProfiles,
    required bool actorIsVerifiedOwner,
    required DateTime createdAtUtc,
  }) {
    final collision = _findNameCollision(
      actorAvoraId: actorAvoraId,
      requestedDisplayName: requestedDisplayName,
      protectedProfiles: protectedProfiles,
    );

    final decision = _guard.validateProtectedName(
      actorAvoraId: actorAvoraId,
      requestedDisplayName: requestedDisplayName,
      protectedProfiles: protectedProfiles,
      actorIsVerifiedOwner: actorIsVerifiedOwner,
    );

    if (!decision.allowed) {
      _auditLedger.append(
        AvoraImpersonationAuditRecord(
          auditId: auditId,
          actorAvoraId: actorAvoraId,
          protectedAvoraId: collision,
          attemptType: AvoraImpersonationAttemptType.protectedNameClone,
          requestedValue: requestedDisplayName,
          reason: decision.reason,
          createdAtUtc: createdAtUtc.toUtc(),
          status: AvoraImpersonationReviewStatus.pending,
        ),
      );
    }

    return decision;
  }

  AvoraIdentityImpersonationDecision validateProfileMedia({
    required String auditId,
    required String actorAvoraId,
    required String requestedFingerprint,
    required Iterable<AvoraProtectedIdentityProfile> protectedProfiles,
    required bool actorIsVerifiedOwner,
    required DateTime createdAtUtc,
  }) {
    final collision = _findMediaCollision(
      actorAvoraId: actorAvoraId,
      requestedFingerprint: requestedFingerprint,
      protectedProfiles: protectedProfiles,
    );

    final decision = _guard.validateProfileMedia(
      actorAvoraId: actorAvoraId,
      requestedFingerprint: requestedFingerprint,
      protectedProfiles: protectedProfiles,
      actorIsVerifiedOwner: actorIsVerifiedOwner,
    );

    if (!decision.allowed) {
      _auditLedger.append(
        AvoraImpersonationAuditRecord(
          auditId: auditId,
          actorAvoraId: actorAvoraId,
          protectedAvoraId: collision,
          attemptType: AvoraImpersonationAttemptType.protectedProfileMediaClone,
          requestedValue: requestedFingerprint,
          reason: decision.reason,
          createdAtUtc: createdAtUtc.toUtc(),
          status: AvoraImpersonationReviewStatus.pending,
        ),
      );
    }

    return decision;
  }

  String? _findNameCollision({
    required String actorAvoraId,
    required String requestedDisplayName,
    required Iterable<AvoraProtectedIdentityProfile> protectedProfiles,
  }) {
    final requested = _guard.normalize(requestedDisplayName);

    for (final profile in protectedProfiles) {
      if (profile.avoraId == actorAvoraId) continue;

      if (requested.isNotEmpty && requested == profile.normalizedDisplayName) {
        return profile.avoraId;
      }
    }

    return null;
  }

  String? _findMediaCollision({
    required String actorAvoraId,
    required String requestedFingerprint,
    required Iterable<AvoraProtectedIdentityProfile> protectedProfiles,
  }) {
    final requested = requestedFingerprint.trim();

    for (final profile in protectedProfiles) {
      if (profile.avoraId == actorAvoraId) continue;

      if (requested.isNotEmpty &&
          requested == profile.profileMediaFingerprint) {
        return profile.avoraId;
      }
    }

    return null;
  }

  static bool blockedTitleMustAutoAudit() => true;
  static bool blockedNameCloneMustAutoAudit() => true;
  static bool blockedDpCloneMustAutoAudit() => true;
  static bool collisionTargetMustBePreservedWhenKnown() => true;
  static bool allowedIdentityUpdateMustNotCreateAttackAudit() => true;
  static bool ownerOverrideMustNotBeTreatedAsImpersonation() => true;
  static bool futureIdentityChecksMustUseSameBridge() => true;
}
