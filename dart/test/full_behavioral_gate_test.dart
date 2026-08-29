import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/simulation.dart';

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

  test('rejects duplicate scenario IDs across file categories', () {
    final repositoryRoot = _createRepositoryFixture();
    final expectedOutput = Directory.systemTemp.createTempSync(
      'toy-racers-duplicate-id-test-',
    );
    try {
      _writeScenario(repositoryRoot, 'car/first.json', 'duplicate-id');
      _writeScenario(repositoryRoot, 'collision/second.json', 'duplicate-id');

      expect(
        () => BehavioralInventory.load(repositoryRoot, expectedOutput),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('duplicate-id'),
          ),
        ),
      );
    } finally {
      repositoryRoot.deleteSync(recursive: true);
      expectedOutput.deleteSync(recursive: true);
    }
  });

  test('rejects an unsupported legacy golden schema version', () {
    final repositoryRoot = _createRepositoryFixture(
      legacyGoldenSchemaVersion: 2,
    );
    final expectedOutput = Directory.systemTemp.createTempSync(
      'toy-racers-golden-schema-test-',
    );
    try {
      expect(
        () => BehavioralInventory.load(repositoryRoot, expectedOutput),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('Unsupported golden schema version'),
          ),
        ),
      );
    } finally {
      repositoryRoot.deleteSync(recursive: true);
      expectedOutput.deleteSync(recursive: true);
    }
  });

  test('rejects scenario filenames outside the snake_case contract', () {
    final repositoryRoot = _createRepositoryFixture();
    final expectedOutput = Directory.systemTemp.createTempSync(
      'toy-racers-scenario-filename-test-',
    );
    try {
      _writeScenario(
        repositoryRoot,
        'car/straight-acceleration.json',
        'valid-scenario-id',
      );

      expect(
        () => BehavioralInventory.load(repositoryRoot, expectedOutput),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('snake_case'),
          ),
        ),
      );
    } finally {
      repositoryRoot.deleteSync(recursive: true);
      expectedOutput.deleteSync(recursive: true);
    }
  });

  test('rejects duplicate fields in legacy golden documents', () {
    final repositoryRoot = _createRepositoryFixture();
    final expectedOutput = Directory.systemTemp.createTempSync(
      'toy-racers-duplicate-field-test-',
    );
    try {
      File('${repositoryRoot.path}/core/src/test/resources/compat/goldens.json')
          .writeAsStringSync(
            '{"schemaVersion":3,"traces":{"legacy-example":'
            '{"samples":[],"samples":[]}}}',
          );

      expect(
        () => BehavioralInventory.load(repositoryRoot, expectedOutput),
        throwsA(
          isA<CompatibilityFormatException>().having(
            (error) => error.toString(),
            'message',
            contains('Duplicate object key'),
          ),
        ),
      );
    } finally {
      repositoryRoot.deleteSync(recursive: true);
      expectedOutput.deleteSync(recursive: true);
    }
  });

  test('includes legacy fixtures in tagged subsystem status', () {
    final expectedOutput = Directory.systemTemp.createTempSync(
      'toy-racers-legacy-status-test-',
    );
    try {
      final fixtures = BehavioralInventory.load(
        Directory('..').absolute,
        expectedOutput,
      ).fixtures;
      final results = fixtures.map((fixture) {
        final isLegacyCollision =
            fixture.category == BehavioralInventory.legacyCategory &&
            fixture.scenario.tags.contains('collision');
        return BehavioralFixtureResult(
          fixture: fixture,
          failure: isLegacyCollision ? 'synthetic collision failure' : null,
        );
      }).toList();
      final report = BehavioralGateReport(
        results: results,
        unexpectedGoldenChanges: const <String>[],
      );

      expect(report.passedAll, isFalse);
      expect(report.format(), contains('collision FAIL.'));
    } finally {
      expectedOutput.deleteSync(recursive: true);
    }
  });

  test('includes legacy full-race fixtures in full-race status', () {
    final expectedOutput = Directory.systemTemp.createTempSync(
      'toy-racers-legacy-full-race-status-test-',
    );
    try {
      final fixtures = BehavioralInventory.load(
        Directory('..').absolute,
        expectedOutput,
      ).fixtures;
      final results = fixtures.map((fixture) {
        final isLegacyFullRace =
            fixture.category == BehavioralInventory.legacyCategory &&
            fixture.scenario.fullRace;
        return BehavioralFixtureResult(
          fixture: fixture,
          failure: isLegacyFullRace ? 'synthetic full-race failure' : null,
        );
      }).toList();
      final report = BehavioralGateReport(
        results: results,
        unexpectedGoldenChanges: const <String>[],
      );

      expect(report.passedAll, isFalse);
      expect(report.format(), contains('full_race FAIL.'));
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

Directory _createRepositoryFixture({int legacyGoldenSchemaVersion = 3}) {
  final root = Directory.systemTemp.createTempSync(
    'toy-racers-inventory-fixture-',
  );
  Directory('${root.path}/compatibility/scenarios').createSync(recursive: true);
  Directory('${root.path}/compatibility/golden').createSync(recursive: true);
  final legacyDirectory = Directory(
    '${root.path}/core/src/test/resources/compat',
  )..createSync(recursive: true);
  File('${legacyDirectory.path}/scenarios.json')
      .writeAsStringSync(_scenarioDocument('legacy-example'));
  File('${legacyDirectory.path}/goldens.json').writeAsStringSync(
    '{"schemaVersion":$legacyGoldenSchemaVersion,"traces":{'
    '"legacy-example":{}}}',
  );
  return root;
}

void _writeScenario(Directory repositoryRoot, String path, String id) {
  final scenario = File('${repositoryRoot.path}/compatibility/scenarios/$path')
    ..createSync(recursive: true);
  scenario.writeAsStringSync(_scenarioDocument(id));
  final golden = File('${repositoryRoot.path}/compatibility/golden/$path')
    ..createSync(recursive: true);
  golden.writeAsStringSync('{}');
}

String _scenarioDocument(String id) =>
    '{"schemaVersion":1,"scenarios":[{"id":"$id",'
    '"seed":42,"trackId":"track-01","playerCar":"red-stripe",'
    '"inputOrigin":"keyboard","tags":["car"],"ticks":1,'
    '"snapshotIntervalTicks":1,"inputSegments":['
    '{"fromTick":1,"toTick":1}]}]}';
