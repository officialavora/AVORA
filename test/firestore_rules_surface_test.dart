import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firestore rules protect identity and allow signed-in demo flows', () {
    final rules = File('firestore.rules').readAsStringSync();

    expect(rules, contains('request.resource.data.originalAvoraId == resource.data.originalAvoraId'));
    expect(rules, contains("request.resource.data.role == resource.data.role"));
    expect(rules, contains('request.resource.data.ownerUid == request.auth.uid'));
    expect(rules, contains("match /rooms/{roomId}"));
    expect(rules, contains("match /members/{uid}"));
    expect(rules, contains("request.resource.data.userUid == uid"));
    expect(rules, contains("match /supportTickets/{ticketId}"));
    expect(rules, contains('allow read, write: if false'));
  });
}
