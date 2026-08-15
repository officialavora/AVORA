import 'package:avora/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('create room validates its required name', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CreateRoomScreen()),
    );

    await tester.tap(find.byKey(const Key('create-room-submit')));
    await tester.pump();

    expect(find.text('Please enter a room name.'), findsOneWidget);
  });

  testWidgets('voice room exposes seats and testable mic state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VoiceRoomScreen(
          roomName: 'AVORA Test Room',
          themeName: 'Aurora',
          seatCount: 10,
          isOwner: true,
        ),
      ),
    );

    expect(find.text('AVORA Test Room'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('voice-seat-9')),
      240,
      scrollable: find.byKey(const Key('voice-room-seats')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('voice-seat-9')), findsOneWidget);
    expect(find.text('Mic off'), findsOneWidget);

    await tester.tap(find.byKey(const Key('voice-room-mic')));
    await tester.pumpAndSettle();

    expect(find.text('Mic on'), findsOneWidget);
  });
}
