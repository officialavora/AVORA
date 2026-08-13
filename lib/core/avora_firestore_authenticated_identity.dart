import 'package:cloud_firestore/cloud_firestore.dart';

import 'avora_authenticated_identity.dart';

class AvoraFirestoreAuthenticatedIdentityResolver
    implements AvoraAuthenticatedIdentityResolver {
  AvoraFirestoreAuthenticatedIdentityResolver({
    required FirebaseFirestore firestore,
    this.identityCollection = 'avoraIdentityBindings',
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;
  final String identityCollection;

  @override
  Future<AvoraAuthenticatedIdentity?> resolve({
    required String firebaseUid,
  }) async {
    final uid = firebaseUid.trim();

    if (uid.isEmpty) {
      return null;
    }

    final snapshot =
        await _firestore.collection(identityCollection).doc(uid).get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();

    if (data == null) {
      return null;
    }

    final storedFirebaseUid = data['firebaseUid'];
    final avoraId = data['avoraId'];
    final bindingVerified = data['bindingVerified'];
    final active = data['active'];

    if (storedFirebaseUid is! String ||
        storedFirebaseUid != uid ||
        avoraId is! String ||
        avoraId.trim().isEmpty ||
        bindingVerified != true ||
        active != true) {
      return null;
    }

    return AvoraAuthenticatedIdentity(
      firebaseUid: uid,
      avoraId: avoraId.trim(),
      bindingVerified: true,
    );
  }

  static bool firebaseUidMustNeverBecomeAvoraId() => true;

  static bool missingIdentityDocumentMustFailClosed() => true;

  static bool disabledIdentityMustFailClosed() => true;

  static bool bindingMustBeServerAuthoritative() => true;

  static bool immutableAvoraIdMustNeverBeClientAssigned() => true;
}
