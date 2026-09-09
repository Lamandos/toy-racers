import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/game/toy_racers_game.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final difficulty in AiDifficulty.values) {
    test(
      'applies ${difficulty.name} to every opponent and preserves it on restart',
      () async {
        final game = await ToyRacersGame.loadRace(
          trackId: TrackId.livingRoom,
          playerCarModel: CarModel.redStripe,
          opponentDifficulty: difficulty,
        );
        for (final opponent in game.session.opponents) {
          expect(
            (opponent.aiDriver as ReferenceAiDriver).difficulty,
            difficulty,
          );
        }
        game.restartRace();
        for (final opponent in game.session.opponents) {
          expect(
            (opponent.aiDriver as ReferenceAiDriver).difficulty,
            difficulty,
          );
        }
        game.dispose();
      },
    );
  }
}
