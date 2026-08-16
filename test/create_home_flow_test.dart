import 'package:avora/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home voice rooms action opens discovery', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    await tester.tap(find.text('Voice Rooms'));
    // The cinematic backdrop intentionally runs continuously. Pump one frame
    // to complete the synchronous navigation without waiting for it to settle.
    await tester.pump();

    expect(find.text('Rooms'), findsOneWidget);
    expect(find.text('Create room'), findsOneWidget);
  });

  testWidgets('create hub opens voice room setup', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CreateHubPage()));

    await tester.tap(find.byKey(const Key('create-hub-voice-room')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-room-name')), findsOneWidget);
    expect(find.byKey(const Key('create-room-submit')), findsOneWidget);
  });
}
