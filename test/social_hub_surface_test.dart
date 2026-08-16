import 'package:avora/features/social/avora_social_hub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('social hub exposes required AVORA relationship tabs', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AvoraSocialHubPage(account: {
        'friendsCount': 2,
        'followersCount': 3,
        'followingCount': 4,
        'visitorsCount': 5,
        'giftersCount': 6,
      }),
    ));

    expect(find.text('Friends 2'), findsOneWidget);
    expect(find.text('Followers 3'), findsOneWidget);
    expect(find.text('Following 4'), findsOneWidget);
    expect(find.text('Visitors 5'), findsOneWidget);
    expect(find.text('Gifters 6'), findsOneWidget);
  });
}
