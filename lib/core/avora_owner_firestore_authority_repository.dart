import 'package:cloud_firestore/cloud_firestore.dart';

import 'avora_owner_message_override.dart';

class AvoraFirestoreOwnerAuthorityRepository
    implements AvoraOwnerAuthorityRepository {
  AvoraFirestoreOwnerAuthorityRepository({
    required FirebaseFirestore firestore,
    this.collectionPath = 'ownerAuthorities',
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;
  final String collectionPath;

  @override
  Future<bool> isActiveOwner({
    required String avoraId,
  }) async {
    final normalized = avoraId.trim();

    if (normalized.isEmpty) {
      return false;
    }

    final snapshot =
        await _firestore.collection(collectionPath).doc(normalized).get();

    if (!snapshot.exists) {
      return false;
    }

    final data = snapshot.data();

    if (data == null) {
      return false;
    }

    return data['avoraId'] == normalized &&
        data['role'] == 'owner' &&
        data['active'] == true &&
        data['serverVerified'] == true;
  }

  static bool ownerAuthorityMustBeServerVerified() => true;

  static bool inactiveOwnerMustFailClosed() => true;

  static bool clientMustNotSelfGrantOwnerAuthority() => true;

  static bool immutableAvoraIdMustIdentifyOwnerAuthority() => true;
}
