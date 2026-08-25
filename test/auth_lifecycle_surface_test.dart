import 'package:avora/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login exposes recovery, Google, and account creation routes',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(onDemoLogin: () {})),
    );

    expect(find.byKey(const Key('email-login-submit')), findsOneWidget);
    expect(find.byKey(const Key('google-login-submit')), findsOneWidget);
    expect(find.text('Forgot password'), findsOneWidget);
    expect(find.byKey(const Key('open-signup-from-login')), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-signup-from-login')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('google-signup-submit')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('email-signup-submit')),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('email-signup-submit')), findsOneWidget);
  });

  testWidgets('profile sign out requires explicit confirmation',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AvoraSignOutConfirmationDialog()),
      ),
    );

    expect(find.text('Sign out of AVORA?'), findsOneWidget);
    expect(find.textContaining('permanent AVORA ID'), findsOneWidget);
    expect(find.byKey(const Key('confirm-sign-out')), findsOneWidget);
  });
}
