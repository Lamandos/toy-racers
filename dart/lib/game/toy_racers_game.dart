import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:toy_racers/simulation.dart';

import '../audio/game_audio_controller.dart';
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
    GameAudioController? audio,
  }) : playerCarModel = playerCarModel,
       opponentCarModels = List<CarModel>.unmodifiable(
         opponentCarModels ?? RaceCarModels.opponentsFor(playerCarModel),
       ),
       _playerInputProvider = playerInputProvider ?? _neutralInput,
       _cameraController = cameraController ?? RaceCameraController(),
       _audio = audio ?? GameAudioController.silent(),
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
  GameAudioController _audio;
  final FixedTimestepScheduler _fixedTimestep = FixedTimestepScheduler();
  @override
  final ValueNotifier<int> presentationFrame = ValueNotifier<int>(0);

  double interpolationFactor = 0;
  PlayerInput _latestInput = PlayerInput.none;
  int _lastCountdownNumber = -1;
  bool _finishSoundPlayed = false;
  bool _resultsVisible = false;
  bool _hasLoaded = false;

  @override
  RaceUiState get uiState => RaceUiState.fromSession(session);

  /// The application binds its shared presentation audio before [onLoad].
  void attachAudio(GameAudioController audio) {
    if (_hasLoaded && !identical(_audio, audio)) {
      throw StateError('Audio must be attached before the Flame game loads.');
    }
    _audio = audio;
  }

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
    _hasLoaded = true;
    unawaited(_audio.startRaceLoops());
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
    unawaited(_audio.stopRaceLoops());
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
        unawaited(_audio.pauseRace());
        _synchronizePresentationOverlays();
        _publishPresentationFrame();
      case RacePhase.paused:
        session.resume();
        unawaited(_audio.resumeRace());
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
    _latestInput = PlayerInput.none;
    _lastCountdownNumber = -1;
    _finishSoundPlayed = false;
    _resultsVisible = false;
    unawaited(_audio.resetRaceMix());
    unawaited(_audio.resumeRace());
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

  /// Touch actions pass through the same browser-unlock and UI-sound path.
  void onTouchPause() {
    unawaited(_audio.activateFromUserGesture());
    unawaited(_audio.buttonClick());
    togglePause();
  }

  /// Restarts a touch race without bypassing the presentation audio layer.
  void onTouchRestart() {
    unawaited(_audio.activateFromUserGesture());
    unawaited(_audio.buttonClick());
    restartRace();
  }

  @override
  void update(double dt) {
    final frameDelta = FixedTimestepScheduler.boundedRenderDelta(dt);
    final phaseBeforeAdvance = session.raceState.phase;
    final racingDelta = session.advanceLifecycle(elapsedSeconds: frameDelta);
    _audio.advanceRaceFadeOut(frameDelta);
    _updateCountdownAudio(phaseBeforeAdvance);
    var maximumImpactSpeed = 0.0;
    var playerCheckpointPassed = false;
    final frame = _fixedTimestep.advance(
      simulationDeltaSeconds: racingDelta,
      isSimulationActive: _isRacing,
      onFixedStep: () {
        final step = _advanceSimulation();
        playerCheckpointPassed =
            playerCheckpointPassed || step.playerCheckpointPassed;
        if (step.maxImpactSpeed > maximumImpactSpeed) {
          maximumImpactSpeed = step.maxImpactSpeed;
        }
      },
    );
    if (playerCheckpointPassed) {
      unawaited(_audio.checkpoint());
    }
    if (maximumImpactSpeed >= _minimumShakeImpactSpeed) {
      _cameraController.addShake(maximumImpactSpeed * _shakePerImpactSpeed);
      unawaited(
        _audio.collision(
          maximumImpactSpeed / session.player.carConfig.maxForwardSpeed,
        ),
      );
    }
    _updateRaceAudio();
    _showResultsWhenFadeCompletes();
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

  RaceStepResult _advanceSimulation() {
    final step = session.advanceFixedStep(
      playerInput: _playerInputAdapter.readInput(),
    );
    final input = step.appliedPlayerInput;
    if (input != null) {
      _latestInput = input;
    }
    return step;
  }

  void _updateCountdownAudio(RacePhase phaseBeforeAdvance) {
    if (session.raceState.phase == RacePhase.countdown) {
      final countdownNumber = session.raceState.countdownRemainingSeconds
          .ceil()
          .clamp(0, 3);
      if (countdownNumber != _lastCountdownNumber) {
        _lastCountdownNumber = countdownNumber;
        if (countdownNumber == 3) {
          unawaited(_audio.countdown());
        }
      }
    } else if (phaseBeforeAdvance == RacePhase.countdown &&
        session.raceState.phase == RacePhase.racing) {
      unawaited(_audio.go());
    }
  }

  void _updateRaceAudio() {
    final state = session.player.carState;
    unawaited(
      _audio.updateRace(
        speed: state.longitudinalSpeed,
        maxSpeed: session.player.carConfig.maxForwardSpeed,
        input: _latestInput,
        driftAmount: state.driftAmount,
        racing: session.raceState.phase == RacePhase.racing,
        surface: session.track.surfaceAtCoordinates(state.x, state.y),
      ),
    );
  }

  void _showResultsWhenFadeCompletes() {
    if (session.raceState.phase != RacePhase.finished) {
      return;
    }
    if (!_finishSoundPlayed) {
      _finishSoundPlayed = true;
      _latestInput = PlayerInput.none;
      unawaited(_audio.finishRace());
    }
    if (_audio.isRaceFadeComplete) {
      _resultsVisible = true;
    }
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
    _setOverlayActive(registeredOverlays, resultsOverlayId, _resultsVisible);
    _setOverlayActive(registeredOverlays, raceHudOverlayId, !_resultsVisible);
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
