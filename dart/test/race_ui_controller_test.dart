import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:toy_racers/game/race_results_overlay.dart';
import 'package:toy_racers/game/ui/race_hud_overlay.dart';
import 'package:toy_racers/game/ui/race_ui_controller.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  testWidgets('race overlays use only documented presentation commands', (
    tester,
  ) async {
    final controller = _FakeRaceUiController();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RaceHudOverlay(controller: controller),
      ),
    );

    expect(find.text('POSITION'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('pause-race')));

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RacePauseOverlay(controller: controller, onQuitToMenu: () {}),
      ),
    );

    await tester.tap(find.text('RESUME'));
    await tester.tap(find.text('RESTART'));

    expect(controller.pauseCommands, 2);
    expect(controller.restartCommands, 1);
  });

  testWidgets('results use the command boundary with immutable display state', (
    tester,
  ) async {
    final controller = _FakeRaceUiController();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RaceResultsOverlay(controller: controller),
      ),
    );

    expect(find.text('YOU'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('restart-race-button')));

    expect(controller.restartCommands, 1);
  });
}

final class _FakeRaceUiController implements RaceUiController {
  final ValueNotifier<int> _presentationFrame = ValueNotifier<int>(0);
  var pauseCommands = 0;
  var restartCommands = 0;

  @override
  ValueListenable<int> get presentationFrame => _presentationFrame;

  @override
  RaceUiState get uiState => RaceUiState(
    phase: RacePhase.finished,
    countdownRemainingSeconds: 0,
    position: 1,
    competitorCount: 2,
    displayedLap: 3,
    requiredLaps: 3,
    totalRaceTime: 12.345,
    bestLapTime: 4.123,
    playerResult: const RaceStanding(
      participantId: 'player',
      finishPosition: 1,
      competitorCount: 2,
      totalRaceTime: 12.345,
    ),
    standings: const <RaceStanding>[
      RaceStanding(
        participantId: 'player',
        finishPosition: 1,
        competitorCount: 2,
        totalRaceTime: 12.345,
      ),
      RaceStanding(
        participantId: 'ai-0',
        finishPosition: 2,
        competitorCount: 2,
        totalRaceTime: 13.456,
      ),
    ],
  );

  @override
  void restartRace() {
    restartCommands++;
  }

  @override
  void togglePause() {
    pauseCommands++;
  }
}
