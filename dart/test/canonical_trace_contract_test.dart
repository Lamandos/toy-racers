import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  test('generates canonical snapshot arrays, numbers, and rotations', () {
    final simulation = createCompatibilitySimulation(_scenario());
    simulation.applyInitialStates(<CompatibilityInitialState>[
      const CompatibilityInitialState(
        id: 'ai-0',
        finished: true,
        finishPosition: 2,
      ),
      const CompatibilityInitialState(
        id: 'ai-1',
        finished: true,
        finishPosition: 1,
      ),
      const CompatibilityInitialState(
        id: 'player',
        rotationDeg: -720,
        velocityX: -0.0,
      ),
    ]);

    final snapshot = simulation.snapshot;
    final encoded = CompatibilityTraceJson.encodeSnapshot(snapshot);

    expect(snapshot.participants.map((participant) => participant.id), <String>[
      'ai-0',
      'ai-1',
      'ai-2',
      'ai-3',
      'ai-4',
      'player',
    ]);
    expect(snapshot.ranking.take(2), <String>['ai-1', 'ai-0']);
    expect(snapshot.finishedParticipants, <String>['ai-1', 'ai-0']);
    expect(
      snapshot.finishResults.map((result) => result.participantId),
      <String>['ai-1', 'ai-0'],
    );
    expect(
      snapshot.participants
          .singleWhere((participant) => participant.id == 'player')
          .rotation,
      0,
    );
    expect(encoded, isNot(contains('-0.000000')));
    expect(encoded, contains('"rotation":0.000000'));
    _expectSixDecimalNumbers(encoded);
  });

  test('accepts canonical lifecycle, simulation, and event ordering', () {
    final trace = CompatibilityTrace(
      scenarioId: 'canonical-order',
      seed: '0',
      samples: <CompatibilityTraceSample>[
        _sample(
          'loading',
          0,
          raceState: 'loading',
          countdownState: 'not-started',
        ),
        _sample('ready', 0, raceState: 'ready', countdownState: 'not-started'),
        _sample(
          'countdown',
          0,
          raceState: 'countdown',
          countdownState: 'active',
        ),
        _sample('racing', 0),
        _sample('simulation', 1, simulationTick: 1),
        _sample('checkpoint', 1, simulationTick: 1),
        _sample('lap', 1, simulationTick: 1),
        _sample('finish', 1, simulationTick: 1),
        _sample('simulation', 2, simulationTick: 1, raceState: 'finished'),
      ],
    );

    expect(CompatibilityTraceJson.encode(trace), isNotEmpty);
  });

  test('rejects trace events that violate canonical ordering', () {
    final trace = CompatibilityTrace(
      scenarioId: 'reversed-events',
      seed: '0',
      samples: <CompatibilityTraceSample>[
        _sample(
          'countdown',
          0,
          raceState: 'countdown',
          countdownState: 'active',
        ),
        _sample('racing', 0),
        _sample('simulation', 1, simulationTick: 1),
        _sample('lap', 1, simulationTick: 1),
        _sample('checkpoint', 1, simulationTick: 1),
      ],
    );

    expect(
      () => CompatibilityTraceJson.encode(trace),
      throwsA(
        isA<CompatibilityFormatException>().having(
          (error) => error.path,
          'path',
          r'$.samples[4].label',
        ),
      ),
    );
  });

  test('rejects lifecycle events emitted after tick zero', () {
    final trace = CompatibilityTrace(
      scenarioId: 'late-lifecycle',
      seed: '0',
      samples: <CompatibilityTraceSample>[
        _sample(
          'countdown',
          0,
          raceState: 'countdown',
          countdownState: 'active',
        ),
        _sample('racing', 0),
        _sample('simulation', 1, simulationTick: 1),
        _sample('racing', 1, simulationTick: 1),
      ],
    );

    expect(
      () => CompatibilityTraceJson.encode(trace),
      throwsA(isA<CompatibilityFormatException>()),
    );
  });

  test('rejects every non-finite value before canonical serialization', () {
    for (final value in <double>[
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expect(
        () => CompatibilityTraceJson.encodeSnapshot(_snapshot(x: value)),
        throwsA(isA<CompatibilityFormatException>()),
      );
    }
  });
}

CompatibilityScenario _scenario() => CompatibilityScenario(
  schemaVersion: 3,
  id: 'canonical-snapshot',
  seed: '0',
  trackId: 'track-01',
  playerCar: 'red-stripe',
  inputOrigin: 'keyboard',
  tags: const <String>[],
  ticks: 1,
  snapshotIntervalTicks: 1,
  inputSegments: <CompatibilityInputSegment>[
    CompatibilityInputSegment(fromTick: 1, toTick: 1, input: PlayerInput.none),
  ],
  inputTweaks: const <CompatibilityInputTweak>[],
  initialStates: const <CompatibilityInitialState>[],
  fullRace: false,
);

CompatibilityTraceSample _sample(
  String label,
  int tick, {
  int simulationTick = 0,
  String raceState = 'racing',
  String countdownState = 'complete',
}) => CompatibilityTraceSample(
  label: label,
  tick: tick,
  snapshot: _snapshot(
    simulationTick: simulationTick,
    raceState: raceState,
    countdownState: countdownState,
  ),
);

CompatibilitySnapshot _snapshot({
  int simulationTick = 0,
  String raceState = 'racing',
  String countdownState = 'complete',
  double x = 0,
}) => CompatibilitySnapshot(
  simulationTick: simulationTick,
  raceState: raceState,
  countdown: CompatibilityCountdown(
    state: countdownState,
    remainingSeconds: countdownState == 'complete' ? 0 : 3,
  ),
  elapsedSimulationTime: simulationTick * Float32.fixedDeltaSeconds,
  currentLap: 1,
  currentProgress: const CompatibilityProgress(checkpoint: 0, completedLaps: 0),
  participants: <CompatibilityParticipantSnapshot>[
    CompatibilityParticipantSnapshot(
      id: 'player',
      surface: 'asphalt',
      x: x,
      y: 0,
      rotation: 0,
      velocityX: 0,
      velocityY: 0,
      angularVelocity: 0,
      longitudinalSpeed: 0,
      lateralSpeed: 0,
      driftAmount: 0,
      checkpoint: 0,
      lap: 0,
      racePosition: 1,
      finished: false,
    ),
  ],
  ranking: const <String>['player'],
  finishedParticipants: const <String>[],
  finishResults: const <CompatibilityFinishResult>[],
);

void _expectSixDecimalNumbers(String encoded) {
  final decimals = RegExp(r':(-?\d+\.\d+)').allMatches(encoded);

  for (final match in decimals) {
    expect(match.group(1), matches(RegExp(r'^-?\d+\.\d{6}$')));
  }
}
