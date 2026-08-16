import 'package:avora/features/profile/avora_prestige_showcase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile prestige exposes original AVORA gift and photo walls', (tester) async {
    var photoTapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AvoraPrestigeShowcase(
          account: const {
            'richLevel': 2,
            'charmLevel': 3,
            'vipLevel': 1,
            'giftersCount': 4,
          },
          onPhotoTap: () => photoTapped = true,
        ),
      ),
    ));

    expect(find.text('Medal'), findsOneWidget);
    expect(find.text('Level 5'), findsOneWidget);
    expect(find.text('VIP 1'), findsOneWidget);
    expect(find.text('Gift Wall'), findsOneWidget);
    expect(find.text('Photo Wall'), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-gift-wall')));
    await tester.pumpAndSettle();
    expect(find.text('AVORA Gift Wall'), findsOneWidget);
    expect(find.text('AVORA Crown'), findsOneWidget);

    Navigator.of(tester.element(find.text('AVORA Gift Wall'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-photo-wall')));
    expect(photoTapped, isTrue);
  });
}
