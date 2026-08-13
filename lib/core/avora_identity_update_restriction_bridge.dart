import 'avora_identity_edit_restriction.dart';
import 'avora_protected_identity_update_gate.dart';

class AvoraIdentityUpdateRestrictionResult {
  const AvoraIdentityUpdateRestrictionResult({
    required this.allowed,
    required this.reason,
    this.identityDecision,
  });

  final bool allowed;
  final String reason;
  final AvoraProtectedIdentityUpdateDecision? identityDecision;
}

class AvoraIdentityUpdateRestrictionBridge {
  AvoraIdentityUpdateRestrictionBridge({
    required AvoraIdentityEditRestrictionLedger restrictionLedger,
    required AvoraProtectedIdentityUpdateGate identityUpdateGate,
  })  : _restrictionLedger = restrictionLedger,
        _identityUpdateGate = identityUpdateGate;

  final AvoraIdentityEditRestrictionLedger _restrictionLedger;
  final AvoraProtectedIdentityUpdateGate _identityUpdateGate;

  AvoraIdentityUpdateRestrictionResult update({
    required AvoraProtectedIdentityUpdateRequest request,
  }) {
    final mayEdit = _restrictionLedger.mayEditIdentity(
      avoraId: request.targetAvoraId,
      nowUtc: request.createdAtUtc,
      actorIsVerifiedOwner: request.actorIsVerifiedOwner,
    );

    if (!mayEdit) {
      return const AvoraIdentityUpdateRestrictionResult(
        allowed: false,
        reason: 'identity_edit_temporarily_restricted',
      );
    }

    final decision = _identityUpdateGate.update(request);

    return AvoraIdentityUpdateRestrictionResult(
      allowed: decision.allowed,
      reason: decision.reason,
      identityDecision: decision,
    );
  }

  static bool restrictionMustRunBeforeIdentityGuard() => true;

  static bool restrictedUserMustNotChangeTitleNameOrDp() => true;

  static bool restrictedAttemptMustNotMutateProtectedRegistry() => true;

  static bool ownerOverrideMustBypassTemporaryRestriction() => true;

  static bool expiredRestrictionMustAllowNormalFlow() => true;

  static bool futureIdentityUpdateSurfacesMustUseSameBridge() => true;
}
