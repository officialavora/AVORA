import 'avora_authenticated_identity.dart';

class AvoraOwnerAuditActorGuard {
  const AvoraOwnerAuditActorGuard._();

  static bool matchesAuthenticatedIdentity({
    required AvoraAuthenticatedIdentity identity,
    required String claimedActorAvoraId,
  }) {
    if (!identity.isUsable) {
      return false;
    }

    final claimed = claimedActorAvoraId.trim();

    if (claimed.isEmpty) {
      return false;
    }

    return identity.avoraId == claimed;
  }

  static void requireMatch({
    required AvoraAuthenticatedIdentity identity,
    required String claimedActorAvoraId,
  }) {
    if (!matchesAuthenticatedIdentity(
      identity: identity,
      claimedActorAvoraId: claimedActorAvoraId,
    )) {
      throw StateError('owner_audit_actor_identity_mismatch');
    }
  }

  static bool callerMustNotSpoofActorAvoraId() => true;

  static bool verifiedIdentityMustRemainAuthoritative() => true;

  static bool mismatchMustFailClosed() => true;
}
