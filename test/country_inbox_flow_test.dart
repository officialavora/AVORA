import 'package:avora/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('signup country is suggested and remains user selectable', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    final country = find.byKey(const Key('signup-country'));
    expect(country, findsOneWidget);
    expect(find.textContaining('Suggested from your device region'), findsOneWidget);

    final field = tester.widget<DropdownButtonFormField<String>>(country);
    final countryCodes = field.items!
        .map((item) => item.value)
        .whereType<String>()
        .toSet();
    expect(countryCodes, containsAll(<String>{'SA', 'IN', 'PK'}));
  });

  testWidgets('inbox sections navigate to contact form', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MessagesPage()));

    expect(find.text('Your activity'), findsOneWidget);
    await tester.tap(find.byKey(const Key('inbox-section-2')));
    await tester.pumpAndSettle();
    expect(find.text('Contact AVORA'), findsOneWidget);

    await tester.tap(find.byKey(const Key('contact-avora')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-subject')), findsOneWidget);
    expect(find.byKey(const Key('support-message')), findsOneWidget);
  });
}
