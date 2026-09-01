import 'package:avora/ui/avora_games_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ships 43 unique original games across all engines', () {
    expect(avoraGames, hasLength(43));
    expect(avoraGames.map((game) => game.name).toSet(), hasLength(43));
    expect(
      avoraGames.map((game) => game.engine).toSet(),
      containsAll(AvoraGameEngine.values),
    );
  });
}
