import 'package:flame/game.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:toy_racers/game/race_results_overlay.dart';
import 'package:toy_racers/game/toy_racers_game.dart';
import 'package:toy_racers/main.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  testWidgets('captures menu, selection, and race presentation states', (
    tester,
  ) async {
    final game = await ToyRacersGame.loadDefault();
    await _pumpApplication(tester, game);

    expect(find.text('TOY RACERS'), findsOneWidget);
    await _capture(tester, 'main_menu');
    _expectInLeftHalf(
      tester,
      find.byKey(const ValueKey<String>('main-menu-play')),
    );

    await tester.tap(find.byKey(const ValueKey<String>('main-menu-play')));
    await tester.pumpAndSettle();
    expect(find.text('SELECT CAR'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('car-red-stripe')),
      findsOneWidget,
    );
    await _capture(tester, 'car_selection');

    await tester.tap(find.byKey(const ValueKey<String>('continue-to-track')));
    await tester.pumpAndSettle();
    expect(find.text('SELECT TRACK'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    await _capture(tester, 'track_selection');

    await tester.tap(find.byKey(const ValueKey<String>('track-track-01')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(GameWidget<ToyRacersGame>), findsOneWidget);
    await game.toBeLoaded();
    await tester.pump();
    expect(game.session.raceState.phase, RacePhase.countdown);
    expect(find.text('POSITION'), findsOneWidget);
    await _capture(tester, 'race_start');

    game.session.advanceLifecycle(
      elapsedSeconds: game.session.raceState.countdownDurationSeconds,
    );
    game.update(CarPhysics.fixedDeltaSeconds);
    await tester.pump();
    expect(game.session.raceState.phase, RacePhase.racing);
    expect(find.text('TIME  00:00.016'), findsOneWidget);
    await _capture(tester, 'active_race');

    game.togglePause();
    await tester.pump();
    expect(game.session.raceState.phase, RacePhase.paused);
    expect(find.text('PAUSED'), findsOneWidget);
    await _capture(tester, 'pause');
    await tester.pumpWidget(const SizedBox.shrink());
    game.dispose();
  });

  testWidgets('captures results with gameplay-relevant standings', (
    tester,
  ) async {
    final game = ToyRacersGame(session: _finishedSession());
    await tester.pumpWidget(
      _ScreenshotBoundary(child: RaceResultsOverlay(controller: game)),
    );

    expect(find.text('RACE RESULTS'), findsOneWidget);
    expect(find.textContaining('POSITION 1 / 1'), findsOneWidget);
    expect(find.text('RESTART RACE'), findsOneWidget);
    await _capture(tester, 'results');
    await tester.pumpWidget(const SizedBox.shrink());
    game.dispose();
  });

  testWidgets('results actions remain reachable on a short viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(568, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var mainMenuCount = 0;
    final game = ToyRacersGame(session: _finishedSession(participantCount: 6));

    await tester.pumpWidget(
      _ScreenshotBoundary(
        child: RaceResultsOverlay(
          controller: game,
          onMainMenu: () => mainMenuCount++,
        ),
      ),
    );

    final mainMenu = find.byKey(const ValueKey<String>('results-main-menu'));
    await tester.ensureVisible(mainMenu);
    await tester.tap(mainMenu);

    expect(mainMenuCount, 1);
    expect(tester.getRect(mainMenu).bottom, lessThanOrEqualTo(320));
    await tester.pumpWidget(const SizedBox.shrink());
    game.dispose();
  });
}

Future<void> _pumpApplication(WidgetTester tester, ToyRacersGame game) =>
    tester.pumpWidget(
      _ScreenshotBoundary(
        child: ToyRacersApplication(
          showTouchControls: false,
          raceGameLoader: ({required trackId, required playerCarModel}) =>
              Future<ToyRacersGame>.value(game),
        ),
      ),
    );

void _expectInLeftHalf(WidgetTester tester, Finder finder) {
  expect(tester.getCenter(finder).dx, lessThan(400));
}

Future<void> _capture(WidgetTester tester, String scene) async {
  expect(scene, isNotEmpty);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_ScreenshotBoundary.boundaryKey),
  );
  final image = await boundary.toImage(pixelRatio: 1);
  expect(image.width, 800);
  expect(image.height, 600);
  image.dispose();
}

RaceSession _finishedSession({int participantCount = 1}) {
  final track = Track.fromDefinition(
    id: 'results-visual-track',
    name: 'Results visual track',
    worldBounds: TrackRectangle(0, 0, 100, 100),
    cameraBounds: TrackRectangle(0, 0, 100, 100),
    outerBoundary: TrackRectangle(0, 0, 100, 100),
    backgroundSurface: SurfaceType.asphalt,
    startLine: StartLine(
      bounds: TrackRectangle(45, 45, 2, 8),
      forwardX: 1,
      forwardY: 0,
    ),
    checkpoints: <Checkpoint>[
      Checkpoint(
        order: 0,
        gate: TrackSegment(TrackPoint(90, 20), TrackPoint(90, 80)),
        forwardX: 1,
        forwardY: 0,
      ),
    ],
    startGrid: <StartGridPosition>[
      for (var index = 0; index < participantCount; index++)
        StartGridPosition(
          position: TrackPoint(50 - index * 3, 50),
          rotationDegrees: 0,
        ),
    ],
    racingLine: <TrackPoint>[
      TrackPoint(10, 10),
      TrackPoint(90, 10),
      TrackPoint(90, 90),
    ],
  );
  final session = RaceSession(
    track: track,
    participants: <RaceParticipant>[
      for (var index = 0; index < participantCount; index++)
        RaceParticipant(
          id: index == 0 ? 'player' : 'ai-${index - 1}',
          carState: CarState(x: 50 - index * 3, y: 50),
          carConfig: CarConfig(),
        ),
    ],
  );
  for (var index = 0; index < participantCount; index++) {
    session.participants[index].progress
      ..finished = true
      ..finishPosition = index + 1
      ..totalRaceTime = 12.34 + index;
  }
  session.synchronizeFinishOrdering();
  return session;
}

final class _ScreenshotBoundary extends StatelessWidget {
  const _ScreenshotBoundary({required this.child});

  static const Key boundaryKey = ValueKey<String>('visual-screenshot-boundary');

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(key: boundaryKey, child: child);
}
