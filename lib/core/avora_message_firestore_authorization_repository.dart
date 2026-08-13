import 'package:cloud_firestore/cloud_firestore.dart';

import 'avora_message_authorization_repository.dart';

class AvoraFirestoreMessageAuthorizationRepository
    implements AvoraMessageAuthorizationRepository {
  AvoraFirestoreMessageAuthorizationRepository({
    required FirebaseFirestore firestore,
    this.roomMembershipCollection = 'roomMemberships',
    this.inboxMembershipCollection = 'inboxMemberships',
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  final String roomMembershipCollection;
  final String inboxMembershipCollection;

  @override
  Future<bool> isRoomMember({
    required String roomId,
    required String avoraId,
  }) async {
    final normalizedRoomId = roomId.trim();
    final normalizedAvoraId = avoraId.trim();

    if (normalizedRoomId.isEmpty || normalizedAvoraId.isEmpty) {
      return false;
    }

    final docId = '${normalizedRoomId}_$normalizedAvoraId';

    final snapshot =
        await _firestore.collection(roomMembershipCollection).doc(docId).get();

    if (!snapshot.exists) {
      return false;
    }

    final data = snapshot.data();

    if (data == null) {
      return false;
    }

    return data['roomId'] == normalizedRoomId &&
        data['avoraId'] == normalizedAvoraId &&
        data['active'] == true;
  }

  @override
  Future<bool> isInboxParticipant({
    required String conversationId,
    required String avoraId,
  }) async {
    final normalizedConversationId = conversationId.trim();
    final normalizedAvoraId = avoraId.trim();

    if (normalizedConversationId.isEmpty || normalizedAvoraId.isEmpty) {
      return false;
    }

    final docId = '${normalizedConversationId}_$normalizedAvoraId';

    final snapshot =
        await _firestore.collection(inboxMembershipCollection).doc(docId).get();

    if (!snapshot.exists) {
      return false;
    }

    final data = snapshot.data();

    if (data == null) {
      return false;
    }

    return data['conversationId'] == normalizedConversationId &&
        data['avoraId'] == normalizedAvoraId &&
        data['active'] == true;
  }

  static bool membershipMustBeServerControlled() => true;

  static bool inactiveMembershipMustFailClosed() => true;

  static bool membershipDocumentIdentityMustBeDeterministic() => true;
}
