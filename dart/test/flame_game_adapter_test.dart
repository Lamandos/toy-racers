import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:toy_racers/game/components/car_component.dart';
import 'package:toy_racers/game/components/race_objects_component.dart';
import 'package:toy_racers/game/components/track_component.dart';
import 'package:toy_racers/game/input/keyboard_input_controller.dart';
import 'package:toy_racers/game/rendering/car_visual_state.dart';
import 'package:toy_racers/game/rendering/race_world_projection.dart';
import 'package:toy_racers/game/toy_racers_game.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  test('keyboard controller maps desktop driving keys', () {
    final controller = KeyboardInputController();
    final inputResult = controller.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyW,
        logicalKey: LogicalKeyboardKey.keyW,
        timeStamp: Duration.zero,
      ),
      <LogicalKeyboardKey>{
        LogicalKeyboardKey.keyW,
        LogicalKeyboardKey.keyA,
      },
    );

    expect(inputResult, KeyEventResult.handled);
    expect(
      controller.input,
      PlayerInput(throttle: 1, steering: -1),
    );

    controller.handleKeyEvent(
      const KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: LogicalKeyboardKey.keyA,
        timeStamp: Duration.zero,
      ),
      <LogicalKeyboardKey>{LogicalKeyboardKey.keyW},
    );
    expect(controller.input, PlayerInput(throttle: 1));
  });

  test(
    'game applies keyboard input when no external provider is supplied',
    () async {
      final session = _session();
      final game = ToyRacersGame(session: session);

      await game.onLoad();
      game.onKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.arrowUp,
          logicalKey: LogicalKeyboardKey.arrowUp,
          timeStamp: Duration.zero,
        ),
        <LogicalKeyboardKey>{LogicalKeyboardKey.arrowUp},
      );
      for (var frame = 0; frame < 12; frame++) {
        game.update(CarPhysics.maxFrameDeltaSeconds);
      }
      game.update(CarPhysics.fixedDeltaSeconds);

      expect(session.player.carState.x, greaterThan(50));
    },
  );

  test(
    'Flame game delegates fixed ticks to the supplied race session',
    () async {
      final session = _session();
      final game = ToyRacersGame(
        session: session,
        playerInputProvider: () => PlayerInput(throttle: 1),
      );

      await game.onLoad();
      expect(session.raceState.phase, RacePhase.countdown);

      for (var frame = 0; frame < 12; frame++) {
        game.update(CarPhysics.maxFrameDeltaSeconds);
      }
      game.update(CarPhysics.fixedDeltaSeconds);

      expect(session.snapshot.simulationTick, 1);
      expect(session.player.carState.x, greaterThan(50));
      expect(game.world.cars.keys, <String>['player']);
      expect(game.world.children.whereType<TrackComponent>(), hasLength(1));
      expect(
        game.world.children.whereType<RaceObjectsComponent>(),
        hasLength(1),
      );
      expect(game.world.children.whereType<CarComponent>(), hasLength(1));
    },
  );

  test(
    'car visual state interpolates simulation observations without mutation',
    () {
      final projection = RaceWorldProjection(TrackRectangle(0, 0, 100, 100));
      final previous = CarState(x: 10, y: 20, rotationDegrees: 350);
      final current = CarState(x: 14, y: 24, rotationDegrees: 10);

      final visual = CarVisualState.interpolate(
        previous: previous,
        current: current,
        interpolationFactor: 0.5,
        projection: projection,
      );

      expect(visual.position, Vector2(12, 78));
      expect(visual.angle, closeTo(0, 0.000001));
      expect(previous.rotationDegrees, 350);
      expect(current.rotationDegrees, 10);
    },
  );

  test(
    'camera follows the projected player position inside track bounds',
    () async {
      final session = _session(playerX: 10, playerY: 95);
      final game = ToyRacersGame(session: session);

      await game.onLoad();

      expect(game.camera.viewfinder.position.x, 27);
      expect(game.camera.viewfinder.position.y, 18);
    },
  );

  testWidgets('loads the bundled default session into a Flame GameWidget', (
    tester,
  ) async {
    final game = await ToyRacersGame.loadDefault();

    await tester.pumpWidget(GameWidget(game: game));
    await tester.pump();

    expect(game.session.participants, hasLength(6));
    expect(game.world.cars, hasLength(6));
    expect(game.session.raceState.phase, RacePhase.countdown);
  });
}

RaceSession _session({double playerX = 50, double playerY = 50}) {
  final track = Track.fromDefinition(
    id: 'adapter-test-track',
    name: 'Adapter test track',
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
      StartGridPosition(
        position: TrackPoint(playerX, playerY),
        rotationDegrees: 0,
      ),
    ],
    racingLine: <TrackPoint>[
      TrackPoint(10, 10),
      TrackPoint(90, 10),
      TrackPoint(90, 90),
    ],
  );
  return RaceSession(
    track: track,
    participants: <RaceParticipant>[
      RaceParticipant(
        id: 'player',
        carState: CarState(x: playerX, y: playerY),
        carConfig: CarConfig(),
      ),
    ],
  );
}
