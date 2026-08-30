import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  test('lifecycle only simulates after GO and pause freezes race timers', () {
    final session = _session();
    final initialX = session.player.carState.x;

    expect(
      session
          .advance(
            frameDeltaSeconds: CarPhysics.fixedDeltaSeconds,
            playerInput: PlayerInput(throttle: 1),
          )
          .physicalSteps,
      0,
    );

    session.start();
    expect(
      session
          .advance(
            frameDeltaSeconds: session.raceState.countdownDurationSeconds,
            playerInput: PlayerInput(throttle: 1),
          )
          .physicalSteps,
      0,
    );
    expect(session.raceState.phase, RacePhase.racing);

    final racingStep = session.advance(
      frameDeltaSeconds: CarPhysics.fixedDeltaSeconds,
      playerInput: PlayerInput(throttle: 1),
    );
    expect(racingStep.physicalSteps, 1);
    expect(session.player.carState.x, greaterThan(initialX));
    expect(session.player.progress.totalRaceTime, CarPhysics.fixedDeltaSeconds);
    expect(session.snapshot.simulationTick, 1);
    expect(
      session.snapshot.elapsedSimulationTime,
      CarPhysics.fixedDeltaSeconds,
    );

    session.pause();
    final pausedX = session.player.carState.x;
    final pausedTime = session.player.progress.totalRaceTime;
    expect(
      session
          .advance(frameDeltaSeconds: 1, playerInput: PlayerInput(throttle: 1))
          .physicalSteps,
      0,
    );
    expect(session.player.carState.x, pausedX);
    expect(session.player.progress.totalRaceTime, pausedTime);
    expect(session.raceState.phase, RacePhase.paused);
  });

  test('restart restores participants and simulation counters', () {
    final session = _session();
    _startRacing(session);
    session.advance(
      frameDeltaSeconds: CarPhysics.fixedDeltaSeconds,
      playerInput: PlayerInput(throttle: 1),
    );
    session.player.carState.x = 80;
    session.player.progress
      ..completedLaps = 2
      ..totalRaceTime = 12;

    session.restart();

    expect(session.raceState.phase, RacePhase.countdown);
    expect(session.snapshot.simulationTick, 0);
    expect(session.player.carState.x, 10);
    expect(session.player.carState.longitudinalSpeed, 0);
    expect(session.player.progress.currentCheckpointIndex, 0);
    expect(session.player.progress.completedLaps, 0);
    expect(session.player.progress.totalRaceTime, 0);
    expect(session.player.progress.finished, isFalse);
  });

  test('processes a checkpoint through the shared participant pipeline', () {
    final session = _session();
    _startRacing(session);
    session.player.carState
      ..x = 19.8
      ..y = 50
      ..longitudinalSpeed = 24
      ..velocityX = 24;

    final step = session.advance(
      frameDeltaSeconds: CarPhysics.fixedDeltaSeconds,
      playerInput: PlayerInput.none,
    );

    expect(step.playerCheckpointPassed, isTrue);
    expect(session.player.progress.currentCheckpointIndex, 1);
    expect(session.player.progress.completedLaps, 0);
  });

  test(
    'keeps the player first when participants are supplied out of order',
    () {
      final player = _participant('player', 10, 50);
      final opponent = _participant('ai-0', 10, 60);
      final session = RaceSession(
        track: _track(),
        participants: <RaceParticipant>[opponent, player],
        playerId: 'player',
      );

      expect(
        session.participants,
        orderedEquals(<RaceParticipant>[player, opponent]),
      );
    },
  );

  test('infers the first participant as player when playerId is omitted', () {
    final human = _participant('human', 10, 50);
    final opponent = _participant('ai-0', 10, 60);
    final session = RaceSession(
      track: _track(),
      participants: <RaceParticipant>[human, opponent],
    );

    expect(session.player, same(human));
    expect(
      session.participants,
      orderedEquals(<RaceParticipant>[human, opponent]),
    );
  });

  test('rejects duplicate IDs after reordering the participants', () {
    expect(
      () => RaceSession(
        track: _track(),
        participants: <RaceParticipant>[
          _participant('ai-0', 10, 60),
          _participant('player', 10, 50),
          _participant('player', 10, 70),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('does not apply player commands to driverless opponents', () {
    final session = _session(aiCount: 1);
    _startRacing(session);
    final opponent = session.opponents.single;

    session.advance(
      frameDeltaSeconds: CarPhysics.fixedDeltaSeconds,
      playerInput: PlayerInput(throttle: 1, steering: 1),
    );

    expect(session.player.carState.longitudinalSpeed, greaterThan(0));
    expect(opponent.carState.longitudinalSpeed, 0);
    expect(opponent.carState.x, 10);
    expect(opponent.carState.y, 60);
  });

  test(
    'keeps legacy AI drivers source-compatible without optional capabilities',
    () {
      final session = _session(aiCount: 1, driver: _LegacyAiDriver());
      _startRacing(session);

      expect(
        () => session.advance(
          frameDeltaSeconds: CarPhysics.fixedDeltaSeconds,
          playerInput: PlayerInput.none,
        ),
        returnsNormally,
      );
    },
  );

  test('reports the normalized player command used by the physics step', () {
    final session = _session();
    final beforeRacing = session.advance(
      frameDeltaSeconds: CarPhysics.fixedDeltaSeconds,
      playerInput: PlayerInput(steering: 1),
    );
    _startRacing(session);

    final result = session.advance(
      frameDeltaSeconds: CarPhysics.fixedDeltaSeconds,
      playerInput: PlayerInput(throttle: 2, brake: -1, steering: 1),
    );

    expect(
      result.appliedPlayerInput,
      PlayerInput(throttle: 1, brake: 0, steering: 0.85),
    );
    expect(beforeRacing.appliedPlayerInput, isNull);
  });

  test(
    'near-simultaneous finishes keep participant order, ranking, and results',
    () {
      final session = _session(requiredLaps: 1, aiCount: 2);
      _startRacing(session);
      for (final entry in <(RaceParticipant, double)>[
        (session.player, 50),
        (session.opponents[0], 45),
        (session.opponents[1], 55),
      ]) {
        entry.$1.progress.currentCheckpointIndex = 2;
        entry.$1.carState
          ..x = 50.9
          ..y = entry.$2
          ..longitudinalSpeed = 24
          ..velocityX = 24;
      }

      final step = session.advance(
        frameDeltaSeconds: CarPhysics.fixedDeltaSeconds,
        playerInput: PlayerInput.none,
      );

      expect(step.physicalSteps, 1);
      expect(session.raceState.phase, RacePhase.finished);
      expect(
        session.finishResults.map((result) => result.participantId),
        <String>['player', 'ai-0', 'ai-1'],
      );
      expect(
        session.finishResults.map((result) => result.result.finishPosition),
        <int>[1, 2, 3],
      );
      expect(session.playerPosition, 1);
      expect(session.participantPositions['ai-0'], 2);
      expect(session.participantPositions['ai-1'], 3);
      expect(session.playerResult!.competitorCount, 3);
      expect(
        session.results.keys,
        containsAll(<String>['player', 'ai-0', 'ai-1']),
      );

      expect(
        session
            .advance(
              frameDeltaSeconds: CarPhysics.fixedDeltaSeconds,
              playerInput: PlayerInput.none,
            )
            .physicalSteps,
        0,
      );
    },
  );

  test('AI sees the ordered obstacles and can restore its safe state', () {
    final driver = _RecordingAiDriver(requestRespawn: true);
    final session = _session(aiCount: 1, driver: driver);
    _startRacing(session);
    final opponent = session.opponents.single;
    opponent.carState
      ..x = 40
      ..y = 40
      ..longitudinalSpeed = 4
      ..velocityX = 4;
    session.advance(
      frameDeltaSeconds: CarPhysics.fixedDeltaSeconds,
      playerInput: PlayerInput.none,
    );
    opponent.carState
      ..x = 5
      ..y = 5
      ..lateralSpeed = 8
      ..driftAmount = 0.75;
    opponent.surfaceSpeedState.speedMultiplier = 0.3;

    session.advance(
      frameDeltaSeconds: CarPhysics.fixedDeltaSeconds,
      playerInput: PlayerInput.none,
    );

    expect(driver.contexts, hasLength(2));
    expect(driver.contexts.last.obstacles, hasLength(1));
    expect(opponent.carState.x, 40);
    expect(opponent.carState.y, 40);
    expect(opponent.carState.lateralSpeed, 0);
    expect(opponent.carState.driftAmount, 0);
    expect(opponent.surfaceSpeedState.speedMultiplier, 1);
    expect(opponent.progress.currentCheckpointIndex, 0);
    expect(driver.resetPositions.last, TrackPoint(40, 40));
  });

  test('AI driving against its route does not overwrite its safe state', () {
    final driver = _RecordingAiDriver(
      requestRespawn: false,
      facingRoute: false,
    );
    final session = _session(aiCount: 1, driver: driver);
    _startRacing(session);
    final opponent = session.opponents.single;
    final safeState = opponent.lastSafeState;
    opponent.carState
      ..x = 40
      ..y = 40
      ..longitudinalSpeed = 4
      ..velocityX = 4;

    session.advance(
      frameDeltaSeconds: CarPhysics.fixedDeltaSeconds,
      playerInput: PlayerInput.none,
    );

    expect(opponent.lastSafeState, safeState);
  });

  test('synchronizes injected finish order during construction', () {
    final player = _participant('player', 50.9, 50);
    player.progress.currentCheckpointIndex = 2;
    player.carState
      ..longitudinalSpeed = 24
      ..velocityX = 24;
    final finishedOpponent = _participant('ai-0', 10, 60);
    finishedOpponent.progress
      ..finished = true
      ..finishPosition = 2;
    final session = RaceSession(
      track: _track(),
      participants: <RaceParticipant>[finishedOpponent, player],
      requiredLaps: 1,
      playerId: 'player',
    );

    _startRacing(session);
    session.advance(
      frameDeltaSeconds: CarPhysics.fixedDeltaSeconds,
      playerInput: PlayerInput.none,
    );

    expect(session.playerResult!.finishPosition, 3);
  });
}

RaceSession _session({
  int requiredLaps = 3,
  int aiCount = 0,
  AiDriver? driver,
}) {
  final participants = <RaceParticipant>[
    _participant('player', 10, 50),
    for (var index = 0; index < aiCount; index++)
      _participant('ai-$index', 10, 60 + index * 10, aiDriver: driver),
  ];
  return RaceSession(
    track: _track(),
    participants: participants,
    requiredLaps: requiredLaps,
  );
}

RaceParticipant _participant(
  String id,
  double x,
  double y, {
  AiDriver? aiDriver,
}) => RaceParticipant(
  id: id,
  carState: CarState(x: x, y: y),
  carConfig: CarConfig(),
  aiDriver: aiDriver,
);

void _startRacing(RaceSession session) {
  session.start();
  session.advance(
    frameDeltaSeconds: session.raceState.countdownDurationSeconds,
    playerInput: PlayerInput.none,
  );
}

Track _track() {
  final bounds = TrackRectangle(0, 0, 100, 100);
  return Track.fromDefinition(
    id: 'race-session-test',
    name: 'RACE SESSION TEST',
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
      Checkpoint(
        order: 1,
        gate: TrackSegment(TrackPoint(35, 40), TrackPoint(35, 60)),
        forwardX: 1,
        forwardY: 0,
      ),
    ],
    startGrid: <StartGridPosition>[
      StartGridPosition(position: TrackPoint(10, 50), rotationDegrees: 0),
    ],
    racingLine: <TrackPoint>[
      TrackPoint(10, 50),
      TrackPoint(20, 50),
      TrackPoint(50, 50),
    ],
  );
}

final class _RecordingAiDriver
    implements AiDriver, ResettableAiDriver, RouteAwareAiDriver {
  _RecordingAiDriver({required this.requestRespawn, this.facingRoute = true});

  final bool requestRespawn;
  final bool facingRoute;
  final List<AiRaceContext> contexts = <AiRaceContext>[];
  final List<TrackPoint> resetPositions = <TrackPoint>[];

  @override
  bool isFacingRoute(CarState carState) => facingRoute;

  @override
  void reset(TrackPoint restoredPosition) {
    resetPositions.add(restoredPosition);
  }

  @override
  AiDriverDecision update({
    required CarState carState,
    required double deltaSeconds,
    required AiRaceContext context,
  }) {
    contexts.add(context);
    return AiDriverDecision(
      input: PlayerInput.none,
      requestRespawn: requestRespawn,
    );
  }
}

final class _LegacyAiDriver implements AiDriver {
  @override
  AiDriverDecision update({
    required CarState carState,
    required double deltaSeconds,
    required AiRaceContext context,
  }) => AiDriverDecision(input: PlayerInput.none);
}
