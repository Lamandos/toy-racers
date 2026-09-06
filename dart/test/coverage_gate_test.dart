import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/coverage_gate.dart';

void main() {
  test('requires 95 percent line coverage for every critical module', () {
    const lcov = '''
SF:lib/simulation/ai/ai_driver.dart
DA:1,1,checksum
DA:2,1
DA:3,1
DA:4,1
DA:5,1
DA:6,1
DA:7,1
DA:8,1
DA:9,1
DA:10,1
DA:11,1
DA:12,1
DA:13,1
DA:14,1
DA:15,1
DA:16,1
DA:17,1
DA:18,1
DA:19,1
DA:20,0
SF:lib/simulation/car/car_physics.dart
DA:1,1
SF:lib/simulation/collision/collision_system.dart
DA:1,1
SF:lib/simulation/race/race_rules.dart
DA:1,1
SF:lib/game/toy_racers_game.dart
DA:1,0
''';

    final report = const DartSimulationCoverageGate().evaluate(lcov);

    expect(report.passed, isTrue);
    expect(report.modules['ai']!.percentText, '95.00%');
    expect(report.modules['car']!.foundLines, 1);
  });

  test('rejects missing coverage and malformed LCOV records', () {
    const insufficientCoverage = '''
SF:lib/simulation/ai/ai_driver.dart
DA:1,1
DA:2,0
SF:lib/simulation/car/car_physics.dart
DA:1,1
SF:lib/simulation/collision/collision_system.dart
DA:1,1
SF:lib/simulation/race/race_rules.dart
DA:1,1
''';

    final report = const DartSimulationCoverageGate().evaluate(
      insufficientCoverage,
    );

    expect(report.passed, isFalse);
    expect(report.format(), contains('ai: 1 / 2 (50.00%) FAIL'));
    expect(
      () => const DartSimulationCoverageGate().evaluate(
        'SF:lib/simulation/ai/ai_driver.dart\nDA:not-a-number',
      ),
      throwsFormatException,
    );
  });

  test('returns a process status for a saved LCOV report', () {
    final directory = Directory.systemTemp.createTempSync('toy-racers-lcov-');
    final report = File('${directory.path}/lcov.info');
    try {
      report.writeAsStringSync(_passingLcov);

      expect(executeDartCoverageGate(<String>['--lcov', report.path]), 0);
    } finally {
      directory.deleteSync(recursive: true);
    }
  });
}

const String _passingLcov = '''
SF:lib/simulation/ai/ai_driver.dart
DA:1,1
SF:lib/simulation/car/car_physics.dart
DA:1,1
SF:lib/simulation/collision/collision_system.dart
DA:1,1
SF:lib/simulation/race/race_rules.dart
DA:1,1
''';
