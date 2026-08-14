import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'avora_firebase_auth_bridge.dart';

enum AvoraGoogleAuthOperation {
  signIn,
  link,
}

enum AvoraGoogleAuthError {
  none,
  notInitialized,
  interactiveAuthUnsupported,
  googleAuthenticationFailed,
  missingIdToken,
  avoraPolicyApprovalRequired,
  firebaseBridgeRejected,
}

class AvoraGoogleAuthResult {
  final bool success;

  final AvoraGoogleAuthOperation operation;
  final AvoraGoogleAuthError error;

  /// Google provider identity only.
  /// It never replaces the immutable AVORA ID.
  final String? providerSubjectId;

  final String? firebaseUid;

  final AvoraFirebaseAuthBridgeError? firebaseError;

  const AvoraGoogleAuthResult({
    required this.success,
    required this.operation,
    required this.error,
    this.providerSubjectId,
    this.firebaseUid,
    this.firebaseError,
  });
}

class AvoraGoogleSignInAdapter {
  final GoogleSignIn googleSignIn;
  final AvoraFirebaseAuthBridge firebaseBridge;

  final String? clientId;
  final String? serverClientId;

  bool _initialized = false;

  AvoraGoogleSignInAdapter({
    GoogleSignIn? googleSignIn,
    AvoraFirebaseAuthBridge? firebaseBridge,
    String? clientId,
    String? serverClientId,
  })  : clientId = clientId,
        serverClientId = serverClientId,
        googleSignIn = googleSignIn ??
            GoogleSignIn(
              clientId: clientId,
              serverClientId: serverClientId ??
                  '553162958068-i9323bql4svshr06mm93via5j645nd5r.apps.googleusercontent.com',
              scopes: const <String>[
                'email',
              ],
            ),
        firebaseBridge =
            firebaseBridge ?? AvoraFirebaseAuthBridge();

  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    /// google_sign_in 6.x is configured through the
    /// GoogleSignIn constructor, so no async SDK initialize
    /// call is required here.
    _initialized = true;
  }

  Future<_AvoraGoogleCredentialResult> _authenticate() async {
    if (!_initialized) {
      return const _AvoraGoogleCredentialResult(
        success: false,
        error: AvoraGoogleAuthError.notInitialized,
      );
    }

    try {
      /// google_sign_in 6.x uses the legacy signIn() flow.
      final GoogleSignInAccount? account =
          await googleSignIn.signIn();

      /// A null account means the interactive flow was cancelled.
      if (account == null) {
        return const _AvoraGoogleCredentialResult(
          success: false,
          error: AvoraGoogleAuthError.googleAuthenticationFailed,
        );
      }

      final GoogleSignInAuthentication authentication =
          await account.authentication;

      final String? idToken = authentication.idToken;

      if (idToken == null || idToken.trim().isEmpty) {
        return const _AvoraGoogleCredentialResult(
          success: false,
          error: AvoraGoogleAuthError.missingIdToken,
        );
      }

      /// Token is used only transiently to construct the
      /// Firebase credential. It is never stored in AVORA core.
      final OAuthCredential credential =
          GoogleAuthProvider.credential(
        accessToken: authentication.accessToken,
        idToken: idToken,
      );

      return _AvoraGoogleCredentialResult(
        success: true,
        error: AvoraGoogleAuthError.none,
        providerSubjectId: account.id,
        credential: credential,
      );
    } catch (e) {
      /// Keep the real v6/platform error visible during testing
      /// instead of hiding it behind a generic failure.
      throw Exception('Google Sign-In v6 error: $e');
    }
  }

  Future<AvoraGoogleAuthResult> signIn() async {
    final google = await _authenticate();

    if (!google.success || google.credential == null) {
      return AvoraGoogleAuthResult(
        success: false,
        operation: AvoraGoogleAuthOperation.signIn,
        error: google.error,
        providerSubjectId: google.providerSubjectId,
      );
    }

    final firebase = await firebaseBridge.signInWithCredential(
      google.credential!,
    );

    if (!firebase.success) {
      return AvoraGoogleAuthResult(
        success: false,
        operation: AvoraGoogleAuthOperation.signIn,
        error: AvoraGoogleAuthError.firebaseBridgeRejected,
        providerSubjectId: google.providerSubjectId,
        firebaseUid: firebase.firebaseUid,
        firebaseError: firebase.error,
      );
    }

    return AvoraGoogleAuthResult(
      success: true,
      operation: AvoraGoogleAuthOperation.signIn,
      error: AvoraGoogleAuthError.none,
      providerSubjectId: google.providerSubjectId,
      firebaseUid: firebase.firebaseUid,
      firebaseError: firebase.error,
    );
  }

  Future<AvoraGoogleAuthResult> linkToCurrentAccount({
    required bool avoraPolicyApproved,
  }) async {
    /// Step 9J policy must approve account linking first.
    if (!avoraPolicyApproved) {
      return const AvoraGoogleAuthResult(
        success: false,
        operation: AvoraGoogleAuthOperation.link,
        error: AvoraGoogleAuthError.avoraPolicyApprovalRequired,
      );
    }

    final google = await _authenticate();

    if (!google.success || google.credential == null) {
      return AvoraGoogleAuthResult(
        success: false,
        operation: AvoraGoogleAuthOperation.link,
        error: google.error,
        providerSubjectId: google.providerSubjectId,
      );
    }

    final firebase = await firebaseBridge.linkCredential(
      google.credential!,
    );

    if (!firebase.success) {
      return AvoraGoogleAuthResult(
        success: false,
        operation: AvoraGoogleAuthOperation.link,
        error: AvoraGoogleAuthError.firebaseBridgeRejected,
        providerSubjectId: google.providerSubjectId,
        firebaseUid: firebase.firebaseUid,
        firebaseError: firebase.error,
      );
    }

    return AvoraGoogleAuthResult(
      success: true,
      operation: AvoraGoogleAuthOperation.link,
      error: AvoraGoogleAuthError.none,
      providerSubjectId: google.providerSubjectId,
      firebaseUid: firebase.firebaseUid,
      firebaseError: firebase.error,
    );
  }

  Future<void> signOutGoogle() async {
    if (!_initialized) {
      return;
    }

    await googleSignIn.signOut();
  }

  /// Google ID/Firebase UID are authentication identifiers,
  /// never the immutable AVORA public/backend identity.
  static bool googleIdentityReplacesImmutableAvoraId() {
    return false;
  }

  /// Google sign-in never creates referral attribution.
  static bool googleAdapterReplacesReferralEngine() {
    return false;
  }

  /// Provider name/photo is not automatically copied
  /// over the AVORA user profile.
  static bool googleProfileAutomaticallyOverridesAvoraProfile() {
    return false;
  }

  /// A Google account never grants Manager/Admin/etc authority.
  static bool googleAccountGrantsAvoraAuthority() {
    return false;
  }

  /// Raw Google ID/access tokens are never persisted
  /// by this adapter into AVORA records.
  static bool adapterStoresRawGoogleTokensInAvoraCore() {
    return false;
  }

  /// Account linking must first pass Step 9J AVORA policy.
  static bool googleLinkingCanBypassAvoraPolicy() {
    return false;
  }
}

class _AvoraGoogleCredentialResult {
  final bool success;
  final AvoraGoogleAuthError error;

  final String? providerSubjectId;
  final AuthCredential? credential;

  const _AvoraGoogleCredentialResult({
    required this.success,
    required this.error,
    this.providerSubjectId,
    this.credential,
  });
}
