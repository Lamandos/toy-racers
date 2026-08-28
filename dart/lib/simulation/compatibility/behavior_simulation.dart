import '../car/car_model.dart';
import '../car/car_physics.dart';
import '../car/car_state.dart';
import '../input/driver_input.dart';
import '../input/player_input.dart';
import '../math/float32.dart';
import '../race/race_phase.dart';
import '../race/race_progress.dart';
import '../race/race_result.dart';
import '../race/race_session.dart';
import '../surface/surface_type.dart';
import '../track/checkpoint.dart';
import '../track/track.dart';
import '../track/track_geometry.dart';
import '../track/start_grid_position.dart';
import '../track/track_point.dart';
import 'compatibility_models.dart';

/// A headless simulation boundary used by the compatibility behavior runner.
///
/// The runner owns file I/O, scenario parsing, replay order, and trace output.
/// This interface keeps those concerns separate from the pure-Dart gameplay
/// systems that own car state, race progression, and fixed-step timing.
abstract interface class BehaviorSimulation {
  /// The current normalized observation, without advancing simulation time.
  CompatibilitySnapshot get snapshot;

  /// The normalized player command applied during the latest physical tick.
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
    required covariant PlayerInput input,
    required double deltaSeconds,
  });
}

/// Creates the pure-Dart simulation used by the compatibility behavior runner.
///
/// [track] remains optional for source compatibility with pre-Task 12 callers;
/// those calls use a deterministic in-memory fallback. The behavior runner
/// supplies the scenario's loaded track explicitly.
BehaviorSimulation createCompatibilitySimulation(
  CompatibilityScenario scenario, {
  Track? track,
}) =>
    _CompatibilitySimulation(scenario, track ?? _compatibilityFallbackTrack());

/// Adapts [RaceSession] state to the versioned compatibility trace contract.
final class _CompatibilitySimulation implements BehaviorSimulation {
  _CompatibilitySimulation(CompatibilityScenario scenario, Track track)
    : _session = RaceSession(
        track: track,
        participants: _createParticipants(track, scenario),
      );

  final RaceSession _session;
  int _simulationTick = 0;
  PlayerInput _lastPlayerInput = PlayerInput.none;

  @override
  PlayerInput get lastAppliedPlayerInput => _lastPlayerInput;

  @override
  CompatibilitySnapshot get snapshot {
    final positions = _session.participantPositions;
    final participants = List<RaceParticipant>.of(_session.participants)
      ..sort((left, right) => left.id.compareTo(right.id));
    final finished = _session.finishResults;
    final player = _session.player;
    return CompatibilitySnapshot(
      simulationTick: _simulationTick,
      raceState: _raceStateId(_session.raceState.phase),
      countdown: CompatibilityCountdown(
        state: _countdownStateId(_session.raceState.phase),
        remainingSeconds: _session.raceState.countdownRemainingSeconds,
      ),
      elapsedSimulationTime: Float32.elapsedSimulationTime(_simulationTick),
      currentLap: _currentLap(player.progress),
      currentProgress: CompatibilityProgress(
        checkpoint: player.progress.currentCheckpointIndex,
        completedLaps: player.progress.completedLaps,
      ),
      participants: participants
          .map((participant) => _snapshotParticipant(participant, positions))
          .toList(),
      ranking: _ranking(positions),
      finishedParticipants: finished
          .map((result) => result.participantId)
          .toList(),
      finishResults: finished.map(_finishResult).toList(),
    );
  }

  @override
  void applyInitialStates(List<CompatibilityInitialState> states) {
    for (final state in states) {
      _applyInitialState(_participantById(state.id), state);
    }
    _session.synchronizeFinishOrdering();
  }

  @override
  CompatibilitySnapshot start() {
    _session.start();
    return snapshot;
  }

  @override
  CompatibilitySnapshot markReadyForLifecycle() {
    _session.raceState.markReady();
    return snapshot;
  }

  @override
  CompatibilitySnapshot startCountdownForLifecycle() {
    _session.raceState.startCountdown();
    return snapshot;
  }

  @override
  CompatibilitySnapshot advanceCountdown(double deltaSeconds) {
    final narrowedDelta = Float32.narrow(deltaSeconds);
    final remainingSeconds = _session.raceState.countdownRemainingSeconds;
    final countdownDelta = narrowedDelta > remainingSeconds
        ? remainingSeconds
        : narrowedDelta;
    _session.raceState.advance(countdownDelta);
    return snapshot;
  }

  @override
  CompatibilitySnapshot finishCountdown() =>
      advanceCountdown(_session.raceState.countdownRemainingSeconds);

  @override
  CompatibilitySnapshot advance({
    required PlayerInput input,
    required double deltaSeconds,
  }) {
    final narrowedDelta = Float32.narrow(deltaSeconds);
    if (narrowedDelta != CarPhysics.fixedDeltaSeconds) {
      throw ArgumentError.value(
        deltaSeconds,
        'deltaSeconds',
        'must equal the compatibility fixed timestep of 1 / 60 second',
      );
    }
    final result = _session.advance(
      frameDeltaSeconds: narrowedDelta,
      playerInput: input,
    );
    if (result.physicalSteps > 0) {
      _lastPlayerInput = result.appliedPlayerInput!;
    }
    _simulationTick += result.physicalSteps;
    return snapshot;
  }

  RaceParticipant _participantById(String id) =>
      _session.participants.firstWhere(
        (participant) => participant.id == id,
        orElse: () => throw ArgumentError.value(
          id,
          'id',
          'is not a compatibility participant',
        ),
      );

  void _applyInitialState(
    RaceParticipant participant,
    CompatibilityInitialState initial,
  ) {
    final state = participant.carState;
    state.x = initial.x ?? state.x;
    state.y = initial.y ?? state.y;
    state.rotationDegrees = initial.rotationDeg ?? state.rotationDegrees;
    state.longitudinalSpeed = initial.speed ?? state.longitudinalSpeed;
    state.velocityX = initial.velocityX ?? state.velocityX;
    state.velocityY = initial.velocityY ?? state.velocityY;
    state.angularVelocity = initial.angularVelocity ?? state.angularVelocity;
    state.lateralSpeed = initial.lateralSpeed ?? state.lateralSpeed;
    state.driftAmount = initial.driftAmount ?? state.driftAmount;
    participant.surfaceSpeedState.speedMultiplier =
        initial.surfaceSpeedMultiplier ??
        participant.surfaceSpeedState.speedMultiplier;
    final progress = participant.progress;
    progress.currentCheckpointIndex =
        initial.currentCheckpointIndex ?? progress.currentCheckpointIndex;
    progress.completedLaps = initial.completedLaps ?? progress.completedLaps;
    progress.lapStartTime = initial.lapStartTime ?? progress.lapStartTime;
    progress.totalRaceTime = initial.totalRaceTime ?? progress.totalRaceTime;
    progress.bestLapTime = initial.bestLapTime ?? progress.bestLapTime;
    progress.finished = initial.finished ?? progress.finished;
    progress.finishPosition = initial.finishPosition ?? progress.finishPosition;
  }

  CompatibilityParticipantSnapshot _snapshotParticipant(
    RaceParticipant participant,
    Map<String, int> positions,
  ) => CompatibilityParticipantSnapshot(
    id: participant.id,
    surface: _surfaceId(
      _session.track.surfaceAtCoordinates(
        participant.carState.x,
        participant.carState.y,
      ),
    ),
    x: participant.carState.x,
    y: participant.carState.y,
    rotation: Float32.normalizeRotationDegrees(
      participant.carState.rotationDegrees,
    ),
    velocityX: participant.carState.velocityX,
    velocityY: participant.carState.velocityY,
    angularVelocity: participant.carState.angularVelocity,
    longitudinalSpeed: participant.carState.longitudinalSpeed,
    lateralSpeed: participant.carState.lateralSpeed,
    driftAmount: participant.carState.driftAmount,
    checkpoint: participant.progress.currentCheckpointIndex,
    lap: participant.progress.completedLaps,
    racePosition: positions[participant.id]!,
    finished: participant.progress.finished,
  );

  List<String> _ranking(Map<String, int> positions) {
    final participants = positions.keys.toList()
      ..sort((left, right) {
        final order = positions[left]!.compareTo(positions[right]!);
        return order != 0 ? order : left.compareTo(right);
      });
    return participants;
  }

  CompatibilityFinishResult _finishResult(ParticipantRaceResult result) =>
      CompatibilityFinishResult(
        participantId: result.participantId,
        finishPosition: result.result.finishPosition,
        elapsedSimulationTime: result.result.totalRaceTime,
        bestLapTime: result.result.bestLapTime,
      );

  int _currentLap(RaceProgress progress) =>
      (progress.completedLaps + 1).clamp(1, _session.requiredLaps);

  static List<RaceParticipant> _createParticipants(
    Track track,
    CompatibilityScenario scenario,
  ) {
    final playerModel = CarModel.fromScenarioId(scenario.playerCar);
    final opponentModels = <CarModel>[
      ...CarModel.values.where((model) => model != playerModel),
      CarModel.values.firstWhere((model) => model != playerModel),
    ];
    if (track.startGrid.length != opponentModels.length + 1) {
      throw ArgumentError(
        'Start grid must contain one position for every race participant',
      );
    }
    return <RaceParticipant>[
      RaceParticipant(
        id: _playerId,
        carState: _stateAt(track.startGrid.first),
        carConfig: playerModel.performance.applyTo(),
      ),
      for (var index = 0; index < opponentModels.length; index++)
        RaceParticipant(
          id: 'ai-$index',
          carState: _stateAt(track.startGrid[index + 1]),
          carConfig: opponentModels[index].performance.applyTo(),
        ),
    ];
  }

  static CarState _stateAt(StartGridPosition start) => CarState(
    x: start.position.x,
    y: start.position.y,
    rotationDegrees: start.rotationDegrees,
  );

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

  static String _surfaceId(SurfaceType surface) => switch (surface) {
    SurfaceType.asphalt => 'asphalt',
    SurfaceType.parquet => 'parquet',
    SurfaceType.tile => 'tile',
    SurfaceType.grass => 'grass',
    SurfaceType.boost => 'boost',
    SurfaceType.oil => 'oil',
  };

  static const String _playerId = 'player';
}

/// Supplies a deterministic in-memory track for legacy factory callers.
Track _compatibilityFallbackTrack() {
  final bounds = TrackRectangle(0, 0, 100, 100);
  return Track.fromDefinition(
    id: 'compatibility-default',
    name: 'COMPATIBILITY DEFAULT',
    worldBounds: bounds,
    cameraBounds: bounds,
    outerBoundary: bounds,
    backgroundSurface: SurfaceType.asphalt,
    startLine: StartLine(
      bounds: TrackRectangle(50, 40, 2, 20),
      forwardX: 1,
      forwardY: 0,
    ),
    checkpoints: <Checkpoint>[
      Checkpoint(
        order: 0,
        gate: TrackSegment(TrackPoint(20, 40), TrackPoint(20, 60)),
        forwardX: 1,
        forwardY: 0,
      ),
    ],
    startGrid: List<StartGridPosition>.generate(
      6,
      (index) => StartGridPosition(
        position: TrackPoint(10, 10 + index * 10),
        rotationDegrees: 0,
      ),
    ),
    racingLine: <TrackPoint>[
      TrackPoint(10, 10),
      TrackPoint(20, 10),
      TrackPoint(50, 10),
    ],
  );
}
