import 'package:avora/features/games/avora_fun_arcade.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fun arcade exposes three playable test games', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AvoraFunArcadePage()),
    );

    expect(find.byKey(const Key('ludo-dice-game')), findsOneWidget);
    expect(find.byKey(const Key('double-seven-game')), findsOneWidget);
    expect(find.byKey(const Key('lucky-wheel-game')), findsOneWidget);
    expect(find.textContaining('no purchase'), findsOneWidget);

    await tester.tap(find.text('ROLL'));
    await tester.pump();
    expect(find.textContaining('Ludo Dice'), findsWidgets);

    await tester.tap(find.text('PLAY'));
    await tester.pump();
    expect(find.textContaining('Double Seven'), findsWidgets);

    await tester.tap(find.text('SPIN'));
    await tester.pump();
    expect(find.textContaining('Lucky Wheel'), findsWidgets);
  });
}
