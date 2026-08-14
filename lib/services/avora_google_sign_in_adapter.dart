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
    this.clientId,
    this.serverClientId,
  })  : googleSignIn = googleSignIn ?? GoogleSignIn.instance,
        firebaseBridge = firebaseBridge ?? AvoraFirebaseAuthBridge();

  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await googleSignIn.initialize(
      clientId: clientId,
      serverClientId: serverClientId ??
          '553162958068-i9323bql4svshr06mm93via5j645nd5r.apps.googleusercontent.com',
    );

    _initialized = true;
  }

  Future<_AvoraGoogleCredentialResult> _authenticate() async {
    if (!_initialized) {
      return const _AvoraGoogleCredentialResult(
        success: false,
        error: AvoraGoogleAuthError.notInitialized,
      );
    }

    if (!googleSignIn.supportsAuthenticate()) {
      return const _AvoraGoogleCredentialResult(
        success: false,
        error: AvoraGoogleAuthError.interactiveAuthUnsupported,
      );
    }

    try {
      final account = await googleSignIn.authenticate();

      final authentication = account.authentication;
      final idToken = authentication.idToken;

      if (idToken == null || idToken.trim().isEmpty) {
        return const _AvoraGoogleCredentialResult(
          success: false,
          error: AvoraGoogleAuthError.missingIdToken,
        );
      }

      /// Token is used only transiently to construct the
      /// Firebase credential. It is never stored in AVORA core.
      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      return _AvoraGoogleCredentialResult(
        success: true,
        error: AvoraGoogleAuthError.none,
        providerSubjectId: account.id,
        credential: credential,
      );
    } on GoogleSignInException catch (e) {
      throw Exception(
        'GoogleSignInException code=${e.code} description=${e.description}',
      );
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
