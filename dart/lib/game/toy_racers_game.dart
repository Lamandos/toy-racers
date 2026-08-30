import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:toy_racers/simulation.dart';

import 'camera/race_camera_controller.dart';
import 'input/keyboard_input_controller.dart';
import 'input/touch_input_controller.dart';
import 'race_world.dart';
import 'rendering/race_visual_interpolator.dart';

/// Supplies the latest normalized player command to the simulation adapter.
typedef PlayerInputProvider = PlayerInput Function();

/// Flame adapter around a deterministic [RaceSession].
///
/// The game delegates all vehicle physics, collision handling, AI, race
/// progression, and fixed-step scheduling to [RaceSession]. It only chooses a
/// bounded render-frame delta, reads the resulting state, and updates visual
/// components and camera framing.
final class ToyRacersGame extends FlameGame<RaceWorld> with KeyboardEvents {
  ToyRacersGame({
    required this.session,
    PlayerInputProvider? playerInputProvider,
    RaceCameraController? cameraController,
  }) : _playerInputProvider = playerInputProvider ?? _neutralInput,
       _cameraController = cameraController ?? RaceCameraController(),
       super(
         world: RaceWorld(session: session),
         camera: CameraComponent.withFixedResolution(width: 1280, height: 720),
       );

  final RaceSession session;
  final PlayerInputProvider _playerInputProvider;
  late final KeyboardInputController _keyboardInputController =
      KeyboardInputController(onAction: _handleKeyboardAction);
  final TouchInputController touchInputController = TouchInputController();
  final RaceCameraController _cameraController;
  final RaceVisualInterpolator _visualInterpolator = RaceVisualInterpolator();

  double interpolationFactor = 0;

  /// Creates the first playable session from bundled canonical TMX sources.
  static Future<ToyRacersGame> loadDefault({
    Future<String> Function(String assetPath)? assetTextLoader,
  }) async {
    final loadText = assetTextLoader ?? rootBundle.loadString;
    final trackId = TrackId.livingRoom;
    final assetPath = TrackLoader.tmxPath(trackId);
    final assetText = await loadText(assetPath);
    final track = TrackLoader((requestedPath) {
      if (requestedPath != assetPath) {
        throw StateError('Unexpected default track asset: $requestedPath');
      }
      return assetText;
    }).load(trackId);
    return ToyRacersGame(session: _defaultSession(track));
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    if (session.raceState.phase == RacePhase.loading) {
      session.start();
    }
    world.synchronizeVisualState(interpolationFactor);
    _followPlayerCamera();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _cameraController.configure(camera);
    _followPlayerCamera();
  }

  @override
  void pauseEngine() {
    touchInputController.clear();
    super.pauseEngine();
  }

  @override
  void onDetach() {
    touchInputController.clear();
    super.onDetach();
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) => _keyboardInputController.handleKeyEvent(event, keysPressed);

  void _handleKeyboardAction(KeyboardAction action) {
    switch (action) {
      case KeyboardAction.togglePause:
        _togglePause();
      case KeyboardAction.restart:
        session.restart();
        touchInputController.clear();
        interpolationFactor = 0;
        world.synchronizeVisualState(interpolationFactor);
        _followPlayerCamera();
    }
  }

  void _togglePause() {
    switch (session.raceState.phase) {
      case RacePhase.racing:
        session.pause();
        touchInputController.clear();
      case RacePhase.paused:
        session.resume();
      case RacePhase.loading ||
          RacePhase.ready ||
          RacePhase.countdown ||
          RacePhase.finished:
        return;
    }
  }

  @override
  void update(double dt) {
    final frameDelta = math.min(dt, CarPhysics.maxFrameDeltaSeconds);
    final phaseBeforeAdvance = session.raceState.phase;
    final countdownRemainingSeconds =
        session.raceState.countdownRemainingSeconds;
    final playerInput = _playerInputProvider()
        .combinedWith(_keyboardInputController.input)
        .combinedWith(touchInputController.input);
    final step = session.advance(
      frameDeltaSeconds: frameDelta,
      playerInput: playerInput,
    );
    interpolationFactor = _visualInterpolator.advance(
      frameDeltaSeconds: frameDelta,
      phaseBeforeAdvance: phaseBeforeAdvance,
      phaseAfterAdvance: session.raceState.phase,
      countdownRemainingSeconds: countdownRemainingSeconds,
      physicalSteps: step.physicalSteps,
    );
    world.synchronizeVisualState(interpolationFactor);
    _followPlayerCamera();
    super.update(dt);
  }

  void _followPlayerCamera() => _cameraController.follow(
    camera: camera,
    visualPosition: world.playerCar.visualState.position,
    worldBounds: world.projection.rectangleFor(session.track.cameraBounds),
  );

  static PlayerInput _neutralInput() => PlayerInput.none;

  static RaceSession _defaultSession(Track track) {
    final playerModel = CarModel.redStripe;
    final opponentModels = <CarModel>[
      CarModel.blueStripe,
      CarModel.yellowSport,
      CarModel.greenRacer,
      CarModel.orangeTruck,
      CarModel.blueStripe,
    ];
    return RaceSession(
      track: track,
      participants: <RaceParticipant>[
        RaceParticipant(
          id: 'player',
          carState: _stateAt(track.startGrid.first),
          carConfig: playerModel.performance.applyTo(),
        ),
        for (var index = 0; index < opponentModels.length; index++)
          RaceParticipant(
            id: 'ai-$index',
            carState: _stateAt(track.startGrid[index + 1]),
            carConfig: opponentModels[index].performance.applyTo(),
            aiDriver: ReferenceAiDriver(
              racingLine: track.racingLine,
              initialPosition: track.startGrid[index + 1].position,
              config: AiConfig(waypointRadius: track.racingLineWaypointRadius),
              racingLineBias: _racingLineBiases[index],
              track: track,
            ),
          ),
      ],
    );
  }

  static CarState _stateAt(StartGridPosition start) => CarState(
    x: start.position.x,
    y: start.position.y,
    rotationDegrees: start.rotationDegrees,
  );

  static const List<double> _racingLineBiases = <double>[
    -0.36,
    0.27,
    -0.16,
    0.39,
    -0.28,
  ];
}
