import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/dart_behavioral_stability.dart';

void main() {
  test('replays the complete inventory with identical normalized traces', () {
    const normalizedTrace = '{"schemaVersion":3,"samples":[]}';
    final report = DartBehavioralStabilityRunner(
      Directory('..').absolute,
      repeatCount: 2,
      replay: (inventory) => <String, String>{
        for (final fixture in inventory.fixtures)
          fixture.label: normalizedTrace,
      },
    ).run();

    expect(report.fixtureCount, 113);
    expect(
      report.format(),
      'Dart behavioral stability: 2 / 2 identical '
      '(113 fixtures each).',
    );
  });

  test('identifies the fixture and run that diverged', () {
    var invocation = 0;
    final runner = DartBehavioralStabilityRunner(
      Directory('..').absolute,
      repeatCount: 2,
      replay: (inventory) {
        invocation++;
        return <String, String>{
          for (final fixture in inventory.fixtures)
            fixture.label:
                invocation == 1 || fixture == inventory.fixtures.first
                ? 'baseline'
                : 'changed',
        };
      },
    );

    expect(
      runner.run,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('diverged on suite run 2'),
        ),
      ),
    );
  });

  test('requires at least two complete suite runs', () {
    final runner = DartBehavioralStabilityRunner(
      Directory('..').absolute,
      repeatCount: 1,
    );

    expect(runner.run, throwsArgumentError);
  });
}
