import 'avora_authenticated_identity.dart';
import 'avora_message_owner_audited_access.dart';
import 'avora_message_production_access_gate.dart';
import 'avora_owner_audit_actor_guard.dart';

class AvoraOwnerGuardedMessageAccessService {
  const AvoraOwnerGuardedMessageAccessService({
    required AvoraAuthenticatedIdentityResolver identityResolver,
    required AvoraMessageOwnerAuditedAccessService auditedAccessService,
  })  : _identityResolver = identityResolver,
        _auditedAccessService = auditedAccessService;

  final AvoraAuthenticatedIdentityResolver _identityResolver;
  final AvoraMessageOwnerAuditedAccessService _auditedAccessService;

  Future<AvoraMessageProductionAccessResult> authorize({
    required AvoraMessageProductionAccessRequest request,
    required String claimedActorAvoraId,
    required String auditId,
    required DateTime createdAtUtc,
  }) async {
    final identity = await _identityResolver.resolve(
      firebaseUid: request.firebaseUid,
    );

    if (identity == null || !identity.isUsable) {
      return const AvoraMessageProductionAccessResult(
        allowed: false,
        reason: 'identity_binding_required',
        ownerOverrideUsed: false,
        auditRequired: false,
      );
    }

    if (!AvoraOwnerAuditActorGuard.matchesAuthenticatedIdentity(
      identity: identity,
      claimedActorAvoraId: claimedActorAvoraId,
    )) {
      return const AvoraMessageProductionAccessResult(
        allowed: false,
        reason: 'owner_audit_actor_identity_mismatch',
        ownerOverrideUsed: false,
        auditRequired: true,
      );
    }

    return _auditedAccessService.authorize(
      request: request,
      actorAvoraId: identity.avoraId,
      auditId: auditId,
      createdAtUtc: createdAtUtc,
    );
  }

  static bool auditActorMustMatchAuthenticatedAvoraId() => true;

  static bool clientClaimedActorIdMustNotBeTrusted() => true;

  static bool spoofAttemptMustFailClosed() => true;
}
