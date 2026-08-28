import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/simulation.dart';

import '../tool/behavior_runner.dart';

void main() {
  test(
    'replays script input, samples events, and emits canonical trace JSON',
    () {
      final fixture = Directory.systemTemp.createTempSync('toy-racers-runner-');
      final simulation = _RecordingSimulation();
      try {
        final scenario = File('${fixture.path}/scenario.json')
          ..writeAsStringSync(_scriptScenario);
        File('${fixture.path}/commands.json').writeAsStringSync(_inputScript);

        final trace = BehaviorRunner(simulationFactory: (_) => simulation)
            .run(scenario);

        expect(simulation.initialStateIds, <String>['player']);
        expect(simulation.inputs.map((input) => input.steering), <double>[
          0.75,
          1,
          0.75,
        ]);
        expect(
          trace.samples.map((sample) => '${sample.label}:${sample.tick}'),
          <String>[
            'countdown:0',
            'racing:0',
            'simulation:1',
            'simulation:2',
            'checkpoint:2',
            'lap:2',
            'finish:2',
            'simulation:3',
          ],
        );
        expect(CompatibilityTraceJson.encode(trace), contains('"seed":-42'));
      } finally {
        fixture.deleteSync(recursive: true);
      }
    },
  );

  test('runs the command through Dart without a Flutter engine', () async {
    final fixture = Directory.systemTemp.createTempSync(
      'toy-racers-runner-cli-',
    );
    try {
      final output = File('${fixture.path}/actual.json');
      final result = await Process.run('dart', <String>[
        'run',
        'tool/behavior_runner.dart',
        '--scenario',
        File('../compatibility/scenarios/car/straight_acceleration.json')
            .absolute
            .path,
        '--output',
        output.path,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      final trace =
          jsonDecode(output.readAsStringSync()) as Map<String, dynamic>;
      expect(trace['schemaVersion'], 3);
      expect(trace['scenarioId'], 'straight-acceleration');
      expect(trace['samples'], isA<List<dynamic>>());
      expect(output.readAsStringSync(), isNot(contains('-0.000000')));
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test(
    'emits the required state-machine lifecycle samples at trace tick zero',
    () {
      const parser = CompatibilityScenarioParser();
      final scenario = parser
          .parseScenarioDocument(
            _stateMachineScenario,
            inputScriptSource: (_) =>
                throw StateError('No script is expected.'),
          )
          .scenarios
          .single;

      final trace = BehaviorRunner(
        simulationFactory: (_) => _RecordingSimulation(),
      ).replay(scenario);

      expect(
        trace.samples.map((sample) => '${sample.label}:${sample.tick}'),
        <String>[
          'loading:0',
          'ready:0',
          'countdown:0',
          'countdown:0',
          'countdown:0',
          'countdown:0',
          'racing:0',
          'simulation:1',
        ],
      );
      expect(
        trace.samples[5].snapshot.countdown.remainingSeconds,
        closeTo(59 / 60, 0.000001),
      );
    },
  );

  test(
    'returns a non-zero exit code for invalid command-line options',
    () async {
      final result = await Process.run('dart', <String>[
        'run',
        'tool/behavior_runner.dart',
        '--scenario',
        '../compatibility/scenarios/car/straight_acceleration.json',
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, isNonZero);
      expect(result.stderr, contains('Behavior runner failed:'));
    },
  );

  test('forces a simulation sample only on the first finished tick', () {
    const parser = CompatibilityScenarioParser();
    final scenario = parser
        .parseScenarioDocument(
          _finishSamplingScenario,
          inputScriptSource: (_) => throw StateError('No script is expected.'),
        )
        .scenarios
        .single;

    final trace = BehaviorRunner(
      simulationFactory: (_) => _RecordingSimulation(),
    ).replay(scenario);

    expect(
      trace.samples
          .where((sample) => sample.label == 'simulation')
          .map((sample) => sample.tick),
      <int>[1, 2, 4, 5],
    );
  });
}

final class _RecordingSimulation implements BehaviorSimulation {
  final List<DriverInput> inputs = <DriverInput>[];
  final List<String> initialStateIds = <String>[];
  String _phase = 'loading';
  double _countdownRemainingSeconds = 3;
  int _simulationTick = 0;

  @override
  PlayerInput get lastAppliedPlayerInput =>
      inputs.isEmpty ? PlayerInput.none : inputs.last;

  @override
  CompatibilitySnapshot get snapshot => _createSnapshot();

  @override
  void applyInitialStates(List<CompatibilityInitialState> states) {
    initialStateIds.addAll(states.map((state) => state.id));
  }

  @override
  CompatibilitySnapshot start() {
    _phase = 'countdown';
    _countdownRemainingSeconds = 3;
    return snapshot;
  }

  @override
  CompatibilitySnapshot markReadyForLifecycle() {
    _phase = 'ready';
    return snapshot;
  }

  @override
  CompatibilitySnapshot startCountdownForLifecycle() => start();

  @override
  CompatibilitySnapshot advanceCountdown(double deltaSeconds) {
    _countdownRemainingSeconds -= deltaSeconds;
    if (_countdownRemainingSeconds <= 0) {
      _countdownRemainingSeconds = 0;
      _phase = 'racing';
    }
    return snapshot;
  }

  @override
  CompatibilitySnapshot finishCountdown() =>
      advanceCountdown(_countdownRemainingSeconds);

  @override
  CompatibilitySnapshot advance({
    required DriverInput input,
    required double deltaSeconds,
  }) {
    inputs.add(input);
    if (_phase == 'racing') {
      _simulationTick += 1;
      if (_simulationTick == 2) {
        _phase = 'finished';
      }
    }
    return snapshot;
  }

  CompatibilitySnapshot _createSnapshot() {
    final isFinished = _phase == 'finished';
    final checkpoint = isFinished ? 1 : 0;
    final lap = isFinished ? 1 : 0;
    return CompatibilitySnapshot(
      simulationTick: _simulationTick,
      raceState: _phase,
      countdown: CompatibilityCountdown(
        state: _countdownState,
        remainingSeconds: _countdownRemainingSeconds,
      ),
      elapsedSimulationTime: _simulationTick * fixedBehaviorTimestep,
      currentLap: lap + 1,
      currentProgress: CompatibilityProgress(
        checkpoint: checkpoint,
        completedLaps: lap,
      ),
      participants: <CompatibilityParticipantSnapshot>[
        CompatibilityParticipantSnapshot(
          id: 'player',
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
          checkpoint: checkpoint,
          lap: lap,
          racePosition: 1,
          finished: isFinished,
        ),
      ],
      ranking: const <String>['player'],
      finishedParticipants: isFinished
          ? const <String>['player']
          : const <String>[],
      finishResults: isFinished
          ? <CompatibilityFinishResult>[
              CompatibilityFinishResult(
                participantId: 'player',
                finishPosition: 1,
                elapsedSimulationTime: _simulationTick * fixedBehaviorTimestep,
                bestLapTime: null,
              ),
            ]
          : const <CompatibilityFinishResult>[],
    );
  }

  String get _countdownState => switch (_phase) {
    'loading' || 'ready' => 'not-started',
    'countdown' => 'active',
    _ => 'complete',
  };
}

const String _inputScript =
    '''{"schemaVersion":1,"segments":[{"fromTick":1,"toTick":3,"steering":0.75}]}''';

const String _scriptScenario = '''
{"schemaVersion":2,"scenarios":[{
  "id":"runner-script",
  "seed":-42,
  "trackId":"track-01",
  "playerCar":"red-stripe",
  "inputOrigin":"keyboard",
  "tags":["event-snapshots"],
  "ticks":3,
  "snapshotIntervalTicks":3,
  "inputScript":"commands.json",
  "inputTweaks":[{"tick":2,"steeringDelta":0.5}],
  "initialStates":[{"id":"player","x":4}]
}]}''';

const String _stateMachineScenario = '''
{"schemaVersion":1,"scenarios":[{
  "id":"runner-state-machine",
  "seed":0,
  "trackId":"track-01",
  "playerCar":"red-stripe",
  "inputOrigin":"keyboard",
  "tags":["state-machine"],
  "ticks":1,
  "snapshotIntervalTicks":1,
  "inputSegments":[{"fromTick":1,"toTick":1}]
}]}''';

const String _finishSamplingScenario = '''
{"schemaVersion":1,"scenarios":[{
  "id":"runner-finish-sampling",
  "seed":0,
  "trackId":"track-01",
  "playerCar":"red-stripe",
  "inputOrigin":"keyboard",
  "tags":[],
  "ticks":5,
  "snapshotIntervalTicks":4,
  "inputSegments":[{"fromTick":1,"toTick":5}]
}]}''';
