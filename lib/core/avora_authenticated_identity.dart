/// Production-facing authenticated identity contract.
///
/// Firebase UID proves authentication.
/// Immutable AVORA ID remains the authoritative application identity.
class AvoraAuthenticatedIdentity {
  const AvoraAuthenticatedIdentity({
    required this.firebaseUid,
    required this.avoraId,
    required this.bindingVerified,
  });

  final String firebaseUid;
  final String avoraId;
  final bool bindingVerified;

  bool get isUsable =>
      firebaseUid.trim().isNotEmpty &&
      avoraId.trim().isNotEmpty &&
      bindingVerified;
}

abstract class AvoraAuthenticatedIdentityResolver {
  Future<AvoraAuthenticatedIdentity?> resolve({
    required String firebaseUid,
  });
}

/// Fail-closed resolver used until a production identity repository
/// is explicitly wired.
///
/// It intentionally never invents an AVORA ID from Firebase UID.
class AvoraClosedIdentityResolver
    implements AvoraAuthenticatedIdentityResolver {
  const AvoraClosedIdentityResolver();

  @override
  Future<AvoraAuthenticatedIdentity?> resolve({
    required String firebaseUid,
  }) async {
    return null;
  }
}

class AvoraIdentityBindingSecurity {
  const AvoraIdentityBindingSecurity._();

  static bool firebaseUidMustNeverBecomeAvoraIdImplicitly() => true;

  static bool bindingMustBeServerAuthoritative() => true;

  static bool missingBindingMustFailClosed() => true;

  static bool clientMustNotSelfAssignImmutableAvoraId() => true;
}
