import 'package:avora/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AVORA username normalization', () {
    test('normalizes supported usernames', () {
      expect(normalizeAvoraUsername('  Avora_User01  '), 'avora_user01');
    });

    test('removes unsupported characters', () {
      expect(normalizeAvoraUsername('A-v.o r@a'), 'avora');
    });
  });
}
