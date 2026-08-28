import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/simulation.dart';

import '../tool/behavior_runner.dart';

void main() {
  group('race compatibility scenarios', () {
    for (final scenario in _scenarioNames) {
      test('$scenario preserves race-owned golden state', () {
        final actual = _encodedTrace(
          '../compatibility/scenarios/race/$scenario.json',
        );
        final golden = _json('../compatibility/golden/race/$scenario.json');

        final actualSamples = actual['samples'] as List<dynamic>;
        final goldenSamples = golden['samples'] as List<dynamic>;
        expect(actualSamples, hasLength(goldenSamples.length));
        for (var index = 0; index < goldenSamples.length; index++) {
          final actualSample = actualSamples[index] as Map<String, dynamic>;
          final goldenSample = goldenSamples[index] as Map<String, dynamic>;
          expect(actualSample['label'], goldenSample['label']);
          expect(actualSample['tick'], goldenSample['tick']);
          _expectRaceState(
            actualSample['snapshot'] as Map<String, dynamic>,
            goldenSample['snapshot'] as Map<String, dynamic>,
          );
        }
      });
    }
  });
}

Map<String, dynamic> _encodedTrace(String scenarioPath) => jsonDecode(
  CompatibilityTraceJson.encode(BehaviorRunner().run(File(scenarioPath))),
) as Map<String, dynamic>;

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void _expectRaceState(
  Map<String, dynamic> actual,
  Map<String, dynamic> golden,
) {
  for (final field in _raceFields) {
    expect(actual[field], golden[field], reason: field);
  }
  expect(_player(actual), _player(golden), reason: 'player state');
  expect(actual['ranking'], golden['ranking'], reason: 'participant ranking');
  expect(
    actual['finishedParticipants'],
    golden['finishedParticipants'],
    reason: 'finish order',
  );
  expect(actual['finishResults'], golden['finishResults'], reason: 'results');
}

Map<String, dynamic> _player(Map<String, dynamic> snapshot) =>
    (snapshot['participants'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .singleWhere((participant) => participant['id'] == 'player');

const List<String> _raceFields = <String>[
  'raceState',
  'countdown',
  'simulationTick',
  'elapsedSimulationTime',
  'currentLap',
  'currentProgress',
];

const List<String> _scenarioNames = <String>[
  'checkpoint_progression',
  'final_lap_progression',
  'near_simultaneous_finish',
  'state_machine_lifecycle',
];
