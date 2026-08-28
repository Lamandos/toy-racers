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
  });

  test('position tracker keeps finish order ahead of running progress', () {
    final tracker = PositionTracker(_track());
    final positions = tracker.positions(<RaceCompetitor>[
      RaceCompetitor(
        id: 'running',
        progress: RaceProgress(completedLaps: 8, currentCheckpointIndex: 2),
        position: TrackPoint(20, 50),
      ),
      RaceCompetitor(
        id: 'second',
        progress: RaceProgress(finished: true, finishPosition: 2),
        position: TrackPoint(0, 0),
      ),
      RaceCompetitor(
        id: 'first',
        progress: RaceProgress(finished: true, finishPosition: 1),
        position: TrackPoint(0, 0),
      ),
    ]);

    expect(positions, <String, int>{'first': 1, 'second': 2, 'running': 3});
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

final class _RecordingAiDriver implements AiDriver {
  _RecordingAiDriver({required this.requestRespawn});

  final bool requestRespawn;
  final List<AiRaceContext> contexts = <AiRaceContext>[];

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
