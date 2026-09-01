import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:toy_racers/simulation.dart';

import 'camera/race_camera_controller.dart';
import 'fixed_timestep_scheduler.dart';
import 'input/keyboard_input_controller.dart';
import 'input/player_input_adapter.dart';
import 'input/touch_input_controller.dart';
import 'rendering/race_car_models.dart';
import 'race_world.dart';
import 'ui/race_ui_controller.dart';

/// Supplies the latest normalized player command to the simulation adapter.
typedef PlayerInputProvider = PlayerInput Function();

/// Flame adapter around a deterministic [RaceSession].
///
/// The game delegates all vehicle physics, collision handling, AI, race
/// progression to [RaceSession]. It schedules reference-rate ticks from
/// Flame's render deltas, then updates visual components and camera framing.
final class ToyRacersGame extends FlameGame<RaceWorld>
    with KeyboardEvents
    implements RaceUiController {
  static const String touchControlsOverlayId = 'touch-controls';
  static const String raceHudOverlayId = 'race-hud';
  static const String countdownOverlayId = 'race-countdown';
  static const String pauseOverlayId = 'race-pause';
  static const String resultsOverlayId = 'race-results';

  ToyRacersGame({
    required this.session,
    CarModel playerCarModel = CarModel.redStripe,
    List<CarModel>? opponentCarModels,
    PlayerInputProvider? playerInputProvider,
    RaceCameraController? cameraController,
  }) : playerCarModel = playerCarModel,
       opponentCarModels = List<CarModel>.unmodifiable(
         opponentCarModels ?? RaceCarModels.opponentsFor(playerCarModel),
       ),
       _playerInputProvider = playerInputProvider ?? _neutralInput,
       _cameraController = cameraController ?? RaceCameraController(),
       super(
         world: RaceWorld(
           session: session,
           carModels: RaceCarModels.forSession(
             session: session,
             playerCarModel: playerCarModel,
             opponentCarModels:
                 opponentCarModels ??
                 RaceCarModels.opponentsFor(playerCarModel),
           ),
         ),
         camera: CameraComponent.withFixedResolution(width: 1280, height: 720),
       );

  final RaceSession session;
  final CarModel playerCarModel;
  final List<CarModel> opponentCarModels;
  final PlayerInputProvider _playerInputProvider;
  late final DesktopKeyboardInputAdapter _keyboardInputAdapter =
      DesktopKeyboardInputAdapter(onAction: _handleKeyboardAction);
  final MobileTouchInputAdapter touchInputController =
      MobileTouchInputAdapter();
  late final PlayerInputAdapter _playerInputAdapter =
      CombinedPlayerInputAdapter(<PlayerInputAdapter>[
        CallbackPlayerInputAdapter(_playerInputProvider),
        _keyboardInputAdapter,
        touchInputController,
      ]);
  final RaceCameraController _cameraController;
  final FixedTimestepScheduler _fixedTimestep = FixedTimestepScheduler();
  @override
  final ValueNotifier<int> presentationFrame = ValueNotifier<int>(0);

  double interpolationFactor = 0;

  @override
  RaceUiState get uiState => RaceUiState.fromSession(session);

  /// Creates the first playable session from bundled canonical TMX sources.
  static Future<ToyRacersGame> loadDefault({
    Future<String> Function(String assetPath)? assetTextLoader,
  }) => loadRace(
    trackId: TrackId.livingRoom,
    playerCarModel: CarModel.redStripe,
    assetTextLoader: assetTextLoader,
  );

  /// Creates one playable race with sprite choices kept out of simulation.
  static Future<ToyRacersGame> loadRace({
    required TrackId trackId,
    required CarModel playerCarModel,
    Future<String> Function(String assetPath)? assetTextLoader,
  }) async {
    final loadText = assetTextLoader ?? rootBundle.loadString;
    final assetPath = TrackLoader.tmxPath(trackId);
    final assetText = await loadText(assetPath);
    final track = TrackLoader((requestedPath) {
      if (requestedPath != assetPath) {
        throw StateError('Unexpected default track asset: $requestedPath');
      }
      return assetText;
    }).load(trackId);
    final opponents = RaceCarModels.opponentsFor(playerCarModel);
    return ToyRacersGame(
      session: _defaultSession(
        track: track,
        playerCarModel: playerCarModel,
        opponentModels: opponents,
      ),
      playerCarModel: playerCarModel,
      opponentCarModels: opponents,
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    if (session.raceState.phase == RacePhase.loading) {
      session.start();
    }
    _synchronizePresentationOverlays();
    world.synchronizeVisualState(interpolationFactor);
    _followPlayerCamera(0);
    _publishPresentationFrame();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _cameraController.configure(camera);
    _followPlayerCamera(0);
  }

  @override
  void pauseEngine() {
    touchInputController.clear();
    _fixedTimestep.reset();
    super.pauseEngine();
  }

  @override
  void onDetach() {
    touchInputController.clear();
    _fixedTimestep.reset();
    super.onDetach();
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) => _keyboardInputAdapter.handleKeyEvent(event, keysPressed);

  void _handleKeyboardAction(KeyboardAction action) {
    switch (action) {
      case KeyboardAction.togglePause:
        togglePause();
      case KeyboardAction.restart:
        restartRace();
    }
  }

  /// Toggles the simulation pause state for keyboard and touch controls.
  @override
  void togglePause() {
    switch (session.raceState.phase) {
      case RacePhase.racing:
        session.pause();
        touchInputController.clear();
        _fixedTimestep.reset();
        _synchronizePresentationOverlays();
        _publishPresentationFrame();
      case RacePhase.paused:
        session.resume();
        _synchronizePresentationOverlays();
        _publishPresentationFrame();
      case RacePhase.loading ||
          RacePhase.ready ||
          RacePhase.countdown ||
          RacePhase.finished:
        return;
    }
  }

  /// Restarts the simulation and clears all presentation state from the prior
  /// race.
  @override
  void restartRace() {
    session.restart();
    touchInputController.clear();
    _fixedTimestep.reset();
    interpolationFactor = 0;
    _synchronizePresentationOverlays();
    if (_touchControlsEnabled &&
        overlays.registeredOverlays.contains(touchControlsOverlayId)) {
      overlays.add(touchControlsOverlayId);
    }
    world.synchronizeVisualState(interpolationFactor);
    _resetPlayerCamera();
    _publishPresentationFrame();
  }

  /// Enables or disables the touch overlay for the current platform.
  void configureTouchControls(bool enabled) {
    _touchControlsEnabled = enabled;
    if (!overlays.registeredOverlays.contains(touchControlsOverlayId)) {
      return;
    }
    overlays.setActive(
      touchControlsOverlayId,
      active: enabled && _isTouchControlsVisible(),
    );
  }

  @override
  void update(double dt) {
    final frameDelta = FixedTimestepScheduler.boundedRenderDelta(dt);
    final racingDelta = session.advanceLifecycle(elapsedSeconds: frameDelta);
    var maximumImpactSpeed = 0.0;
    final frame = _fixedTimestep.advance(
      simulationDeltaSeconds: racingDelta,
      isSimulationActive: _isRacing,
      onFixedStep: () {
        final impactSpeed = _advanceSimulation();
        if (impactSpeed > maximumImpactSpeed) {
          maximumImpactSpeed = impactSpeed;
        }
      },
    );
    if (maximumImpactSpeed >= _minimumShakeImpactSpeed) {
      _cameraController.addShake(maximumImpactSpeed * _shakePerImpactSpeed);
    }
    _synchronizePresentationOverlays();
    interpolationFactor = frame.interpolationFactor;
    world.synchronizeVisualState(interpolationFactor);
    _followPlayerCamera(frameDelta);
    super.update(dt);
    _publishPresentationFrame();
  }

  bool _isRacing() => session.raceState.phase == RacePhase.racing;

  bool _isTouchControlsVisible() => switch (session.raceState.phase) {
    RacePhase.countdown || RacePhase.racing => true,
    RacePhase.loading ||
    RacePhase.ready ||
    RacePhase.paused ||
    RacePhase.finished => false,
  };

  double _advanceSimulation() {
    final step = session.advanceFixedStep(
      playerInput: _playerInputAdapter.readInput(),
    );
    return step.maxImpactSpeed;
  }

  void _followPlayerCamera(double deltaSeconds) => _cameraController.follow(
    camera: camera,
    visualPosition: world.playerCar.visualState.position,
    visualVelocity: world.playerCar.visualState.velocity,
    worldBounds: world.projection.rectangleFor(session.track.cameraBounds),
    deltaSeconds: deltaSeconds,
  );

  void _resetPlayerCamera() => _cameraController.reset(
    camera: camera,
    visualPosition: world.playerCar.visualState.position,
    visualVelocity: world.playerCar.visualState.velocity,
    worldBounds: world.projection.rectangleFor(session.track.cameraBounds),
  );

  static PlayerInput _neutralInput() => PlayerInput.none;

  bool _touchControlsEnabled = false;

  void _synchronizePresentationOverlays() {
    final registeredOverlays = overlays.registeredOverlays;
    _setOverlayActive(
      registeredOverlays,
      countdownOverlayId,
      session.raceState.phase == RacePhase.countdown,
    );
    _setOverlayActive(
      registeredOverlays,
      pauseOverlayId,
      session.raceState.phase == RacePhase.paused,
    );
    _setOverlayActive(
      registeredOverlays,
      resultsOverlayId,
      session.raceState.phase == RacePhase.finished,
    );
    _setOverlayActive(
      registeredOverlays,
      touchControlsOverlayId,
      _touchControlsEnabled && _isTouchControlsVisible(),
    );
  }

  void _setOverlayActive(
    Iterable<String> registeredOverlays,
    String id,
    bool active,
  ) {
    if (registeredOverlays.contains(id)) {
      overlays.setActive(id, active: active);
    }
  }

  void _publishPresentationFrame() => presentationFrame.value++;

  static RaceSession _defaultSession({
    required Track track,
    required CarModel playerCarModel,
    required List<CarModel> opponentModels,
  }) {
    return RaceSession(
      track: track,
      participants: <RaceParticipant>[
        RaceParticipant(
          id: 'player',
          carState: _stateAt(track.startGrid.first),
          carConfig: playerCarModel.performance.applyTo(),
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
  static const double _minimumShakeImpactSpeed = 3;
  static const double _shakePerImpactSpeed = 0.025;
}
