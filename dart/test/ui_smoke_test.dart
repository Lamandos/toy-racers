import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:toy_racers/game/toy_racers_game.dart';
import 'package:toy_racers/game/ui/race_hud_overlay.dart';
import 'package:toy_racers/main.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  testWidgets('smoke: menu, selections, race controls, and results', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final game = await ToyRacersGame.loadDefault();
    TrackId? selectedTrack;
    CarModel? selectedCar;

    await tester.pumpWidget(
      ToyRacersApplication(
        showTouchControls: false,
        raceGameLoader: ({required trackId, required playerCarModel}) {
          selectedTrack = trackId;
          selectedCar = playerCarModel;
          return Future<ToyRacersGame>.value(game);
        },
      ),
    );

    expect(find.text('TOY RACERS'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('main-menu-play')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('main-menu-play')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('car-yellow-sport')));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('car-yellow-sport')),
        matching: find.text('SELECTED'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('continue-to-track')));
    await tester.pumpAndSettle();
    expect(find.text('SELECT TRACK'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('track-track-02')));
    await tester.pump();
    await tester.pump();

    expect(selectedCar, CarModel.yellowSport);
    expect(selectedTrack, TrackId.bathroom);
    expect(find.byType(GameWidget<ToyRacersGame>), findsOneWidget);
    await game.toBeLoaded();
    await tester.pump();
    expect(find.byType(RaceCountdownOverlay), findsOneWidget);

    _completeCountdownWithoutPhysics(game);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('pause-race')));
    await tester.pump();
    expect(find.text('PAUSED'), findsOneWidget);

    await tester.tap(find.text('RESUME'));
    await tester.pump();
    expect(find.text('PAUSED'), findsNothing);

    _injectFinishedSimulationState(game.session);
    game.update(0);
    for (var frame = 0; frame < 4; frame++) {
      game.update(CarPhysics.maxFrameDeltaSeconds);
    }
    await tester.pump();
    expect(find.text('RACE RESULTS'), findsOneWidget);
    expect(find.textContaining('POSITION 1 / 6'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

void _completeCountdownWithoutPhysics(ToyRacersGame game) {
  game.session.advanceLifecycle(
    elapsedSeconds: game.session.raceState.countdownDurationSeconds,
  );
  game.update(0);
}

void _injectFinishedSimulationState(RaceSession session) {
  session.player.progress
    ..finished = true
    ..finishPosition = 1
    ..totalRaceTime = 12.34;
  session.synchronizeFinishOrdering();
  session.raceState.finish();
}
