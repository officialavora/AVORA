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

  testWidgets('voice room exposes royal seats and testable mic state', (tester) async {
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
    expect(find.byKey(const Key('voice-seat-0')), findsOneWidget);
    expect(find.byKey(const Key('voice-seat-1')), findsOneWidget);
    final lowerSeatGrid = tester.widget<GridView>(
      find.byKey(const Key('voice-room-seats')),
    );
    expect(lowerSeatGrid.semanticChildCount, 8);
    expect(find.text('Mic off'), findsOneWidget);

    await tester.tap(find.byKey(const Key('voice-room-mic')));
    await tester.pump();

    expect(find.text('Mic on'), findsOneWidget);
  });
}
