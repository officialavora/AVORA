import 'package:cloud_firestore/cloud_firestore.dart';

class AvoraUsernameRepository {
  AvoraUsernameRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static String normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');

  Future<void> rename({
    required String uid,
    required String requestedUsername,
  }) async {
    final normalized = normalize(requestedUsername);
    if (!RegExp(r'^[a-z][a-z0-9_]{3,19}$').hasMatch(normalized)) {
      throw ArgumentError(
        'Username must start with a letter and contain 4-20 letters, numbers or underscores',
      );
    }

    final userRef = _firestore.collection('users').doc(uid);
    final newUsernameRef = _firestore.collection('usernames').doc(normalized);

    await _firestore.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      final user = userSnapshot.data();
      if (!userSnapshot.exists || user == null) {
        throw StateError('AVORA profile was not found');
      }

      final oldUsername = user['username'] as String?;
      final avoraId = user['originalAvoraId'] as int?;
      if (oldUsername == null || avoraId == null) {
        throw StateError('AVORA identity is incomplete');
      }
      if (oldUsername == normalized) return;

      final newReservation = await transaction.get(newUsernameRef);
      if (newReservation.exists) {
        throw StateError('Username is already taken or permanently reserved');
      }

      final oldHistoryRef =
          _firestore.collection('usernameHistory').doc(oldUsername);
      final auditRef = _firestore.collection('identityAudit').doc();

      transaction.set(newUsernameRef, {
        'uid': uid,
        'username': normalized,
        'avoraId': avoraId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(oldHistoryRef, {
        'uid': uid,
        'username': oldUsername,
        'replacementUsername': normalized,
        'avoraId': avoraId,
        'reservedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(auditRef, {
        'action': 'username.rename',
        'uid': uid,
        'oldUsername': oldUsername,
        'newUsername': normalized,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(userRef, {
        'username': normalized,
        'usernameChangedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
