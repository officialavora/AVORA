import 'dart:math';

import 'package:flutter/material.dart';

class AvoraFunArcadePage extends StatefulWidget {
  const AvoraFunArcadePage({super.key});

  @override
  State<AvoraFunArcadePage> createState() => _AvoraFunArcadePageState();
}

class _AvoraFunArcadePageState extends State<AvoraFunArcadePage> {
  final _random = Random();
  int dice = 1;
  int leftSeven = 3;
  int rightSeven = 4;
  int wheelIndex = 0;
  String activity = 'Choose a game and play a free test round.';

  static const wheelPrizes = <String>[
    'Royal Rose',
    '10 Test Coins',
    'Sparkle Entry',
    'Better luck next round',
    '25 Test Coins',
    'AVORA Badge',
  ];

  void rollDice() {
    setState(() {
      dice = _random.nextInt(6) + 1;
      activity = dice == 6
          ? 'Ludo Dice: Six! You earned a test celebration.'
          : 'Ludo Dice rolled $dice.';
    });
  }

  void rollSeven() {
    setState(() {
      leftSeven = _random.nextInt(6) + 1;
      rightSeven = _random.nextInt(6) + 1;
      final total = leftSeven + rightSeven;
      activity = total == 7
          ? 'Double Seven: Perfect seven — test win!'
          : 'Double Seven total: $total. Try again.';
    });
  }

  void spinWheel() {
    setState(() {
      wheelIndex = _random.nextInt(wheelPrizes.length);
      activity = 'Lucky Wheel: ${wheelPrizes[wheelIndex]}.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AVORA Fun Arcade')),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF25104B), Color(0xFF090611)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0x557C4DFF), blurRadius: 28),
                ],
              ),
              child: const Column(
                children: [
                  Icon(Icons.sports_esports_rounded, size: 48),
                  SizedBox(height: 8),
                  Text('Play together',
                      style:
                          TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                  SizedBox(height: 6),
                  Text(
                    'Free test games • no purchase • no withdrawal',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _GameCard(
              key: const Key('ludo-dice-game'),
              icon: '🎲',
              title: 'Ludo Dice',
              subtitle: 'Quick room-time dice roll',
              result: '$dice',
              button: 'ROLL',
              onPlay: rollDice,
            ),
            _GameCard(
              key: const Key('double-seven-game'),
              icon: '7️⃣',
              title: 'Double Seven',
              subtitle: 'Roll two dice and match seven',
              result: '$leftSeven + $rightSeven',
              button: 'PLAY',
              onPlay: rollSeven,
            ),
            _GameCard(
              key: const Key('lucky-wheel-game'),
              icon: '🎡',
              title: 'Lucky Wheel',
              subtitle: 'A free test reward spin',
              result: wheelPrizes[wheelIndex],
              button: 'SPIN',
              onPlay: spinWheel,
            ),
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Container(
                key: const Key('arcade-activity'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x55FFD166)),
                ),
                child: Text(activity, textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'TEST ARCADE: Results are for entertainment testing only. '
              'They do not create money, diamonds, withdrawals or purchasable value.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.result,
    required this.button,
    required this.onPlay,
  });

  final String icon;
  final String title;
  final String subtitle;
  final String result;
  final String button;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(icon, style: const TextStyle(fontSize: 30)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(subtitle,
                      style: const TextStyle(color: Colors.white60)),
                  const SizedBox(height: 5),
                  Text(result,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFFFFD166))),
                ],
              ),
            ),
            FilledButton(onPressed: onPlay, child: Text(button)),
          ],
        ),
      ),
    );
  }
}
