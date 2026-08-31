import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:toy_racers/game/race_results_overlay.dart';
import 'package:toy_racers/game/toy_racers_game.dart';
import 'package:toy_racers/game/ui/race_hud_overlay.dart';
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
    expect(find.text('SELECT TRACK'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    await _capture(tester, 'track_selection');

    await tester.tap(find.byKey(const ValueKey<String>('track-track-01')));
    await tester.pumpAndSettle();
    expect(find.text('SELECT CAR'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('car-red-stripe')),
      findsOneWidget,
    );
    await _capture(tester, 'car_selection');

    game.session.start();
    await tester.pumpWidget(
      _ScreenshotBoundary(child: _RaceVisualFrame(game: game)),
    );
    expect(game.session.raceState.phase, RacePhase.countdown);
    expect(find.text('POSITION'), findsOneWidget);
    await _capture(tester, 'race_start');

    game.session.advanceLifecycle(elapsedSeconds: 3);
    game.session.advanceFixedStep(playerInput: PlayerInput.none);
    game.presentationFrame.value++;
    await tester.pumpWidget(
      _ScreenshotBoundary(child: _RaceVisualFrame(game: game)),
    );
    expect(game.session.raceState.phase, RacePhase.racing);
    expect(find.text('TIME  00:00.016'), findsOneWidget);
    await _capture(tester, 'active_race');

    game.togglePause();
    await tester.pumpWidget(
      _ScreenshotBoundary(child: _RaceVisualFrame(game: game, paused: true)),
    );
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
      _ScreenshotBoundary(child: RaceResultsOverlay(game: game)),
    );

    expect(find.text('RACE RESULTS'), findsOneWidget);
    expect(find.textContaining('POSITION 1 / 1'), findsOneWidget);
    expect(find.text('RESTART RACE'), findsOneWidget);
    await _capture(tester, 'results');
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
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_ScreenshotBoundary.boundaryKey),
  );
  final image = await boundary.toImage(pixelRatio: 1);
  expect(image.width, 800);
  expect(image.height, 600);
  image.dispose();
}

RaceSession _finishedSession() {
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
      StartGridPosition(position: TrackPoint(50, 50), rotationDegrees: 0),
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
      RaceParticipant(
        id: 'player',
        carState: CarState(x: 50, y: 50),
        carConfig: CarConfig(),
      ),
    ],
  );
  session.player.progress
    ..finished = true
    ..finishPosition = 1
    ..totalRaceTime = 12.34;
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

final class _RaceVisualFrame extends StatelessWidget {
  const _RaceVisualFrame({required this.game, this.paused = false});

  final ToyRacersGame game;
  final bool paused;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.asset('assets/tracks/track_01.png', fit: BoxFit.cover),
        ...List<Widget>.generate(
          6,
          (index) => Positioned(
            left: 240 + index * 58,
            top: 325 + (index.isOdd ? 24 : 0),
            child: Transform.rotate(
              angle: 1.5708,
              child: Image.asset(_carAsset(index), width: 32, height: 64),
            ),
          ),
        ),
        RaceHudOverlay(game: game),
        const Positioned.fill(child: IgnorePointer(child: SizedBox.expand())),
        if (game.session.raceState.phase == RacePhase.countdown)
          RaceCountdownOverlay(game: game),
        if (paused) RacePauseOverlay(game: game, onQuitToMenu: () {}),
      ],
    ),
  );

  String _carAsset(int index) => <String>[
    'assets/sprites/cars/red-stripe.png',
    'assets/sprites/cars/blue-stripe.png',
    'assets/sprites/cars/yellow-sport.png',
    'assets/sprites/cars/green-racer.png',
    'assets/sprites/cars/orange-truck.png',
    'assets/sprites/cars/blue-stripe.png',
  ][index];
}
