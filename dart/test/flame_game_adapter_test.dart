import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:toy_racers/game/camera/race_camera_controller.dart';
import 'package:toy_racers/game/components/car_component.dart';
import 'package:toy_racers/game/components/race_objects_component.dart';
import 'package:toy_racers/game/components/track_component.dart';
import 'package:toy_racers/game/fixed_timestep_scheduler.dart';
import 'package:toy_racers/game/input/keyboard_input_controller.dart';
import 'package:toy_racers/game/input/touch_controls_overlay.dart';
import 'package:toy_racers/game/input/touch_input_controller.dart';
import 'package:toy_racers/game/rendering/car_visual_state.dart';
import 'package:toy_racers/game/rendering/race_world_projection.dart';
import 'package:toy_racers/game/race_results_overlay.dart';
import 'package:toy_racers/game/race_world.dart';
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
      <LogicalKeyboardKey>{LogicalKeyboardKey.keyW, LogicalKeyboardKey.keyA},
    );

    expect(inputResult, KeyEventResult.handled);
    expect(controller.input, PlayerInput(throttle: 1, steering: -1));

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

  test('keyboard controller handles documented race actions', () {
    final actions = <KeyboardAction>[];
    final controller = KeyboardInputController(onAction: actions.add);

    final escapeResult = controller.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.escape,
        logicalKey: LogicalKeyboardKey.escape,
        timeStamp: Duration.zero,
      ),
      <LogicalKeyboardKey>{LogicalKeyboardKey.escape},
    );
    final restartResult = controller.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyR,
        logicalKey: LogicalKeyboardKey.keyR,
        timeStamp: Duration.zero,
      ),
      <LogicalKeyboardKey>{LogicalKeyboardKey.keyR},
    );

    expect(escapeResult, KeyEventResult.handled);
    expect(restartResult, KeyEventResult.handled);
    expect(actions, <KeyboardAction>[
      KeyboardAction.togglePause,
      KeyboardAction.restart,
    ]);
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

  test('touch controller supports simultaneous steering and throttle', () {
    final controller = TouchInputController()..configure(const Size(400, 200));

    controller.pointerDown(1, const Offset(50, 150));
    controller.pointerDown(2, const Offset(350, 150));

    expect(controller.input, PlayerInput(throttle: 1, steering: -1));

    controller.pointerUp(1);
    expect(controller.input, PlayerInput(throttle: 1));
    controller.clear();
    expect(controller.input, PlayerInput.none);
  });

  testWidgets('touch overlay invokes pause and restart actions', (
    tester,
  ) async {
    var pauseCount = 0;
    var restartCount = 0;
    final controller = TouchInputController();

    await tester.pumpWidget(
      SizedBox(
        width: 400,
        height: 200,
        child: TouchControlsOverlay(
          controller: controller,
          onPause: () => pauseCount++,
          onRestart: () => restartCount++,
        ),
      ),
    );

    final overlay = find.byType(TouchControlsOverlay);
    final origin = tester.getTopLeft(overlay);
    final size = tester.getSize(overlay);
    final restartLeft = size.width - 16 - 104;
    await tester.tapAt(origin + Offset(restartLeft - 8 - 52, 40));
    await tester.tapAt(origin + Offset(restartLeft + 52, 40));

    expect(pauseCount, 1);
    expect(restartCount, 1);
    expect(controller.input, PlayerInput.none);
    controller.dispose();
  });

  test('game applies the default touch controller input', () async {
    final session = _session();
    final game = ToyRacersGame(session: session);
    game.touchInputController.configure(const Size(400, 200));
    game.touchInputController.pointerDown(1, const Offset(350, 150));

    await game.onLoad();
    for (var frame = 0; frame < 12; frame++) {
      game.update(CarPhysics.maxFrameDeltaSeconds);
    }
    game.update(CarPhysics.fixedDeltaSeconds);

    expect(session.player.carState.x, greaterThan(50));
  });

  test('game handles pause, resume, and restart keyboard actions', () async {
    final session = _session();
    final game = ToyRacersGame(session: session);

    await game.onLoad();
    for (var frame = 0; frame < 70; frame++) {
      game.update(CarPhysics.maxFrameDeltaSeconds);
    }
    expect(session.raceState.phase, RacePhase.racing);

    game.onKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.escape,
        logicalKey: LogicalKeyboardKey.escape,
        timeStamp: Duration.zero,
      ),
      <LogicalKeyboardKey>{LogicalKeyboardKey.escape},
    );
    expect(session.raceState.phase, RacePhase.paused);

    game.onKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.escape,
        logicalKey: LogicalKeyboardKey.escape,
        timeStamp: Duration.zero,
      ),
      <LogicalKeyboardKey>{LogicalKeyboardKey.escape},
    );
    expect(session.raceState.phase, RacePhase.racing);

    game.update(CarPhysics.fixedDeltaSeconds);
    session.player.carState.x = 80;
    session.player.progress
      ..completedLaps = 2
      ..totalRaceTime = 12;

    game.onKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyR,
        logicalKey: LogicalKeyboardKey.keyR,
        timeStamp: Duration.zero,
      ),
      <LogicalKeyboardKey>{LogicalKeyboardKey.keyR},
    );

    expect(session.raceState.phase, RacePhase.countdown);
    expect(session.snapshot.simulationTick, 0);
    expect(session.player.carState.x, 50);
    expect(session.player.progress.completedLaps, 0);
    expect(session.player.progress.totalRaceTime, 0);
  });

  test('fixed timestep scheduler reports render interpolation remainder', () {
    final scheduler = FixedTimestepScheduler();
    var simulatedSteps = 0;

    final frame = scheduler.advance(
      simulationDeltaSeconds: CarPhysics.fixedDeltaSeconds / 2,
      isSimulationActive: () => true,
      onFixedStep: () => simulatedSteps++,
    );

    expect(frame.physicalSteps, 0);
    expect(simulatedSteps, 0);
    expect(frame.interpolationFactor, closeTo(0.5, 0.000001));

    scheduler.reset();
    final resetFrame = scheduler.advance(
      simulationDeltaSeconds: 0,
      isSimulationActive: () => true,
      onFixedStep: () => simulatedSteps++,
    );
    expect(resetFrame.interpolationFactor, 0);
  });

  test(
    'identical tick inputs reach the same state at 30, 60, and 120 FPS',
    () async {
      final at30Fps = await _runRenderPattern(List<double>.filled(45, 1 / 30));
      final at60Fps = await _runRenderPattern(List<double>.filled(90, 1 / 60));
      final at120Fps = await _runRenderPattern(
        List<double>.filled(180, 1 / 120),
      );

      expect(at30Fps, at60Fps);
      expect(at120Fps, at60Fps);
      expect(at60Fps.simulationTick, 90);
    },
  );

  test('a bounded frame spike preserves fixed tick input order', () async {
    final regularFrames = await _runRenderPattern(
      List<double>.filled(15, CarPhysics.fixedDeltaSeconds),
    );
    final frameSpike = await _runRenderPattern(<double>[1]);

    expect(frameSpike, regularFrames);
    expect(frameSpike.simulationTick, 15);
  });

  test('pause drops accumulated render time before resuming', () async {
    final session = _racingSession();
    final game = ToyRacersGame(
      session: session,
      playerInputProvider: () => PlayerInput(throttle: 1),
    );
    await game.onLoad();

    game.update(CarPhysics.fixedDeltaSeconds / 2);
    game.togglePause();
    game.update(10);
    expect(session.snapshot.simulationTick, 0);

    game.togglePause();
    game.update(CarPhysics.fixedDeltaSeconds);

    expect(session.snapshot.simulationTick, 1);
    expect(game.interpolationFactor, 0);
  });

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
      expect(visual.velocity, Vector2(0, 0));
      expect(visual.angle, closeTo(0, 0.000001));
      expect(previous.rotationDegrees, 350);
      expect(current.rotationDegrees, 10);
    },
  );

  test('legacy car visual state construction defaults velocity to zero', () {
    final visual = CarVisualState(position: Vector2.zero(), angle: 0);

    expect(visual.velocity, Vector2.zero());
  });

  test('camera keeps the legacy follow arguments usable', () {
    final camera = CameraComponent.withFixedResolution(
      width: 1280,
      height: 720,
    );

    RaceCameraController().follow(
      camera: camera,
      visualPosition: Vector2(50, 50),
      worldBounds: const Rect.fromLTWH(0, 0, 100, 100),
    );

    expect(camera.viewfinder.position, Vector2(50, 50));
  });

  test('world maps car sprites and keeps the player above opponents', () {
    final session = _session(participantCount: 3);
    final game = ToyRacersGame(
      session: session,
      playerCarModel: CarModel.yellowSport,
      opponentCarModels: <CarModel>[CarModel.greenRacer, CarModel.blueStripe],
    );
    final player = game.world.cars['player']!;
    final firstOpponent = game.world.cars['ai-0']!;

    expect(player.carModel, CarModel.yellowSport);
    expect(firstOpponent.carModel, CarModel.greenRacer);
    expect(player.size, Vector2(3.4, 1.8));
    expect(player.priority, greaterThan(firstOpponent.priority));
    expect(game.world.children.last, same(player));
  });

  test('world uses the session player identity for layering', () {
    final session = _session(participantCount: 3, playerId: 'human');
    final world = RaceWorld(session: session);

    expect(world.playerCar.participantId, 'human');
    expect(world.playerCar.priority, greaterThan(world.cars['ai-0']!.priority));
  });

  test('world preserves the legacy constructor defaults', () {
    final world = RaceWorld(session: _session());
    final participant = _session().player;
    final component = CarComponent.fromParticipant(
      participant: participant,
      projection: RaceWorldProjection(TrackRectangle(0, 0, 100, 100)),
    );

    expect(world.playerCar.carModel, CarModel.redStripe);
    expect(world.children.whereType<RaceObjectsComponent>(), hasLength(1));
    expect(component.carModel, CarModel.redStripe);
  });

  test('camera rejects invalid tuning values', () {
    expect(() => RaceCameraController(followSpeed: 0), throwsArgumentError);
    expect(
      () => RaceCameraController(followSpeed: double.nan),
      throwsArgumentError,
    );
    expect(
      () => RaceCameraController(lookAheadDistance: -1),
      throwsArgumentError,
    );
    expect(
      () => RaceCameraController(lookAheadDistance: double.infinity),
      throwsArgumentError,
    );
    expect(() => RaceCameraController(shakeDecaySpeed: 0), throwsArgumentError);
    expect(
      () => RaceCameraController(shakeDecaySpeed: double.nan),
      throwsArgumentError,
    );
  });

  test('restart clears camera shake and snaps to the player', () async {
    final cameraController = RaceCameraController();
    final game = ToyRacersGame(
      session: _session(),
      cameraController: cameraController,
    );

    await game.onLoad();
    cameraController.addShake(1);
    game.update(0);
    expect(game.camera.viewfinder.position.y, closeTo(51, 0.000001));

    game.restartRace();

    expect(game.camera.viewfinder.position, Vector2(50, 50));
  });

  test('camera shake uses one strongest impact per render frame', () async {
    final session = _session(collisionSystem: _FixedImpactCollisionSystem(10));
    final game = ToyRacersGame(
      session: session,
      cameraController: RaceCameraController(lookAheadDistance: 0),
    );

    await game.onLoad();
    session.advanceLifecycle(
      elapsedSeconds: session.raceState.countdownDurationSeconds,
    );
    game.update(CarPhysics.maxFrameDeltaSeconds);

    expect((game.camera.viewfinder.position.y - 50).abs(), lessThan(0.02));
  });

  test(
    'camera follows the projected player position inside track bounds',
    () async {
      final session = _session(playerX: 10, playerY: 95);
      final game = ToyRacersGame(session: session);

      await game.onLoad();

      expect(game.camera.viewfinder.position.x, 12);
      expect(game.camera.viewfinder.position.y, 6.75);
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
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows race results and restarts from the results action', (
    tester,
  ) async {
    final session = _session(requiredLaps: 1);
    final game = ToyRacersGame(session: session);

    await tester.pumpWidget(
      GameWidget<ToyRacersGame>(
        game: game,
        overlayBuilderMap: <String, OverlayWidgetBuilder<ToyRacersGame>>{
          ToyRacersGame.resultsOverlayId: (context, game) =>
              RaceResultsOverlay(game: game),
        },
      ),
    );
    await tester.pump();

    for (var frame = 0; frame < 14; frame++) {
      game.update(CarPhysics.maxFrameDeltaSeconds);
    }
    session.player.progress.currentCheckpointIndex = 1;
    session.player.carState
      ..x = 45.8
      ..y = 50
      ..longitudinalSpeed = 24
      ..velocityX = 24;
    game.update(CarPhysics.fixedDeltaSeconds);
    await tester.pump();

    expect(session.raceState.phase, RacePhase.finished);
    expect(find.text('RACE RESULTS'), findsOneWidget);
    expect(find.text('RESTART RACE'), findsOneWidget);

    await tester.tap(find.text('RESTART RACE'));
    await tester.pump();

    expect(session.raceState.phase, RacePhase.countdown);
    expect(find.text('RACE RESULTS'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

RaceSession _session({
  double playerX = 50,
  double playerY = 50,
  int requiredLaps = 3,
  int participantCount = 1,
  String playerId = 'player',
  CollisionSystem? collisionSystem,
}) {
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
      for (var index = 0; index < participantCount; index++)
        StartGridPosition(
          position: TrackPoint(playerX - index * 3, playerY),
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
      for (var index = 0; index < participantCount; index++)
        RaceParticipant(
          id: index == 0 ? playerId : 'ai-${index - 1}',
          carState: CarState(x: playerX - index * 3, y: playerY),
          carConfig: CarConfig(),
        ),
    ],
    requiredLaps: requiredLaps,
    collisionSystem: collisionSystem,
    playerId: playerId,
  );
}

final class _FixedImpactCollisionSystem implements CollisionSystem {
  _FixedImpactCollisionSystem(this.impactSpeed);

  final double impactSpeed;

  @override
  CollisionResult resolveTrackCollision({
    required CarState state,
    required CarConfig config,
    required Track track,
  }) => CollisionResult(maxImpactSpeed: impactSpeed);

  @override
  CollisionResult resolveCarCollision({
    required CarState firstState,
    required CarConfig firstConfig,
    required CarState secondState,
    required CarConfig secondConfig,
  }) => CollisionResult.none;
}

Future<_ObservedSimulationState> _runRenderPattern(
  List<double> renderDeltas,
) async {
  final session = _racingSession();
  final game = ToyRacersGame(
    session: session,
    playerInputProvider: () =>
        _inputForSimulationTick(session.snapshot.simulationTick),
  );
  await game.onLoad();
  for (final delta in renderDeltas) {
    game.update(delta);
  }
  final player = session.player;
  return (
    simulationTick: session.snapshot.simulationTick,
    phase: session.raceState.phase,
    raceTime: player.progress.totalRaceTime,
    x: player.carState.x,
    y: player.carState.y,
    rotationDegrees: player.carState.rotationDegrees,
    longitudinalSpeed: player.carState.longitudinalSpeed,
    velocityX: player.carState.velocityX,
    velocityY: player.carState.velocityY,
    angularVelocity: player.carState.angularVelocity,
    lateralSpeed: player.carState.lateralSpeed,
    driftAmount: player.carState.driftAmount,
  );
}

RaceSession _racingSession() {
  final session = _session();
  session.start();
  session.advance(
    frameDeltaSeconds: session.raceState.countdownDurationSeconds,
    playerInput: PlayerInput.none,
  );
  return session;
}

PlayerInput _inputForSimulationTick(int simulationTick) {
  final sequenceStep = simulationTick % 24;
  if (sequenceStep < 12) {
    return PlayerInput(throttle: 1);
  }
  if (sequenceStep < 18) {
    return PlayerInput(throttle: 1, steering: 0.6);
  }
  return PlayerInput(brake: 0.4, steering: -0.35);
}

typedef _ObservedSimulationState = ({
  int simulationTick,
  RacePhase phase,
  double raceTime,
  double x,
  double y,
  double rotationDegrees,
  double longitudinalSpeed,
  double velocityX,
  double velocityY,
  double angularVelocity,
  double lateralSpeed,
  double driftAmount,
});
