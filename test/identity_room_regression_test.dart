import 'dart:convert';
import 'dart:io';

import 'package:avora/main.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each owner uses one deterministic permanent room document', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains("collection('rooms').doc(user.uid)"));
    expect(source, isNot(contains("collection('rooms').add({")));
  });

  test('completed auth clears the welcome and signup back stack', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, contains('pushAndRemoveUntil'));
    expect(source, contains('(_) => false'));
  });

  test('free profile photo data renders without paid cloud storage', () {
    final transparentPixel = base64Encode(<int>[
      137, 80, 78, 71, 13, 10, 26, 10,
    ]);
    final provider = avoraProfileImage({
      'photoDataUrl': 'data:image/png;base64,$transparentPixel',
    });
    expect(provider, isA<MemoryImage>());
  });
}
