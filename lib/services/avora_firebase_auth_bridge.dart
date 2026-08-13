import 'package:firebase_auth/firebase_auth.dart';

import '../core/avora_account_linking.dart';

enum AvoraFirebaseAuthBridgeError {
  none,
  noCurrentUser,
  providerAlreadyLinked,
  credentialAlreadyInUse,
  invalidCredential,
  providerNotLinked,
  requiresRecentLogin,
  userDisabled,
  operationNotAllowed,
  networkError,
  unknown,
}

class AvoraFirebaseLinkedProvider {
  final AvoraAuthProvider provider;
  final String providerSubjectId;

  const AvoraFirebaseLinkedProvider({
    required this.provider,
    required this.providerSubjectId,
  });
}

class AvoraFirebaseBridgeResult {
  final bool success;

  final AvoraFirebaseAuthBridgeError error;

  final String? firebaseUid;

  final List<AvoraFirebaseLinkedProvider> linkedProviders;

  const AvoraFirebaseBridgeResult({
    required this.success,
    required this.error,
    this.firebaseUid,
    this.linkedProviders = const [],
  });
}

class AvoraFirebaseAuthBridge {
  final FirebaseAuth auth;

  AvoraFirebaseAuthBridge({
    FirebaseAuth? auth,
  }) : auth = auth ?? FirebaseAuth.instance;

  static AvoraAuthProvider? mapFirebaseProviderId(
    String providerId,
  ) {
    switch (providerId) {
      case 'google.com':
        return AvoraAuthProvider.google;

      case 'facebook.com':
        return AvoraAuthProvider.facebook;

      case 'apple.com':
        return AvoraAuthProvider.apple;

      case 'password':
        return AvoraAuthProvider.email;

      case 'phone':
        return AvoraAuthProvider.phone;

      default:
        return null;
    }
  }

  static String firebaseProviderId(
    AvoraAuthProvider provider,
  ) {
    switch (provider) {
      case AvoraAuthProvider.google:
        return 'google.com';

      case AvoraAuthProvider.facebook:
        return 'facebook.com';

      case AvoraAuthProvider.apple:
        return 'apple.com';

      case AvoraAuthProvider.email:
        return 'password';

      case AvoraAuthProvider.phone:
        return 'phone';

      case AvoraAuthProvider.custom:
        return 'custom';
    }
  }

  static List<AvoraFirebaseLinkedProvider> linkedProviders(
    User user,
  ) {
    final result = <AvoraFirebaseLinkedProvider>[];

    for (final info in user.providerData) {
      final mapped = mapFirebaseProviderId(info.providerId);

      final providerSubjectId = info.uid;

      if (mapped == null ||
          providerSubjectId == null ||
          providerSubjectId.trim().isEmpty) {
        continue;
      }

      result.add(
        AvoraFirebaseLinkedProvider(
          provider: mapped,
          providerSubjectId: providerSubjectId,
        ),
      );
    }

    return List.unmodifiable(result);
  }

  AvoraFirebaseBridgeResult currentState() {
    final user = auth.currentUser;

    if (user == null) {
      return const AvoraFirebaseBridgeResult(
        success: false,
        error: AvoraFirebaseAuthBridgeError.noCurrentUser,
      );
    }

    return AvoraFirebaseBridgeResult(
      success: true,
      error: AvoraFirebaseAuthBridgeError.none,
      firebaseUid: user.uid,
      linkedProviders: linkedProviders(user),
    );
  }

  Future<AvoraFirebaseBridgeResult> signInWithCredential(
    AuthCredential credential,
  ) async {
    try {
      final result = await auth.signInWithCredential(
        credential,
      );

      final user = result.user;

      if (user == null) {
        return const AvoraFirebaseBridgeResult(
          success: false,
          error: AvoraFirebaseAuthBridgeError.unknown,
        );
      }

      return AvoraFirebaseBridgeResult(
        success: true,
        error: AvoraFirebaseAuthBridgeError.none,
        firebaseUid: user.uid,
        linkedProviders: linkedProviders(user),
      );
    } on FirebaseAuthException catch (error) {
      return AvoraFirebaseBridgeResult(
        success: false,
        error: mapFirebaseError(error.code),
      );
    }
  }

  Future<AvoraFirebaseBridgeResult> linkCredential(
    AuthCredential credential,
  ) async {
    final user = auth.currentUser;

    if (user == null) {
      return const AvoraFirebaseBridgeResult(
        success: false,
        error: AvoraFirebaseAuthBridgeError.noCurrentUser,
      );
    }

    try {
      final result = await user.linkWithCredential(
        credential,
      );

      final updated = result.user ?? auth.currentUser;

      if (updated == null) {
        return const AvoraFirebaseBridgeResult(
          success: false,
          error: AvoraFirebaseAuthBridgeError.unknown,
        );
      }

      return AvoraFirebaseBridgeResult(
        success: true,
        error: AvoraFirebaseAuthBridgeError.none,
        firebaseUid: updated.uid,
        linkedProviders: linkedProviders(updated),
      );
    } on FirebaseAuthException catch (error) {
      return AvoraFirebaseBridgeResult(
        success: false,
        error: mapFirebaseError(error.code),
      );
    }
  }

  Future<AvoraFirebaseBridgeResult> unlinkProvider(
    AvoraAuthProvider provider,
  ) async {
    final user = auth.currentUser;

    if (user == null) {
      return const AvoraFirebaseBridgeResult(
        success: false,
        error: AvoraFirebaseAuthBridgeError.noCurrentUser,
      );
    }

    try {
      final updated = await user.unlink(
        firebaseProviderId(provider),
      );

      return AvoraFirebaseBridgeResult(
        success: true,
        error: AvoraFirebaseAuthBridgeError.none,
        firebaseUid: updated.uid,
        linkedProviders: linkedProviders(updated),
      );
    } on FirebaseAuthException catch (error) {
      return AvoraFirebaseBridgeResult(
        success: false,
        error: mapFirebaseError(error.code),
      );
    }
  }

  static AvoraFirebaseAuthBridgeError mapFirebaseError(
    String code,
  ) {
    switch (code) {
      case 'provider-already-linked':
        return AvoraFirebaseAuthBridgeError.providerAlreadyLinked;

      case 'credential-already-in-use':
      case 'account-exists-with-different-credential':
        return AvoraFirebaseAuthBridgeError.credentialAlreadyInUse;

      case 'invalid-credential':
        return AvoraFirebaseAuthBridgeError.invalidCredential;

      case 'no-such-provider':
        return AvoraFirebaseAuthBridgeError.providerNotLinked;

      case 'requires-recent-login':
        return AvoraFirebaseAuthBridgeError.requiresRecentLogin;

      case 'user-disabled':
        return AvoraFirebaseAuthBridgeError.userDisabled;

      case 'operation-not-allowed':
        return AvoraFirebaseAuthBridgeError.operationNotAllowed;

      case 'network-request-failed':
        return AvoraFirebaseAuthBridgeError.networkError;

      default:
        return AvoraFirebaseAuthBridgeError.unknown;
    }
  }

  /// Firebase UID is an authentication identity,
  /// not the public/authoritative AVORA ID.
  static bool firebaseUidReplacesImmutableAvoraId() {
    return false;
  }

  /// Provider linking must pass AVORA policy before
  /// this bridge is called.
  static bool firebaseBridgeBypassesAvoraLinkingPolicy() {
    return false;
  }

  /// Existing referral/deep-link attribution remains separate.
  static bool firebaseBridgeCreatesReferralAttribution() {
    return false;
  }

  /// Provider display profile does not silently replace
  /// AVORA name/photo.
  static bool firebaseProfileOverridesAvoraProfile() {
    return false;
  }

  /// Authentication provider never grants staff authority.
  static bool firebaseProviderGrantsAvoraAuthority() {
    return false;
  }

  /// Raw provider access/refresh tokens are not stored
  /// in AVORA account-link records.
  static bool bridgeStoresRawProviderTokensInAvoraCore() {
    return false;
  }
}
