import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AvoraTestGift {
  const AvoraTestGift({
    required this.id,
    required this.name,
    required this.emoji,
    required this.price,
    required this.tier,
  });

  final String id;
  final String name;
  final String emoji;
  final int price;
  final String tier;
}

const avoraTestGifts = <AvoraTestGift>[
  AvoraTestGift(id: 'rose', name: 'Royal Rose', emoji: '🌹', price: 10, tier: 'Fun'),
  AvoraTestGift(id: 'heart', name: 'Love Beam', emoji: '💖', price: 50, tier: 'Romance'),
  AvoraTestGift(id: 'crown', name: 'Golden Crown', emoji: '👑', price: 250, tier: 'Luxury'),
  AvoraTestGift(id: 'tiger', name: 'Royal Tiger', emoji: '🐯', price: 1000, tier: 'Cinematic'),
];

class AvoraTestEconomyService {
  AvoraTestEconomyService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static const initialTestCoins = 100000;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Sign in to use test coins.');
    return uid;
  }

  DocumentReference<Map<String, dynamic>> wallet(String uid) =>
      _firestore.collection('testWallets').doc(uid);

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchMyWallet() =>
      wallet(_uid).snapshots();

  Future<void> ensureWallet() async {
    final uid = _uid;
    final reference = wallet(uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (snapshot.exists) return;
      transaction.set(reference, {
        'ownerUid': uid,
        'testCoins': initialTestCoins,
        'testDiamonds': 0,
        'sentValue': 0,
        'receivedValue': 0,
        'lastTransactionId': 'initial',
        'environment': 'test',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<String> sendGift({
    required String roomId,
    required String receiverUid,
    required AvoraTestGift gift,
    required int quantity,
  }) async {
    if (quantity < 1 || quantity > 99) {
      throw ArgumentError('Combo must be between 1 and 99.');
    }
    final senderUid = _uid;
    if (receiverUid == senderUid) {
      throw ArgumentError('Choose another person in the room.');
    }
    final transactionId =
        '${DateTime.now().microsecondsSinceEpoch}_$senderUid';
    final senderRef = wallet(senderUid);
    final receiverRef = wallet(receiverUid);
    final ledgerRef = _firestore.collection('testGiftLedger').doc(transactionId);
    final total = gift.price * quantity;

    await _firestore.runTransaction((transaction) async {
      final sender = await transaction.get(senderRef);
      final receiver = await transaction.get(receiverRef);
      if (!sender.exists) throw StateError('Your test wallet is not ready.');
      if (!receiver.exists) {
        throw StateError('The receiver must open AVORA once to activate test coins.');
      }
      final senderData = sender.data()!;
      final receiverData = receiver.data()!;
      final senderBalance = (senderData['testCoins'] as num?)?.toInt() ?? 0;
      final receiverBalance = (receiverData['testCoins'] as num?)?.toInt() ?? 0;
      if (senderBalance < total) throw StateError('Not enough test coins.');

      transaction.update(senderRef, {
        'testCoins': senderBalance - total,
        'sentValue': ((senderData['sentValue'] as num?)?.toInt() ?? 0) + total,
        'lastTransactionId': transactionId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(receiverRef, {
        'testCoins': receiverBalance + total,
        'receivedValue':
            ((receiverData['receivedValue'] as num?)?.toInt() ?? 0) + total,
        'lastTransactionId': transactionId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(ledgerRef, {
        'transactionId': transactionId,
        'environment': 'test',
        'roomId': roomId,
        'senderUid': senderUid,
        'receiverUid': receiverUid,
        'giftId': gift.id,
        'giftName': gift.name,
        'giftEmoji': gift.emoji,
        'unitPrice': gift.price,
        'quantity': quantity,
        'debitedCoins': total,
        'status': 'committed',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return transactionId;
  }
}
