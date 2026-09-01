import 'dart:math';

import 'package:flutter/material.dart';

enum AvoraGameEngine { wheel, slot, cards, board, arcade, party }

class AvoraGameSpec {
  const AvoraGameSpec(this.name, this.engine, this.icon);
  final String name;
  final AvoraGameEngine engine;
  final String icon;
}

const avoraGames = <AvoraGameSpec>[
  AvoraGameSpec('Funny Dice', AvoraGameEngine.party, '🎲'),
  AvoraGameSpec('Lucky Number', AvoraGameEngine.party, '🔢'),
  AvoraGameSpec('Coin Flip', AvoraGameEngine.party, '🪙'),
  AvoraGameSpec('RPS Spin', AvoraGameEngine.party, '✊'),
  AvoraGameSpec('Emoji Battle', AvoraGameEngine.party, '😂'),
  AvoraGameSpec('Truth / Dare', AvoraGameEngine.party, '🎭'),
  AvoraGameSpec('Mood Spin', AvoraGameEngine.party, '🌈'),
  AvoraGameSpec('Who Next?', AvoraGameEngine.party, '🎤'),
  AvoraGameSpec('Mic Number PK', AvoraGameEngine.party, '🎙️'),
  AvoraGameSpec('Room Vote', AvoraGameEngine.party, '🗳️'),
  AvoraGameSpec('Ferris Wheel', AvoraGameEngine.wheel, '🎡'),
  AvoraGameSpec('Food Ferris', AvoraGameEngine.wheel, '🍕'),
  AvoraGameSpec('Fruit Mix', AvoraGameEngine.wheel, '🍓'),
  AvoraGameSpec('Magic Slot', AvoraGameEngine.slot, '🎰'),
  AvoraGameSpec('Color Roulette', AvoraGameEngine.wheel, '🎯'),
  AvoraGameSpec('Funny Jackpot', AvoraGameEngine.slot, '🏆'),
  AvoraGameSpec('Lucky Box', AvoraGameEngine.arcade, '🎁'),
  AvoraGameSpec('Big Winner', AvoraGameEngine.wheel, '👑'),
  AvoraGameSpec('Room Rocket', AvoraGameEngine.arcade, '🚀'),
  AvoraGameSpec('Rocket Rush', AvoraGameEngine.arcade, '🌌'),
  AvoraGameSpec('Fishing Rush', AvoraGameEngine.arcade, '🎣'),
  AvoraGameSpec('Greedy Crown', AvoraGameEngine.wheel, '👑'),
  AvoraGameSpec('Greedy Line', AvoraGameEngine.arcade, '💎'),
  AvoraGameSpec('Football Shot', AvoraGameEngine.arcade, '⚽'),
  AvoraGameSpec('Pyramid Pick', AvoraGameEngine.arcade, '🔺'),
  AvoraGameSpec('Room Rally', AvoraGameEngine.arcade, '🏁'),
  AvoraGameSpec('Sun & Moon', AvoraGameEngine.party, '☀️'),
  AvoraGameSpec('Tiger Pick', AvoraGameEngine.party, '🐅'),
  AvoraGameSpec('Buffalo Charge', AvoraGameEngine.arcade, '🐃'),
  AvoraGameSpec('Burst Crystal', AvoraGameEngine.arcade, '💎'),
  AvoraGameSpec('Draw & Guess', AvoraGameEngine.party, '🎨'),
  AvoraGameSpec('Three Card Fun', AvoraGameEngine.cards, '🃏'),
  AvoraGameSpec('Dragon & Tiger', AvoraGameEngine.cards, '🐉'),
  AvoraGameSpec('Lion & Tiger', AvoraGameEngine.cards, '🦁'),
  AvoraGameSpec('Royal Battle', AvoraGameEngine.cards, '♛️'),
  AvoraGameSpec('Ludo Sprint', AvoraGameEngine.board, '🎲'),
  AvoraGameSpec('Snake & Ladder', AvoraGameEngine.board, '🐍'),
  AvoraGameSpec('Domino Duel', AvoraGameEngine.board, '🎴'),
  AvoraGameSpec('Color Drop Cards', AvoraGameEngine.cards, '🎨'),
  AvoraGameSpec('Carrom Shot', AvoraGameEngine.arcade, '🎯'),
  AvoraGameSpec('Pool Shot', AvoraGameEngine.arcade, '🎱'),
  AvoraGameSpec('Marble Relay', AvoraGameEngine.board, '🔵'),
  AvoraGameSpec('Trick Cards', AvoraGameEngine.cards, '♠️'),
];

class AvoraGamesScreen extends StatefulWidget {
  const AvoraGamesScreen({super.key});
  @override
  State<AvoraGamesScreen> createState() => _AvoraGamesScreenState();
}

class _AvoraGamesScreenState extends State<AvoraGamesScreen> {
  AvoraGameEngine? filter;
  @override
  Widget build(BuildContext context) {
    final visible = filter == null
        ? avoraGames
        : avoraGames.where((game) => game.engine == filter).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('AVORA Games')),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(
          colors: [Color(0xFF27145D), Color(0xFF0D0A1A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        )),
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), gradient: const LinearGradient(colors: [Color(0xFFFF3D92), Color(0xFF7C4DFF), Color(0xFF00B8D4)])),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PLAY TOGETHER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
              Text('43 original games', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
              Text('Playable in AVORA • No external game server'),
            ]),
          )),
          SliverToBoxAdapter(child: SizedBox(height: 50, child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            children: [
              _chip('ALL', null),
              for (final engine in AvoraGameEngine.values) _chip(engine.name.toUpperCase(), engine),
            ],
          ))),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
            sliver: SliverGrid.builder(
              itemCount: visible.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .78),
              itemBuilder: (_, index) => _GameTile(game: visible[index]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String label, AvoraGameEngine? value) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(label: Text(label), selected: filter == value, onSelected: (_) => setState(() => filter = value)),
  );
}

class _GameTile extends StatelessWidget {
  const _GameTile({required this.game});
  final AvoraGameSpec game;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .08),
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AvoraGameRoom(game: game))),
      child: Padding(padding: const EdgeInsets.all(9), child: Column(children: [
        Expanded(child: Container(alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: gameColors(game.engine))), child: Text(game.icon, style: const TextStyle(fontSize: 34)))),
        const SizedBox(height: 7),
        Text(game.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
      ])),
    ),
  );
}

class AvoraGameRoom extends StatefulWidget {
  const AvoraGameRoom({super.key, required this.game});
  final AvoraGameSpec game;
  @override
  State<AvoraGameRoom> createState() => _AvoraGameRoomState();
}

class _AvoraGameRoomState extends State<AvoraGameRoom> {
  final random = Random();
  int round = 1, balance = 10000, stake = 100, tick = 0;
  bool running = false;
  String result = 'Choose a chip and start';
  final history = <String>[];

  List<String> get symbols => switch (widget.game.name) {
    'Funny Dice' => ['1', '2', '3', '4', '5', '6'],
    'Lucky Number' => ['7', '11', '22', '44', '77', '99'],
    'Coin Flip' => ['HEADS', 'TAILS'],
    'RPS Spin' => ['ROCK', 'PAPER', 'SCISSORS'],
    'Emoji Battle' => ['😂', '😍', '😡', '🤯', '🥳'],
    'Truth / Dare' => ['TRUTH', 'DARE'],
    'Mood Spin' => ['HAPPY', 'CHILL', 'HYPE', 'SILLY', 'CALM'],
    'Who Next?' => ['SEAT 1', 'SEAT 2', 'SEAT 3', 'SEAT 4', 'SEAT 5'],
    'Mic Number PK' => ['MIC 1', 'MIC 2', 'MIC 3', 'MIC 4'],
    'Room Vote' => ['OPTION A', 'OPTION B', 'OPTION C'],
    'Food Ferris' => ['🍕', '🍔', '🍣', '🍗', '🍜', '🥗'],
    'Fruit Mix' => ['🍓', '🍉', '🍒', '🍇', '🍋', '🥝'],
    'Color Roulette' => ['RED', 'BLACK', 'ODD', 'EVEN', '1–12', '13–24', '25–36'],
    'Greedy Crown' => ['CAT', 'LION', 'TIGER', 'MONKEY', 'ELEPHANT', 'CROWN'],
    'Magic Slot' || 'Funny Jackpot' => ['7️⃣', '💎', '🍒', '🔔', '⭐', '🍀'],
    'Lucky Box' => ['BRONZE', 'SILVER', 'GOLD', 'DIAMOND'],
    'Room Rocket' || 'Rocket Rush' => ['1.2x', '1.5x', '2x', '5x', '10x'],
    'Fishing Rush' => ['SHRIMP', 'FISH', 'TURTLE', 'SHARK', 'GOLD FISH'],
    'Greedy Line' => ['SAFE', 'SAFE', 'BONUS', 'DOUBLE', 'STOP'],
    'Football Shot' => ['LEFT', 'CENTER', 'RIGHT', 'GOAL', 'SAVE'],
    'Pyramid Pick' => ['RED', 'BLUE', 'GREEN'],
    'Room Rally' => ['RED CAR', 'BLUE CAR', 'GREEN CAR', 'GOLD CAR'],
    'Sun & Moon' => ['SUN', 'MOON'],
    'Tiger Pick' => ['TIGER', 'FOREST', 'CROWN'],
    'Buffalo Charge' => ['LEFT', 'RIGHT', 'CHARGE', 'BONUS'],
    'Burst Crystal' => ['BLUE', 'PINK', 'GREEN', 'GOLD', 'BURST'],
    'Draw & Guess' => ['ANIMAL', 'FOOD', 'PLACE', 'OBJECT', 'EMOJI'],
    'Three Card Fun' => ['A♠', 'K♥', 'Q♦', 'J♣', '10♥', '9♠'],
    'Dragon & Tiger' => ['DRAGON', 'TIGER', 'TIE'],
    'Lion & Tiger' => ['LION', 'TIGER', 'TIE'],
    'Royal Battle' => ['SPADE', 'HEART', 'DIAMOND', 'CLUB'],
    'Ludo Sprint' => ['1', '2', '3', '4', '5', '6'],
    'Snake & Ladder' => ['1', '2', '3', '4', '5', '6', 'LADDER', 'SNAKE'],
    'Domino Duel' => ['0•0', '1•2', '2•3', '3•4', '5•5', '6•6'],
    'Color Drop Cards' => ['RED', 'BLUE', 'GREEN', 'YELLOW', 'WILD'],
    'Carrom Shot' => ['WHITE', 'BLACK', 'QUEEN', 'FOUL'],
    'Pool Shot' => ['SOLID', 'STRIPE', '8 BALL', 'FOUL'],
    'Marble Relay' => ['BLUE', 'RED', 'GREEN', 'YELLOW'],
    'Trick Cards' => ['SPADE', 'HEART', 'DIAMOND', 'CLUB', 'TRUMP'],
    _ => switch (widget.game.engine) {
    AvoraGameEngine.wheel => ['🍓', '🍉', '🥕', '🍕', '🍇', '🍋', '🍎', '🥝'],
    AvoraGameEngine.slot => ['7️⃣', '💎', '🍒', '🔔', '⭐', '🍀'],
    AvoraGameEngine.cards => ['A♠', 'K♥', 'Q♦', 'J♣', '10♥', '9♠'],
    AvoraGameEngine.board => ['1', '2', '3', '4', '5', '6'],
    AvoraGameEngine.arcade => ['PERFECT', 'GREAT', 'GOOD', 'MISS', 'BONUS'],
      AvoraGameEngine.party => ['YOU', 'FRIEND', 'TEAM A', 'TEAM B', 'EVERYONE'],
    },
  };

  Future<void> play() async {
    if (running || balance < stake) return;
    setState(() { running = true; balance -= stake; result = 'ROUND IN PROGRESS'; });
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      setState(() => tick = random.nextInt(symbols.length));
    }
    final multiplier = random.nextInt(100) < 38 ? [2, 3, 5, 10][random.nextInt(4)] : 0;
    final outcome = symbols[tick];
    setState(() {
      balance += stake * multiplier;
      result = multiplier == 0 ? '$outcome • NO WIN' : '$outcome • ${multiplier}x WIN';
      history.insert(0, outcome);
      if (history.length > 8) history.removeLast();
      running = false;
      round++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = gameColors(widget.game.engine);
    return Scaffold(body: Container(
      decoration: BoxDecoration(gradient: RadialGradient(center: Alignment.topCenter, radius: 1.25, colors: [colors.first, const Color(0xFF080612)])),
      child: SafeArea(child: Column(children: [
        Row(children: [
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          Expanded(child: Text(widget.game.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
          IconButton(onPressed: () {}, icon: const Icon(Icons.volume_up_outlined)),
        ]),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('ROUND $round'), Text('🪙 $balance', style: const TextStyle(fontWeight: FontWeight.w900))])),
        Expanded(child: Center(child: _visual(colors))),
        Text(result, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          for (final value in [10, 100, 1000, 10000]) Padding(padding: const EdgeInsets.only(right: 9), child: ChoiceChip(label: Text(compact(value)), selected: stake == value, onSelected: running ? null : (_) => setState(() => stake = value))),
        ])),
        if (history.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('History  ${history.join('  ')}', maxLines: 1, overflow: TextOverflow.ellipsis)),
        Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 18), child: SizedBox(width: double.infinity, height: 56, child: FilledButton(onPressed: running ? null : play, child: Text(running ? 'PLAYING…' : 'START • ${compact(stake)}')))),
      ])),
    ));
  }

  Widget _visual(List<Color> colors) {
    if (widget.game.engine == AvoraGameEngine.slot || widget.game.engine == AvoraGameEngine.cards) {
      return Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (index) => Container(
        margin: const EdgeInsets.all(5), width: 82, height: 120, alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: colors.last, width: 5)),
        child: Text(symbols[(tick + index) % symbols.length], style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF301049))),
      )));
    }
    if (widget.game.engine == AvoraGameEngine.board) {
      return Column(mainAxisSize: MainAxisSize.min, children: [const Text('🎲', style: TextStyle(fontSize: 100)), Text(symbols[tick], style: const TextStyle(fontSize: 55, fontWeight: FontWeight.w900))]);
    }
    return AnimatedRotation(
      turns: running ? 1 : 0,
      duration: const Duration(milliseconds: 900),
      child: Container(width: 250, height: 250, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, gradient: SweepGradient(colors: [...colors, ...colors.reversed]), border: Border.all(color: Colors.white, width: 7), boxShadow: [BoxShadow(color: colors.last.withValues(alpha: .55), blurRadius: 40)]), child: Container(width: 106, height: 106, alignment: Alignment.center, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF21123F)), child: Text(symbols[tick], textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)))),
    );
  }
}

String compact(int value) => value >= 1000 ? '${value ~/ 1000}K' : '$value';

List<Color> gameColors(AvoraGameEngine engine) => switch (engine) {
  AvoraGameEngine.wheel => const [Color(0xFFFF3D91), Color(0xFFFFC857), Color(0xFF7C4DFF)],
  AvoraGameEngine.slot => const [Color(0xFF7C1DFF), Color(0xFFFFC400), Color(0xFFE040FB)],
  AvoraGameEngine.cards => const [Color(0xFFB71C1C), Color(0xFFFF8A80), Color(0xFFFFC400)],
  AvoraGameEngine.board => const [Color(0xFF00BFA5), Color(0xFF00B8D4), Color(0xFF536DFE)],
  AvoraGameEngine.arcade => const [Color(0xFFFF6D00), Color(0xFFFFC400), Color(0xFF00C853)],
  AvoraGameEngine.party => const [Color(0xFFFF4081), Color(0xFF7C4DFF), Color(0xFF18FFFF)],
};
