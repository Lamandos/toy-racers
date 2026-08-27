import '../car/car_config.dart';
import '../car/car_model.dart';
import '../car/car_physics.dart';
import '../car/car_state.dart';
import '../input/player_control_config.dart';
import '../input/player_input.dart';
import '../math/float32.dart';
import '../race/race_phase.dart';
import '../surface/surface_speed_system.dart';
import 'compatibility_models.dart';

/// A headless simulation boundary used by the compatibility behavior runner.
///
/// The runner owns file I/O, scenario parsing, replay order, and trace output.
/// This interface keeps those concerns separate from the evolving pure-Dart
/// gameplay implementation. A future reference-compatible race session can
/// replace [createCompatibilitySimulation] without changing the CLI contract.
abstract interface class BehaviorSimulation {
  /// The current normalized observation, without advancing simulation time.
  CompatibilitySnapshot get snapshot;

  /// The normalized player command applied during the latest physical tick.
  ///
  /// Input is deliberately not included in a compatibility trace, but keeping
  /// it observable here makes the runner boundary testable without UI input.
  PlayerInput get lastAppliedPlayerInput;

  /// Applies explicitly supplied state before the replay lifecycle begins.
  void applyInitialStates(List<CompatibilityInitialState> states);

  /// Enters the normal countdown lifecycle.
  CompatibilitySnapshot start();

  /// Exposes `loading -> ready` for a state-machine compatibility scenario.
  CompatibilitySnapshot markReadyForLifecycle();

  /// Exposes `ready -> countdown` for a state-machine compatibility scenario.
  CompatibilitySnapshot startCountdownForLifecycle();

  /// Advances only the countdown component of a lifecycle scenario.
  CompatibilitySnapshot advanceCountdown(double deltaSeconds);

  /// Completes a countdown without adding a physical simulation tick.
  CompatibilitySnapshot finishCountdown();

  /// Applies one normalized player [input] for exactly [deltaSeconds].
  CompatibilitySnapshot advance({
    required PlayerInput input,
    required double deltaSeconds,
  });
}

/// Creates the pure-Dart simulation used by the behavior runner.
///
/// This bootstrap implementation establishes the deterministic replay boundary
/// while the physics, collision, track, race-rule, and AI migrations are added
/// independently. It deliberately has no Flutter, Flame, render-loop, or
/// wall-clock dependency.
BehaviorSimulation createCompatibilitySimulation(
  CompatibilityScenario scenario,
) => _CompatibilitySimulation(scenario);

/// Initial pure-Dart replay state, ready for the gameplay migration pipeline.
///
/// It owns lifecycle, initial-state injection, stable participant ordering, and
/// fixed-tick time accounting. Concrete gameplay systems will update the same
/// state through [advance] as they are ported.
final class _CompatibilitySimulation implements BehaviorSimulation {
  _CompatibilitySimulation(CompatibilityScenario scenario)
    : _participants = _createParticipants(scenario),
      _raceState = RaceState();

  static final double fixedDeltaSeconds = Float32.divide(1, 60);

  final List<_CompatibilityParticipant> _participants;
  final RaceState _raceState;
  final CarPhysics _carPhysics = CarPhysics();
  final PlayerControlConfig _playerControlConfig = PlayerControlConfig();
  int _simulationTick = 0;
  PlayerInput _lastPlayerInput = PlayerInput.none;

  @override
  PlayerInput get lastAppliedPlayerInput => _lastPlayerInput;

  @override
  CompatibilitySnapshot get snapshot {
    final participants = List<_CompatibilityParticipant>.of(_participants)
      ..sort((left, right) => left.id.compareTo(right.id));
    final snapshots = participants.map(_snapshotParticipant).toList();
    final ranking = List<_CompatibilityParticipant>.of(participants)
      ..sort(_compareRacePosition);
    final finished =
        participants.where((participant) => participant.finished).toList()
          ..sort(_compareFinishPosition);
    final player = _participantById(_playerId);
    return CompatibilitySnapshot(
      simulationTick: _simulationTick,
      raceState: _raceStateId(_raceState.phase),
      countdown: CompatibilityCountdown(
        state: _countdownStateId(_raceState.phase),
        remainingSeconds: _raceState.countdownRemainingSeconds,
      ),
      elapsedSimulationTime: Float32.multiply(
        _simulationTick.toDouble(),
        fixedDeltaSeconds,
      ),
      currentLap: _currentLap(player),
      currentProgress: CompatibilityProgress(
        checkpoint: player.currentCheckpointIndex,
        completedLaps: player.completedLaps,
      ),
      participants: snapshots,
      ranking: ranking.map((participant) => participant.id).toList(),
      finishedParticipants: finished
          .map((participant) => participant.id)
          .toList(),
      finishResults: finished.map(_finishResult).toList(),
    );
  }

  @override
  void applyInitialStates(List<CompatibilityInitialState> states) {
    for (final state in states) {
      _participantById(state.id).apply(state);
    }
  }

  @override
  CompatibilitySnapshot start() {
    _raceState.markReady();
    _raceState.startCountdown();
    return snapshot;
  }

  @override
  CompatibilitySnapshot markReadyForLifecycle() {
    _raceState.markReady();
    return snapshot;
  }

  @override
  CompatibilitySnapshot startCountdownForLifecycle() {
    _raceState.startCountdown();
    return snapshot;
  }

  @override
  CompatibilitySnapshot advanceCountdown(double deltaSeconds) {
    _raceState.advance(deltaSeconds);
    return snapshot;
  }

  @override
  CompatibilitySnapshot finishCountdown() =>
      advanceCountdown(_raceState.countdownRemainingSeconds);

  @override
  CompatibilitySnapshot advance({
    required PlayerInput input,
    required double deltaSeconds,
  }) {
    final narrowedDelta = Float32.narrow(deltaSeconds);
    if (narrowedDelta != fixedDeltaSeconds) {
      throw ArgumentError.value(
        deltaSeconds,
        'deltaSeconds',
        'must equal the compatibility fixed timestep of 1 / 60 second',
      );
    }
    final racingSeconds = _raceState.advance(narrowedDelta);
    if (racingSeconds == 0) {
      return snapshot;
    }
    _lastPlayerInput = _playerControlConfig.applyTo(input.normalized());
    final player = _participantById(_playerId);
    _carPhysics.update(
      state: player.carState,
      config: player.carConfig,
      input: _lastPlayerInput,
      deltaSeconds: narrowedDelta,
    );
    _simulationTick += 1;
    _advanceRaceTimers();
    return snapshot;
  }

  void _advanceRaceTimers() {
    for (final participant in _participants) {
      if (!participant.finished) {
        participant.totalRaceTime = Float32.add(
          participant.totalRaceTime,
          fixedDeltaSeconds,
        );
      }
    }
  }

  _CompatibilityParticipant _participantById(String id) =>
      _participants.firstWhere(
        (participant) => participant.id == id,
        orElse: () => throw ArgumentError.value(
          id,
          'id',
          'is not a compatibility participant',
        ),
      );

  CompatibilityParticipantSnapshot _snapshotParticipant(
    _CompatibilityParticipant participant,
  ) => CompatibilityParticipantSnapshot(
    id: participant.id,
    surface: participant.surface,
    x: participant.carState.x,
    y: participant.carState.y,
    rotation: _normalizeRotation(participant.carState.rotationDegrees),
    velocityX: participant.carState.velocityX,
    velocityY: participant.carState.velocityY,
    angularVelocity: participant.carState.angularVelocity,
    longitudinalSpeed: participant.carState.longitudinalSpeed,
    lateralSpeed: participant.carState.lateralSpeed,
    driftAmount: participant.carState.driftAmount,
    checkpoint: participant.currentCheckpointIndex,
    lap: participant.completedLaps,
    racePosition: participant.racePosition,
    finished: participant.finished,
  );

  CompatibilityFinishResult _finishResult(
    _CompatibilityParticipant participant,
  ) => CompatibilityFinishResult(
    participantId: participant.id,
    finishPosition: participant.finishPosition!,
    elapsedSimulationTime: participant.totalRaceTime,
    bestLapTime: participant.bestLapTime,
  );

  int _currentLap(_CompatibilityParticipant participant) =>
      (participant.completedLaps + 1).clamp(1, _requiredLaps);

  static List<_CompatibilityParticipant> _createParticipants(
    CompatibilityScenario scenario,
  ) => <_CompatibilityParticipant>[
    for (var index = 0; index < _aiCount; index++)
      _CompatibilityParticipant(id: 'ai-$index', racePosition: index + 2),
    _CompatibilityParticipant(
      id: _playerId,
      racePosition: 1,
      carConfig: CarModel.fromScenarioId(scenario.playerCar).performance
          .applyTo(),
    ),
  ];

  static int _compareRacePosition(
    _CompatibilityParticipant left,
    _CompatibilityParticipant right,
  ) {
    final position = left.racePosition.compareTo(right.racePosition);
    return position != 0 ? position : left.id.compareTo(right.id);
  }

  static int _compareFinishPosition(
    _CompatibilityParticipant left,
    _CompatibilityParticipant right,
  ) {
    final position = left.finishPosition!.compareTo(right.finishPosition!);
    return position != 0 ? position : left.id.compareTo(right.id);
  }

  static String _raceStateId(RacePhase phase) => switch (phase) {
    RacePhase.loading => 'loading',
    RacePhase.ready => 'ready',
    RacePhase.countdown => 'countdown',
    RacePhase.racing => 'racing',
    RacePhase.paused => 'paused',
    RacePhase.finished => 'finished',
  };

  static String _countdownStateId(RacePhase phase) => switch (phase) {
    RacePhase.loading || RacePhase.ready => 'not-started',
    RacePhase.countdown => 'active',
    RacePhase.racing || RacePhase.paused || RacePhase.finished => 'complete',
  };

  static double _normalizeRotation(double rotation) {
    final wrapped = Float32.narrow(rotation % _degreesPerTurn);
    final normalized = wrapped < 0
        ? Float32.add(wrapped, _degreesPerTurn)
        : wrapped;
    return normalized >= _degreesPerTurn || normalized == 0 ? 0 : normalized;
  }

  static const int _aiCount = 5;
  static const int _requiredLaps = 3;
  static const String _playerId = 'player';
  static const double _degreesPerTurn = 360;
}

/// Mutable participant state observed by the compatibility trace adapter.
final class _CompatibilityParticipant {
  _CompatibilityParticipant({
    required this.id,
    required this.racePosition,
    CarConfig? carConfig,
  }) : carState = CarState(),
       carConfig = carConfig ?? CarConfig(),
       surfaceSpeedState = SurfaceSpeedState();

  final String id;
  final CarState carState;
  final CarConfig carConfig;
  final SurfaceSpeedState surfaceSpeedState;
  String surface = 'asphalt';
  int currentCheckpointIndex = 0;
  int completedLaps = 0;
  int racePosition;
  double lapStartTime = 0;
  double totalRaceTime = 0;
  double? bestLapTime;
  bool finished = false;
  int? finishPosition;

  void apply(CompatibilityInitialState initial) {
    carState.x = initial.x ?? carState.x;
    carState.y = initial.y ?? carState.y;
    carState.rotationDegrees = initial.rotationDeg ?? carState.rotationDegrees;
    carState.longitudinalSpeed = initial.speed ?? carState.longitudinalSpeed;
    carState.velocityX = initial.velocityX ?? carState.velocityX;
    carState.velocityY = initial.velocityY ?? carState.velocityY;
    carState.angularVelocity =
        initial.angularVelocity ?? carState.angularVelocity;
    carState.lateralSpeed = initial.lateralSpeed ?? carState.lateralSpeed;
    carState.driftAmount = initial.driftAmount ?? carState.driftAmount;
    surfaceSpeedState.speedMultiplier =
        initial.surfaceSpeedMultiplier ?? surfaceSpeedState.speedMultiplier;
    currentCheckpointIndex =
        initial.currentCheckpointIndex ?? currentCheckpointIndex;
    completedLaps = initial.completedLaps ?? completedLaps;
    lapStartTime = initial.lapStartTime ?? lapStartTime;
    totalRaceTime = initial.totalRaceTime ?? totalRaceTime;
    bestLapTime = initial.bestLapTime ?? bestLapTime;
    finished = initial.finished ?? finished;
    finishPosition = initial.finishPosition ?? finishPosition;
    if (finishPosition != null) {
      racePosition = finishPosition!;
    }
  }
}
