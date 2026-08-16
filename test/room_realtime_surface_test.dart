import 'package:avora/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('room exposes reconnect chat seats and speaker controls', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VoiceRoomScreen(
          roomName: 'Realtime Test',
          themeName: 'Ocean',
          seatCount: 8,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('room-reconnect')), findsOneWidget);
    expect(find.byKey(const Key('voice-room-chat')), findsOneWidget);
    expect(find.byKey(const Key('room-activity-strip')), findsOneWidget);
    expect(find.text('Speaker'), findsOneWidget);

    await tester.tap(find.byKey(const Key('voice-seat-1')));
    await tester.pump();
    expect(find.text('You'), findsOneWidget);

    await tester.tap(find.text('Speaker'));
    await tester.pump();
    expect(find.text('Muted'), findsOneWidget);
  });

  testWidgets('host seat remains protected for guests', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VoiceRoomScreen(
          roomName: 'Guest Test',
          themeName: 'Night',
          seatCount: 8,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('voice-seat-0')));
    await tester.pump();
    expect(find.text('The host seat is reserved for the room owner.'), findsOneWidget);
  });
}
