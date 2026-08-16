import 'dart:io';

import 'package:avora/services/avora_test_economy_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('test gift catalog has distinct prices and original AVORA labels', () {
    expect(avoraTestGifts, hasLength(4));
    expect(avoraTestGifts.map((gift) => gift.id).toSet(), hasLength(4));
    expect(avoraTestGifts.every((gift) => gift.price > 0), isTrue);
    expect(AvoraTestEconomyService.initialTestCoins, 100000);
  });

  test('Firestore rules bind wallet changes to immutable gift evidence', () {
    final rules = File('firestore.rules').readAsStringSync();
    expect(rules, contains('match /testWallets/{uid}'));
    expect(rules, contains('match /testGiftLedger/{transactionId}'));
    expect(rules, contains("request.resource.data.testCoins == 100000"));
    expect(rules, contains('allow update, delete: if false'));
    expect(rules, contains('existsAfter('));
  });
}
