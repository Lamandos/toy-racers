import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  const parser = CompatibilityScenarioParser();

  CompatibilityScenarioDocument parseScenario(
    String source, {
    Map<String, String> scripts = const <String, String>{},
  }) => parser.parseScenarioDocument(
    source,
    inputScriptSource: (filename) => scripts[filename]!,
  );

  test('parses every checked-in compatibility scenario without schema copies', () {
    final scenarioDirectory = Directory('../compatibility/scenarios');
    final files =
        scenarioDirectory
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.json'))
            .where(
              (file) =>
                  file.path.split(Platform.pathSeparator).last !=
                  'full-race-input.json',
            )
            .toList()
          ..sort((left, right) => left.path.compareTo(right.path));

    for (final file in files) {
      parseScenario(
        file.readAsStringSync(),
        scripts: <String, String>{
          'full-race-input.json':
              File(
                '${file.parent.path}${Platform.pathSeparator}full-race-input.json',
              ).existsSync()
              ? File(
                  '${file.parent.path}${Platform.pathSeparator}full-race-input.json',
                ).readAsStringSync()
              : '',
        },
      );
    }

    expect(files, hasLength(63));
  });

  test(
    'parses scenario versions and normalizes input only after a v2 tweak',
    () {
      final v1 = parseScenario(_scenarioDocument(version: 1));
      final v2 = parseScenario(
        _scenarioDocument(
          version: 2,
          input: '"inputScript":"commands.json","inputTweaks":[{"tick":2,"steeringDelta":0.5}]',
        ),
        scripts: <String, String>{
          'commands.json': '{"schemaVersion":1,"segments":[{"fromTick":1,"toTick":3,"steering":0.75}]}',
        },
      );
      final v3 = parseScenario(
        _scenarioDocument(
          version: 3,
          input:
              '"inputSegments":[{"fromTick":1,"toTick":3}],'
              '"initialStates":[{"id":"player","lapStartTime":1,"totalRaceTime":2,"bestLapTime":1}]',
        ),
      );

      expect(v1.scenarios.single.schemaVersion, 1);
      expect(v2.scenarios.single.inputForTick(2).steering, 1);
      expect(v3.scenarios.single.initialStates.single.lapStartTime, 1);
      expect(v3.scenarios.single.initialStates.single.bestLapTime, 1);
    },
  );

  test('rejects contract violations at the parsing boundary', () {
    final invalidDocuments = <String>[
      _scenarioDocument(version: 4),
      _scenarioDocument(version: 1)
          .replaceFirst('"playerCar":"red-stripe",', ''),
      _scenarioDocument(version: 1).replaceFirst('"track-01"', '"not-a-track"'),
      _scenarioDocument(
        version: 1,
        input: '"inputSegments":[{"fromTick":1,"toTick":4}]',
      ),
      _scenarioDocument(
        version: 1,
        input: '"inputSegments":[{"fromTick":1,"toTick":2},{"fromTick":2,"toTick":3}]',
      ),
      _scenarioDocument(version: 1)
          .replaceFirst('"tags":["car"]', '"tags":["car","car"]'),
      _scenarioDocument(version: 1)
          .replaceFirst('"seed":42', '"seed":9223372036854775808'),
      _scenarioDocument(version: 1)
          .replaceFirst('"throttle":1', '"throttle":1e999'),
      _scenarioDocument(version: 1)
          .replaceFirst('"throttle":1', '"throttle":NaN'),
      _scenarioDocument(version: 1)
          .replaceFirst('"throttle":1', '"throttle":Infinity'),
      _scenarioDocument(version: 1)
          .replaceFirst('"throttle":1', '"throttle":3.4028235e38'),
      _scenarioDocument(
        version: 2,
        input:
            '"inputSegments":[{"fromTick":1,"toTick":3}],'
            '"inputTweaks":[{"tick":1,"throttleDelta":3.4028235e38}]',
      ),
      _scenarioDocument(
        version: 3,
        input:
            '"inputSegments":[{"fromTick":1,"toTick":3}],'
            '"initialStates":[{"id":"player","x":3.4028235e38}]',
      ),
      _scenarioDocument(
        version: 3,
        input:
            '"inputSegments":[{"fromTick":1,"toTick":3}],'
            '"initialStates":[{"id":"player","lapStartTime":3.4028235e38}]',
      ),
      _scenarioDocument(version: 1)
          .replaceFirst('"id":"example"', '"id":"example","id":"again"'),
      _scenarioDocument(
        version: 3,
        input:
            '"inputSegments":[{"fromTick":1,"toTick":3}],'
            '"initialStates":[{"id":"player","finished":true,"finishPosition":1},'
            '{"id":"ai-0","finished":true,"finishPosition":1}]',
      ),
      _scenarioDocument(
        version: 3,
        input:
            '"inputSegments":[{"fromTick":1,"toTick":3}],'
            '"initialStates":[{"id":"player","lapStartTime":2,"totalRaceTime":1}]',
      ),
    ];

    for (final source in invalidDocuments) {
      expect(
        () => parseScenario(source),
        throwsA(isA<CompatibilityFormatException>()),
      );
    }
  });

  test('rejects malformed and overlapping input-script v1 documents', () {
    expect(
      () => parser.parseInputScriptDocument(
        '{"schemaVersion":2,"segments":[{"fromTick":1,"toTick":1}]}',
      ),
      throwsA(isA<CompatibilityFormatException>()),
    );
    expect(
      () => parser.parseInputScriptDocument(
        '{"schemaVersion":1,"segments":['
        '{"fromTick":1,"toTick":2},{"fromTick":2,"toTick":3}]}',
      ),
      throwsA(isA<CompatibilityFormatException>()),
    );
  });

  test('encodes canonical schema-v2 snapshots inside a schema-v3 trace', () {
    final snapshot = CompatibilitySnapshot(
      simulationTick: 1,
      raceState: 'racing',
      countdown: const CompatibilityCountdown(
        state: 'complete',
        remainingSeconds: -0.0,
      ),
      elapsedSimulationTime: 1 / 60,
      currentLap: 1,
      currentProgress: const CompatibilityProgress(
        checkpoint: 0,
        completedLaps: 0,
      ),
      participants: <CompatibilityParticipantSnapshot>[
        CompatibilityParticipantSnapshot(
          id: 'player',
          surface: 'asphalt',
          x: -1e-8,
          y: Float32.narrow(3.4028234663852886e38),
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
    final trace = CompatibilityTrace(
      scenarioId: 'maximum-seed',
      seed: '9223372036854775807',
      samples: <CompatibilityTraceSample>[
        CompatibilityTraceSample(
          label: 'simulation',
          tick: 1,
          snapshot: snapshot,
        ),
      ],
    );

    final encoded = CompatibilityTraceJson.encode(trace);

    expect(encoded, contains('"schemaVersion":3'));
    expect(encoded, contains('"seed":9223372036854775807'));
    expect(encoded, contains('"schemaVersion":2'));
    expect(encoded, contains('"elapsedSimulationTime":0.016667'));
    expect(
      encoded,
      contains('"y":340282346638528860000000000000000000000.000000'),
    );
    expect(encoded, isNot(contains('-0.000000')));
  });

  test('rejects snapshot rotations that narrow to 360 degrees', () {
    final snapshot = CompatibilitySnapshot(
      simulationTick: 0,
      raceState: 'loading',
      countdown: const CompatibilityCountdown(
        state: 'not-started',
        remainingSeconds: 0,
      ),
      elapsedSimulationTime: 0,
      currentLap: 1,
      currentProgress: const CompatibilityProgress(
        checkpoint: 0,
        completedLaps: 0,
      ),
      participants: const <CompatibilityParticipantSnapshot>[
        CompatibilityParticipantSnapshot(
          id: 'player',
          surface: 'asphalt',
          x: 0,
          y: 0,
          rotation: 359.99999,
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

    expect(
      () => CompatibilityTraceJson.encodeSnapshot(snapshot),
      throwsA(isA<CompatibilityFormatException>()),
    );
  });

  test('refuses non-finite snapshot output', () {
    final snapshot = CompatibilitySnapshot(
      simulationTick: 0,
      raceState: 'loading',
      countdown: const CompatibilityCountdown(
        state: 'not-started',
        remainingSeconds: 0,
      ),
      elapsedSimulationTime: double.nan,
      currentLap: 1,
      currentProgress: const CompatibilityProgress(
        checkpoint: 0,
        completedLaps: 0,
      ),
      participants: const <CompatibilityParticipantSnapshot>[
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

    expect(
      () => CompatibilityTraceJson.encodeSnapshot(snapshot),
      throwsA(isA<CompatibilityFormatException>()),
    );
  });
}

String _scenarioDocument({required int version, String? input}) =>
    '''
{"schemaVersion":$version,"scenarios":[{
  "id":"example",
  "seed":42,
  "trackId":"track-01",
  "playerCar":"red-stripe",
  "inputOrigin":"keyboard",
  "tags":["car"],
  "ticks":3,
  "snapshotIntervalTicks":1,
  ${input ?? '"inputSegments":[{"fromTick":1,"toTick":3,"throttle":1}]'}
}]}''';
