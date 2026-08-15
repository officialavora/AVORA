import 'package:avora/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login password visibility can be toggled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(onDemoLogin: () {}),
      ),
    );

    expect(find.byTooltip('Show password'), findsOneWidget);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();

    expect(find.byTooltip('Hide password'), findsOneWidget);
  });

  testWidgets('signup password visibility can be toggled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SignupScreen()),
    );

    expect(find.byTooltip('Show password'), findsOneWidget);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();

    expect(find.byTooltip('Hide password'), findsOneWidget);
  });
}
