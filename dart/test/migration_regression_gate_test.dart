import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/migration_regression_gate.dart';

void main() {
  test('runs focused unit tests and the complete compatibility inventory', () {
    final commands = <_Command>[];
    final gate = MigrationRegressionGate(
      MigrationSubsystem.named('car')!,
      commandRunner: (executable, arguments, workingDirectory) {
        commands.add(_Command(executable, arguments, workingDirectory));
        return GateCommandResult(
          exitCode: 0,
          stdout: executable == 'dart' ? 'car PASS.' : 'car unit tests pass',
        );
      },
      workingDirectory: Directory.current,
    );

    final report = gate.run();

    expect(report.passed, isTrue);
    expect(commands, hasLength(2));
    expect(commands[0].executable, 'flutter');
    expect(commands[0].arguments, <String>[
      'test',
      'test/car_physics_test.dart',
      'test/simulation_models_test.dart',
    ]);
    expect(commands[1].executable, 'dart');
    expect(commands[1].arguments, const <String>[
      'run',
      'tool/full_behavioral_gate.dart',
    ]);
    expect(
      report.format(),
      contains(
        'Protected compatibility categories: '
        'car, collision, race, track, surface, ai, full_race',
      ),
    );
  });

  test('reports the affected subsystem and compatibility failure', () {
    final gate = MigrationRegressionGate(
      MigrationSubsystem.named('collision')!,
      commandRunner: (executable, _, _) => GateCommandResult(
        exitCode: 1,
        stderr: executable == 'flutter'
            ? 'collision unit test failed'
            : 'collision FAIL.',
      ),
      workingDirectory: Directory.current,
    );

    final report = gate.run();

    expect(report.passed, isFalse);
    expect(
      report.format(),
      allOf(
        contains('Affected subsystem: collision'),
        contains('Dart unit tests for collision: FAIL'),
        contains('Full compatibility inventory: FAIL'),
        contains('collision FAIL.'),
        contains('Regression rule: FAIL'),
      ),
    );
  });

  test('rejects an unregistered subsystem before starting commands', () {
    var commands = 0;

    final status = executeMigrationRegressionGate(
      const <String>['--subsystem', 'audio'],
      commandRunner: (_, _, _) {
        commands++;
        return const GateCommandResult(exitCode: 0);
      },
    );

    expect(status, 1);
    expect(commands, 0);
  });
}

final class _Command {
  const _Command(this.executable, this.arguments, this.workingDirectory);

  final String executable;
  final List<String> arguments;
  final Directory workingDirectory;
}
