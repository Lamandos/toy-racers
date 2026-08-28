import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/simulation.dart';

import '../tool/behavior_runner.dart';

void main() {
  group('AI compatibility scenarios', () {
    for (final scenario in _scenarioNames) {
      test(
        scenario,
        () => _expectGoldenTrace(scenario),
        timeout: const Timeout(Duration(minutes: 10)),
      );
    }

    test('scenario seed does not alter Kotlin-compatible AI decisions', () {
      final source = File(
        '../compatibility/scenarios/ai/deterministic_steering.json',
      ).readAsStringSync();
      final original = _parseScenario(source);
      final reseeded = _parseScenario(source.replaceFirst('11002', '99999'));

      final originalTrace = _traceFor(original);
      final reseededTrace = _traceFor(reseeded);

      expect(originalTrace['seed'], isNot(reseededTrace['seed']));
      expect(originalTrace['samples'], reseededTrace['samples']);
    });
  });
}

void _expectGoldenTrace(String scenario) {
  final actual = _trace('scenarios/ai/$scenario.json');
  final golden = _json('../compatibility/golden/ai/$scenario.json');
  final mismatch = _firstMismatch(golden, actual);

  expect(mismatch, isNull);
}

Object? _trace(String scenarioPath) => jsonDecode(
  CompatibilityTraceJson.encode(
    BehaviorRunner().run(File('../compatibility/$scenarioPath')),
  ),
);

CompatibilityScenario _parseScenario(String source) =>
    const CompatibilityScenarioParser()
        .parseScenarioDocument(
          source,
          inputScriptSource: (_) =>
              throw StateError('No input script expected.'),
        )
        .scenarios
        .single;

Map<String, dynamic> _traceFor(CompatibilityScenario scenario) =>
    jsonDecode(CompatibilityTraceJson.encode(BehaviorRunner().replay(scenario)))
        as Map<String, dynamic>;

Object? _json(String path) => jsonDecode(File(path).readAsStringSync());

String? _firstMismatch(Object? expected, Object? actual, [String path = r'$']) {
  if (expected is Map<Object?, Object?> && actual is Map<Object?, Object?>) {
    if (expected.keys.toSet().length != actual.keys.toSet().length ||
        !expected.keys.toSet().containsAll(actual.keys)) {
      return '$path contains different fields';
    }
    for (final entry in expected.entries) {
      final mismatch = _firstMismatch(
        entry.value,
        actual[entry.key],
        '$path.${entry.key}',
      );
      if (mismatch != null) {
        return mismatch;
      }
    }
    return null;
  }
  if (expected is List<Object?> && actual is List<Object?>) {
    if (expected.length != actual.length) {
      return '$path has ${actual.length} values, expected ${expected.length}';
    }
    for (var index = 0; index < expected.length; index++) {
      final mismatch = _firstMismatch(
        expected[index],
        actual[index],
        '$path[$index]',
      );
      if (mismatch != null) {
        return mismatch;
      }
    }
    return null;
  }
  if (expected is int) {
    return actual is int && expected == actual
        ? null
        : '$path is $actual, expected $expected';
  }
  if (expected is num) {
    if (actual is! num || !expected.isFinite || !actual.isFinite) {
      return '$path must contain finite numbers';
    }
    return (expected - actual).abs() <= _absoluteTolerance
        ? null
        : '$path is $actual, expected $expected';
  }
  return expected == actual ? null : '$path is $actual, expected $expected';
}

const double _absoluteTolerance = 0.0001;

const List<String> _scenarioNames = <String>[
  'deterministic_steering',
  'extended_multicar',
  'follows_racing_path',
  'obstacle_reaction',
  'obstacle_reaction_control',
  'recovery',
  'recovery_checkpoint_progress',
];
