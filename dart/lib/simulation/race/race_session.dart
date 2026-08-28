import 'dart:math' as math;

import '../ai/ai_driver.dart';
import '../ai/ai_race_context.dart';
import '../car/car_config.dart';
import '../car/car_physics.dart';
import '../car/car_state.dart';
import '../collision/collision_system.dart';
import '../input/player_control_config.dart';
import '../input/player_input.dart';
import '../math/float32.dart';
import '../snapshot/simulation_snapshot.dart';
import '../surface/surface_speed_system.dart';
import '../surface/surface_type.dart';
import '../track/track.dart';
import '../track/track_point.dart';
import 'position_tracker.dart';
import 'race_phase.dart';
import 'race_progress.dart';
import 'race_result.dart';
import 'race_rules.dart';

/// A stable participant in a [RaceSession].
final class RaceParticipant {
  RaceParticipant({
    required String id,
    required this.carState,
    required this.carConfig,
    this.aiDriver,
    SurfaceSpeedState? surfaceSpeedState,
    RaceProgress? progress,
  }) : id = _requireId(id),
       surfaceSpeedState = surfaceSpeedState ?? SurfaceSpeedState(),
       progress = progress ?? RaceProgress(),
       _lastSafeState = carState.copy(),
       _previousState = carState.copy();

  final String id;
  final CarState carState;
  final CarConfig carConfig;
  final AiDriver? aiDriver;
  final SurfaceSpeedState surfaceSpeedState;
  final RaceProgress progress;
  CarState _lastSafeState;
  CarState _previousState;

  /// Last state that an AI recovery operation may restore.
  CarState get lastSafeState => _lastSafeState.copy();

  /// State before the latest completed fixed step, for presentation only.
  CarState get previousState => _previousState.copy();

  void _captureStateForRendering() {
    _previousState = carState.copy();
  }

  void _saveLastSafeState() {
    _lastSafeState = carState.copy();
  }

  static String _requireId(String id) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be blank');
    }
    return id;
  }
}

/// Session-only tuning that is not part of vehicle physics.
final class RaceSessionConfig {
  RaceSessionConfig({double safeStateMinSpeed = 2})
    : safeStateMinSpeed = Float32.narrow(safeStateMinSpeed) {
    if (this.safeStateMinSpeed < 0) {
      throw ArgumentError.value(
        safeStateMinSpeed,
        'safeStateMinSpeed',
        'must not be negative',
      );
    }
  }

  final double safeStateMinSpeed;
}

/// Fixed-step result emitted by [RaceSession.advance].
final class RaceStepResult {
  const RaceStepResult({
    required this.phaseBeforeAdvance,
    this.appliedPlayerInput,
    required this.playerCheckpointPassed,
    required this.maxImpactSpeed,
    required this.physicalSteps,
  });

  final RacePhase phaseBeforeAdvance;

  /// The player command consumed by physics, or `null` when no step ran.
  final PlayerInput? appliedPlayerInput;
  final bool playerCheckpointPassed;
  final double maxImpactSpeed;
  final int physicalSteps;
}

/// Headless assembly root for one deterministic race simulation.
///
/// It owns the same participant order as the Kotlin reference: the player,
/// followed by each supplied AI participant. Presentation must only observe
/// this state and may not substitute a frame loop or collision system.
final class RaceSession {
  RaceSession({
    required this.track,
    required Iterable<RaceParticipant> participants,
    RaceState? raceState,
    int requiredLaps = RaceRules.defaultLapCount,
    CarPhysics? carPhysics,
    CollisionSystem? collisionSystem,
    SurfaceSpeedSystem? surfaceSpeedSystem,
    PlayerControlConfig? playerControlConfig,
    RaceSessionConfig? sessionConfig,
    String playerId = _defaultPlayerId,
  }) : participants = List<RaceParticipant>.unmodifiable(
         _playerFirstParticipants(participants, playerId),
       ),
       raceState = raceState ?? RaceState(),
       _carPhysics = carPhysics ?? CarPhysics(),
       _collisionSystem = collisionSystem ?? CollisionSystem(),
       _surfaceSpeedSystem = surfaceSpeedSystem ?? SurfaceSpeedSystem(),
       _playerControlConfig = playerControlConfig ?? PlayerControlConfig(),
       _sessionConfig = sessionConfig ?? RaceSessionConfig(),
       _playerId = playerId,
       _raceRules = RaceRules(track, requiredLaps: requiredLaps),
       _positionTracker = PositionTracker(track) {
    if (this.participants.isEmpty) {
      throw ArgumentError.value(
        participants,
        'participants',
        'must not be empty',
      );
    }
    final participantIds = this.participants
        .map((participant) => participant.id)
        .toSet();
    if (participantIds.length != this.participants.length) {
      throw ArgumentError.value(
        participants,
        'participants',
        'must have unique IDs',
      );
    }
    if (!participantIds.contains(_playerId)) {
      throw ArgumentError.value(
        playerId,
        'playerId',
        'must identify a participant',
      );
    }
  }

  final Track track;
  final List<RaceParticipant> participants;
  final RaceState raceState;
  final CarPhysics _carPhysics;
  final CollisionSystem _collisionSystem;
  final SurfaceSpeedSystem _surfaceSpeedSystem;
  final PlayerControlConfig _playerControlConfig;
  final RaceSessionConfig _sessionConfig;
  final String _playerId;
  final RaceRules _raceRules;
  final PositionTracker _positionTracker;
  double _accumulator = 0;

  RaceParticipant get player =>
      participants.firstWhere((participant) => participant.id == _playerId);

  List<RaceParticipant> get opponents => List<RaceParticipant>.unmodifiable(
    participants.where((participant) => participant.id != _playerId),
  );

  int get requiredLaps => _raceRules.requiredLaps;

  int get playerPosition => participantPositions[_playerId]!;

  /// Positions keyed by stable participant IDs.
  Map<String, int> get participantPositions => _positionTracker.positions(
    participants.map(
      (participant) => RaceCompetitor(
        id: participant.id,
        progress: participant.progress,
        position: TrackPoint(participant.carState.x, participant.carState.y),
      ),
    ),
  );

  /// Every finished result, sorted by finish position and participant ID.
  List<ParticipantRaceResult> get finishResults {
    final results =
        participants
            .where((participant) => participant.progress.finished)
            .toList()
          ..sort(_compareFinishers);
    return List<ParticipantRaceResult>.unmodifiable(
      results.map(
        (participant) => ParticipantRaceResult(
          participantId: participant.id,
          result: _resultFor(participant),
        ),
      ),
    );
  }

  /// Immutable per-participant result values keyed by stable ID.
  Map<String, RaceResult> get results => <String, RaceResult>{
    for (final result in finishResults) result.participantId: result.result,
  };

  RaceResult? get playerResult =>
      player.progress.finished ? _resultFor(player) : null;

  /// Exposes the initial deterministic lifecycle state without advancing time.
  SimulationSnapshot get snapshot => SimulationSnapshot(
    simulationTick: 0,
    racePhase: raceState.phase,
    countdownRemainingSeconds: raceState.countdownRemainingSeconds,
    elapsedSimulationTime: 0,
  );

  void start() {
    raceState.markReady();
    raceState.startCountdown();
  }

  void pause() => raceState.pause();

  void resume() => raceState.resume();

  /// Synchronizes fixture-injected finish positions before race progression.
  void synchronizeFinishOrdering() => _raceRules.synchronizeFinishOrdering(
    participants.map((value) => value.progress),
  );

  /// Advances the fixed simulation pipeline using explicit frame time.
  RaceStepResult advance({
    required double frameDeltaSeconds,
    required PlayerInput playerInput,
  }) {
    final phaseBeforeAdvance = raceState.phase;
    final simulationDelta = raceState.advance(frameDeltaSeconds);
    if (simulationDelta <= 0) {
      return _emptyStep(phaseBeforeAdvance);
    }

    _accumulator = Float32.add(_accumulator, simulationDelta);
    final appliedPlayerInput = _playerControlConfig.applyTo(
      playerInput.normalized(),
    );
    var playerCheckpointPassed = false;
    var maxImpactSpeed = 0.0;
    var physicalSteps = 0;
    while (_accumulator >= CarPhysics.fixedDeltaSeconds) {
      for (final participant in participants) {
        participant._captureStateForRendering();
      }
      for (final participant in participants) {
        _updateLastSafeState(participant);
        final result = _updateParticipant(participant, appliedPlayerInput);
        if (participant.id == _playerId) {
          maxImpactSpeed = math.max(maxImpactSpeed, result.impactSpeed);
          playerCheckpointPassed =
              playerCheckpointPassed || result.checkpointPassed;
        }
      }
      maxImpactSpeed = math.max(maxImpactSpeed, _resolveCarCollisions());
      physicalSteps++;
      _accumulator = Float32.subtract(
        _accumulator,
        CarPhysics.fixedDeltaSeconds,
      );
      if (player.progress.finished) {
        for (final participant in participants) {
          participant._captureStateForRendering();
        }
        raceState.finish();
        _accumulator = 0;
        break;
      }
    }
    return RaceStepResult(
      phaseBeforeAdvance: phaseBeforeAdvance,
      appliedPlayerInput: physicalSteps > 0 ? appliedPlayerInput : null,
      playerCheckpointPassed: playerCheckpointPassed,
      maxImpactSpeed: Float32.narrow(maxImpactSpeed),
      physicalSteps: physicalSteps,
    );
  }

  _ParticipantStepResult _updateParticipant(
    RaceParticipant participant,
    PlayerInput appliedPlayerInput,
  ) {
    final previousPosition = TrackPoint(
      participant.carState.x,
      participant.carState.y,
    );
    final participantInput = _inputFor(participant, appliedPlayerInput);
    _carPhysics.update(
      state: participant.carState,
      config: participant.carConfig,
      input: participantInput.input,
      deltaSeconds: CarPhysics.fixedDeltaSeconds,
    );
    final collision = _collisionSystem.resolveTrackCollision(
      state: participant.carState,
      config: participant.carConfig,
      track: track,
    );
    _surfaceSpeedSystem.update(
      carState: participant.carState,
      carConfig: participant.carConfig,
      surfaceState: participant.surfaceSpeedState,
      surface: track.surfaceAtCoordinates(
        participant.carState.x,
        participant.carState.y,
      ),
      deltaSeconds: CarPhysics.fixedDeltaSeconds,
    );
    final checkpointBefore = participant.progress.currentCheckpointIndex;
    _raceRules.update(
      progress: participant.progress,
      previousPosition: previousPosition,
      currentPosition: TrackPoint(
        participant.carState.x,
        participant.carState.y,
      ),
      deltaSeconds: CarPhysics.fixedDeltaSeconds,
      allowProgress: !participantInput.respawned,
    );
    return _ParticipantStepResult(
      checkpointPassed:
          participant.progress.currentCheckpointIndex > checkpointBefore,
      impactSpeed: collision.maxImpactSpeed,
    );
  }

  _ParticipantInput _inputFor(
    RaceParticipant participant,
    PlayerInput appliedPlayerInput,
  ) {
    if (participant.id == _playerId) {
      return _ParticipantInput(input: appliedPlayerInput);
    }
    final driver = participant.aiDriver;
    if (driver == null) {
      return _ParticipantInput(input: PlayerInput.none);
    }
    final decision = driver.update(
      carState: participant.carState,
      deltaSeconds: CarPhysics.fixedDeltaSeconds,
      context: AiRaceContext(
        obstacles: _obstaclesFor(participant),
        finished: participant.progress.finished,
        isOnTrack: track
            .surfaceAtCoordinates(
              participant.carState.x,
              participant.carState.y,
            )
            .isRoad,
      ),
    );
    if (decision.requestRespawn) {
      _restoreLastSafeState(participant);
      return _ParticipantInput(input: PlayerInput.none, respawned: true);
    }
    return _ParticipantInput(input: decision.input);
  }

  void _updateLastSafeState(RaceParticipant participant) {
    final driver = participant.aiDriver;
    if (driver == null ||
        !track
            .surfaceAtCoordinates(
              participant.carState.x,
              participant.carState.y,
            )
            .isRoad ||
        participant.carState.longitudinalSpeed.abs() <
            _sessionConfig.safeStateMinSpeed ||
        !driver.isFacingRoute(participant.carState)) {
      return;
    }
    participant._saveLastSafeState();
  }

  void _restoreLastSafeState(RaceParticipant participant) {
    final safe = participant._lastSafeState;
    participant.carState
      ..x = safe.x
      ..y = safe.y
      ..rotationDegrees = safe.rotationDegrees
      ..longitudinalSpeed = 0
      ..velocityX = 0
      ..velocityY = 0
      ..angularVelocity = 0
      ..lateralSpeed = 0
      ..driftAmount = 0;
    participant.surfaceSpeedState.speedMultiplier = 1;
    participant._captureStateForRendering();
  }

  double _resolveCarCollisions() {
    var maxImpactSpeed = 0.0;
    for (var firstIndex = 0; firstIndex < participants.length; firstIndex++) {
      for (
        var secondIndex = firstIndex + 1;
        secondIndex < participants.length;
        secondIndex++
      ) {
        final result = _collisionSystem.resolveCarCollision(
          firstState: participants[firstIndex].carState,
          firstConfig: participants[firstIndex].carConfig,
          secondState: participants[secondIndex].carState,
          secondConfig: participants[secondIndex].carConfig,
        );
        maxImpactSpeed = math.max(maxImpactSpeed, result.maxImpactSpeed);
      }
    }
    return maxImpactSpeed;
  }

  List<AiObstacle> _obstaclesFor(RaceParticipant participant) => participants
      .where((other) => !identical(other, participant))
      .map(
        (other) => AiObstacle(
          x: other.carState.x,
          y: other.carState.y,
          radius: other.carConfig.collisionRadius,
          speed: other.carState.longitudinalSpeed,
        ),
      )
      .toList(growable: false);

  RaceResult _resultFor(RaceParticipant participant) => RaceResult(
    finishPosition: participant.progress.finishPosition!,
    competitorCount: participants.length,
    totalRaceTime: participant.progress.totalRaceTime,
    bestLapTime: participant.progress.bestLapTime,
  );

  int _compareFinishers(RaceParticipant left, RaceParticipant right) {
    final position = left.progress.finishPosition!.compareTo(
      right.progress.finishPosition!,
    );
    return position != 0 ? position : left.id.compareTo(right.id);
  }

  RaceStepResult _emptyStep(RacePhase phase) => RaceStepResult(
    phaseBeforeAdvance: phase,
    playerCheckpointPassed: false,
    maxImpactSpeed: 0,
    physicalSteps: 0,
  );

  static List<RaceParticipant> _playerFirstParticipants(
    Iterable<RaceParticipant> participants,
    String playerId,
  ) {
    final supplied = participants.toList(growable: false);
    final playerIndex = supplied.indexWhere(
      (participant) => participant.id == playerId,
    );
    if (playerIndex < 0) {
      return supplied;
    }
    return <RaceParticipant>[
      supplied[playerIndex],
      ...supplied.take(playerIndex),
      ...supplied.skip(playerIndex + 1),
    ];
  }

  static const String _defaultPlayerId = 'player';
}

final class _ParticipantInput {
  const _ParticipantInput({required this.input, this.respawned = false});

  final PlayerInput input;
  final bool respawned;
}

final class _ParticipantStepResult {
  const _ParticipantStepResult({
    required this.checkpointPassed,
    required this.impactSpeed,
  });

  final bool checkpointPassed;
  final double impactSpeed;
}
