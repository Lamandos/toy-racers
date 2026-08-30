import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/simulation.dart';

import '../tool/behavior_runner.dart';
import '../tool/stress_determinism_runner.dart';

void main() {
  test('writes the normalized output hash as an unsigned 64-bit value', () {
    expect(normalizedOutputHash('a'), 'af63dc4c8601ec8c');
  });

  test(
    'replays both stress fixtures with identical normalized Dart output',
    () {
      final output = Directory.systemTemp.createTempSync(
        'toy-racers-dart-stress-',
      );
      try {
        final report = StressDeterminismRunner(
          repeatCount: 2,
          behaviorRunner: BehaviorRunner(
            simulationFactory: (_) => _StressSimulation(),
          ),
        ).run(_requests(output));

        expect(report.scenariosPassed, 2);
        expect(report.normalizedHash, hasLength(16));
        expect(report.format(), contains('Dart determinism: 2 / 2 identical'));
        expect(
          File('${output.path}/dart-5000.json').readAsStringSync(),
          isNot(contains('-0.000000')),
        );
      } finally {
        output.deleteSync(recursive: true);
      }
    },
  );

  test('rejects numerical, ranking, and race-state stress corruption', () {
    final scenario = _loadShortScenario();
    final trace = BehaviorRunner(simulationFactory: (_) => _StressSimulation())
        .replay(scenario);
    final participant = trace.samples[2].snapshot.participants.first;
    final invalidTraces = <_InvalidTraceCase>[
      _InvalidTraceCase(
        'NaN',
        _withParticipant(trace, participant.copyWith(x: double.nan)),
      ),
      _InvalidTraceCase(
        'Infinity',
        _withParticipant(trace, participant.copyWith(x: double.infinity)),
      ),
      _InvalidTraceCase(
        'rotation',
        _withParticipant(trace, participant.copyWith(rotation: 360)),
      ),
      _InvalidTraceCase(
        'velocity',
        _withParticipant(trace, participant.copyWith(velocityX: 1000)),
      ),
      _InvalidTraceCase(
        'ranking',
        _withSnapshot(
          trace,
          ranking: trace.samples[2].snapshot.ranking.reversed.toList(),
        ),
      ),
      _InvalidTraceCase(
        'race state',
        _withSnapshot(trace, raceState: 'finished'),
      ),
    ];

    for (final invalid in invalidTraces) {
      expect(
        () => StressTraceValidator.validate(invalid.trace, scenario),
        throwsA(isA<StateError>()),
        reason: invalid.description,
      );
    }
  });
}

List<StressTraceRequest> _requests(Directory output) => <StressTraceRequest>[
  StressTraceRequest(
    scenario: File(
      '../core/src/test/resources/compat/stress/long_running_1000.json',
    ),
    output: File('${output.path}/dart-1000.json'),
  ),
  StressTraceRequest(
    scenario: File(
      '../core/src/test/resources/compat/stress/long_running_5000.json',
    ),
    output: File('${output.path}/dart-5000.json'),
  ),
];

CompatibilityScenario _loadShortScenario() {
  final scenarioFile = File(
    '../core/src/test/resources/compat/stress/long_running_1000.json',
  );
  return const CompatibilityScenarioParser()
      .parseScenarioDocument(
        scenarioFile.readAsStringSync(),
        inputScriptSource: (_) => throw StateError('No script is expected.'),
      )
      .scenarios
      .single;
}

CompatibilityTrace _withParticipant(
  CompatibilityTrace trace,
  CompatibilityParticipantSnapshot participant,
) {
  final snapshot = trace.samples[2].snapshot;
  return _withSnapshot(
    trace,
    participants: <CompatibilityParticipantSnapshot>[
      participant,
      ...snapshot.participants.skip(1),
    ],
  );
}

CompatibilityTrace _withSnapshot(
  CompatibilityTrace trace, {
  List<CompatibilityParticipantSnapshot>? participants,
  List<String>? ranking,
  String? raceState,
}) {
  final samples = List<CompatibilityTraceSample>.of(trace.samples);
  final snapshot = samples[2].snapshot;
  samples[2] = CompatibilityTraceSample(
    label: samples[2].label,
    tick: samples[2].tick,
    snapshot: CompatibilitySnapshot(
      simulationTick: snapshot.simulationTick,
      raceState: raceState ?? snapshot.raceState,
      countdown: snapshot.countdown,
      elapsedSimulationTime: snapshot.elapsedSimulationTime,
      currentLap: snapshot.currentLap,
      currentProgress: snapshot.currentProgress,
      participants: participants ?? snapshot.participants,
      ranking: ranking ?? snapshot.ranking,
      finishedParticipants: snapshot.finishedParticipants,
      finishResults: snapshot.finishResults,
    ),
  );
  return CompatibilityTrace(
    scenarioId: trace.scenarioId,
    seed: trace.seed,
    samples: samples,
  );
}

final class _InvalidTraceCase {
  const _InvalidTraceCase(this.description, this.trace);

  final String description;
  final CompatibilityTrace trace;
}

final class _StressSimulation implements BehaviorSimulation {
  var _phase = 'loading';
  var _simulationTick = 0;

  @override
  PlayerInput get lastAppliedPlayerInput => PlayerInput.none;

  @override
  CompatibilitySnapshot get snapshot => CompatibilitySnapshot(
    simulationTick: _simulationTick,
    raceState: _phase,
    countdown: CompatibilityCountdown(
      state: _phase == 'countdown' ? 'active' : 'complete',
      remainingSeconds: _phase == 'countdown' ? 3 : 0,
    ),
    elapsedSimulationTime: Float32.elapsedSimulationTime(_simulationTick),
    currentLap: 1,
    currentProgress: const CompatibilityProgress(
      checkpoint: 0,
      completedLaps: 0,
    ),
    participants: _participants,
    ranking: _participantIds,
    finishedParticipants: const <String>[],
    finishResults: const <CompatibilityFinishResult>[],
  );

  @override
  void applyInitialStates(List<CompatibilityInitialState> states) {}

  @override
  CompatibilitySnapshot advance({
    required DriverInput input,
    required double deltaSeconds,
  }) {
    _simulationTick++;
    return snapshot;
  }

  @override
  CompatibilitySnapshot advanceCountdown(double deltaSeconds) => snapshot;

  @override
  CompatibilitySnapshot finishCountdown() {
    _phase = 'racing';
    return snapshot;
  }

  @override
  CompatibilitySnapshot markReadyForLifecycle() => snapshot;

  @override
  CompatibilitySnapshot startCountdownForLifecycle() => start();

  @override
  CompatibilitySnapshot start() {
    _phase = 'countdown';
    return snapshot;
  }
}

extension on CompatibilityParticipantSnapshot {
  CompatibilityParticipantSnapshot copyWith({
    double? x,
    double? rotation,
    double? velocityX,
  }) => CompatibilityParticipantSnapshot(
    id: id,
    surface: surface,
    x: x ?? this.x,
    y: y,
    rotation: rotation ?? this.rotation,
    velocityX: velocityX ?? this.velocityX,
    velocityY: velocityY,
    angularVelocity: angularVelocity,
    longitudinalSpeed: longitudinalSpeed,
    lateralSpeed: lateralSpeed,
    driftAmount: driftAmount,
    checkpoint: checkpoint,
    lap: lap,
    racePosition: racePosition,
    finished: finished,
  );
}

const List<String> _participantIds = <String>[
  'ai-0',
  'ai-1',
  'ai-2',
  'ai-3',
  'ai-4',
  'player',
];

final List<CompatibilityParticipantSnapshot> _participants =
    <CompatibilityParticipantSnapshot>[
      for (var index = 0; index < _participantIds.length; index++)
        CompatibilityParticipantSnapshot(
          id: _participantIds[index],
          surface: 'asphalt',
          x: 0,
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
          racePosition: index + 1,
          finished: false,
        ),
    ];
