import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/full_behavioral_gate.dart';

void main() {
  test('discovers the complete current compatibility inventory', () {
    final expectedOutput = Directory.systemTemp.createTempSync(
      'toy-racers-full-gate-test-',
    );
    try {
      final inventory = BehavioralInventory.load(
        Directory('..').absolute,
        expectedOutput,
      );

      expect(inventory.fixtures, hasLength(113));
      expect(
        inventory.fixtures.where((fixture) => fixture.category == 'legacy'),
        hasLength(50),
      );
      expect(_categoryCounts(inventory), <String, int>{
        'ai': 7,
        'car': 17,
        'collision': 11,
        'full_race': 10,
        'race': 4,
        'surface': 5,
        'track': 9,
      });
      expect(
        inventory.fixtures.map((fixture) => fixture.label),
        isNot(contains('full_race/full-race-input.json')),
      );
    } finally {
      expectedOutput.deleteSync(recursive: true);
    }
  });

  test('reports every required category after a successful inventory run', () {
    final expectedOutput = Directory.systemTemp.createTempSync(
      'toy-racers-full-gate-report-test-',
    );
    try {
      final fixtures = BehavioralInventory.load(
        Directory('..').absolute,
        expectedOutput,
      ).fixtures;
      final report = BehavioralGateReport(
        results: fixtures
            .map((fixture) => BehavioralFixtureResult(fixture: fixture))
            .toList(),
        unexpectedGoldenChanges: const <String>[],
      );

      expect(report.format(), '''Dart behavioral compatibility:
Passed: ALL
Failed: 0
Skipped: 0
Unexpected golden changes: 0
113 / 113 PASS
car PASS.
collision PASS.
race PASS.
track PASS.
surface PASS.
AI PASS.
full_race PASS.''');
    } finally {
      expectedOutput.deleteSync(recursive: true);
    }
  });
}

Map<String, int> _categoryCounts(BehavioralInventory inventory) {
  final counts = <String, int>{};
  for (final fixture in inventory.fixtures) {
    if (fixture.category == 'legacy') {
      continue;
    }
    counts.update(fixture.category, (count) => count + 1, ifAbsent: () => 1);
  }
  return counts;
}
