import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/differential_fuzz_runner.dart';

void main() {
  test('writes a canonical Dart trace for a materialized fuzz scenario', () {
    final fixture = Directory.systemTemp.createTempSync(
      'toy-racers-differential-fuzz-runner-',
    );
    try {
      final output = File('${fixture.path}/dart.json');
      final status = executeDifferentialFuzzRunner(<String>[
        '--scenario',
        File('../compatibility/scenarios/car/idle.json').absolute.path,
        '--output',
        output.path,
      ]);

      expect(status, 0);
      expect(output.existsSync(), isTrue);
      final trace =
          jsonDecode(output.readAsStringSync()) as Map<String, dynamic>;
      expect(trace['schemaVersion'], 3);
      expect(trace['scenarioId'], 'idle');
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test('rejects malformed trace request pairs', () {
    expect(
      executeDifferentialFuzzRunner(<String>['--scenario', 'scenario.json']),
      1,
    );
  });
}
