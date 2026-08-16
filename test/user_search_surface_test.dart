import 'package:avora/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AVORA ID search exposes field and explicit search action',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: UserSearchPage()));

    expect(find.byKey(const Key('user-search-field')), findsOneWidget);
    expect(find.byKey(const Key('user-search-submit')), findsOneWidget);
    expect(find.text('Search AVORA ID'), findsOneWidget);
  });
}
