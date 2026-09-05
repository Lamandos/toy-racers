import 'dart:io';

/// One Dart subsystem whose compatibility category is protected after a pass.
final class MigrationSubsystem {
  const MigrationSubsystem({required this.name, required this.unitTests});

  final String name;
  final List<String> unitTests;

  static MigrationSubsystem? named(String name) {
    for (final subsystem in all) {
      if (subsystem.name == name) {
        return subsystem;
      }
    }
    return null;
  }

  /// Every category with checked-in Kotlin goldens is protected by this gate.
  static const List<MigrationSubsystem> all = <MigrationSubsystem>[
    MigrationSubsystem(
      name: 'car',
      unitTests: <String>[
        'test/car_physics_test.dart',
        'test/simulation_models_test.dart',
      ],
    ),
    MigrationSubsystem(
      name: 'collision',
      unitTests: <String>[
        'test/collision_edge_case_test.dart',
        'test/collision_public_api_test.dart',
        'test/collision_scenarios_test.dart',
      ],
    ),
    MigrationSubsystem(
      name: 'race',
      unitTests: <String>[
        'test/position_tracker_test.dart',
        'test/race_compatibility_scenarios_test.dart',
        'test/race_rules_test.dart',
        'test/race_session_test.dart',
      ],
    ),
    MigrationSubsystem(
      name: 'track',
      unitTests: <String>[
        'test/simulation_models_test.dart',
        'test/track_loader_test.dart',
      ],
    ),
    MigrationSubsystem(
      name: 'surface',
      unitTests: <String>['test/surface_speed_system_test.dart'],
    ),
    MigrationSubsystem(
      name: 'ai',
      unitTests: <String>[
        'test/ai_compatibility_scenarios_test.dart',
        'test/ai_config_test.dart',
        'test/ai_driver_test.dart',
      ],
    ),
    MigrationSubsystem(
      name: 'full_race',
      unitTests: <String>[
        'test/behavior_simulation_test.dart',
        'test/race_session_test.dart',
      ],
    ),
  ];
}

/// Captures one external verification command without hiding its diagnostics.
final class GateCommandResult {
  const GateCommandResult({
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });

  final int exitCode;
  final String stdout;
  final String stderr;

  bool get passed => exitCode == 0;
}

/// Runs a command from the Dart package directory.
typedef GateCommandRunner = GateCommandResult Function(
  String executable,
  List<String> arguments,
  Directory workingDirectory,
);

/// Executes the regression rule for a single migration subsystem.
///
/// The focused unit tests make the changed subsystem clear. The behavioral
/// gate deliberately replays the full compatibility inventory, which protects
/// every category that has already become green instead of relying on callers
/// to remember a partial list.
final class MigrationRegressionGate {
  MigrationRegressionGate(
    this.subsystem, {
    GateCommandRunner? commandRunner,
    Directory? workingDirectory,
  }) : _commandRunner = commandRunner ?? _runProcess,
       _workingDirectory = workingDirectory ?? Directory.current;

  final MigrationSubsystem subsystem;
  final GateCommandRunner _commandRunner;
  final Directory _workingDirectory;

  MigrationRegressionReport run() {
    final unitTests = _commandRunner('flutter', <String>[
      'test',
      ...subsystem.unitTests,
    ], _workingDirectory);
    final compatibility = _commandRunner('dart', const <String>[
      'run',
      'tool/full_behavioral_gate.dart',
    ], _workingDirectory);
    return MigrationRegressionReport(
      subsystem: subsystem,
      unitTests: unitTests,
      compatibility: compatibility,
    );
  }

  static GateCommandResult _runProcess(
    String executable,
    List<String> arguments,
    Directory workingDirectory,
  ) {
    try {
      final result = Process.runSync(
        executable,
        arguments,
        workingDirectory: workingDirectory.path,
      );
      return GateCommandResult(
        exitCode: result.exitCode,
        stdout: result.stdout.toString(),
        stderr: result.stderr.toString(),
      );
    } on ProcessException catch (error) {
      return GateCommandResult(exitCode: 1, stderr: error.toString());
    }
  }
}

/// The stage result, including subsystem and compatibility-category evidence.
final class MigrationRegressionReport {
  const MigrationRegressionReport({
    required this.subsystem,
    required this.unitTests,
    required this.compatibility,
  });

  final MigrationSubsystem subsystem;
  final GateCommandResult unitTests;
  final GateCommandResult compatibility;

  bool get passed => unitTests.passed && compatibility.passed;

  String format() {
    final output = StringBuffer('Migration regression gate:\n');
    output.writeln('Affected subsystem: ${subsystem.name}');
    output.writeln(
      'Dart unit tests for ${subsystem.name}: '
      '${unitTests.passed ? 'PASS' : 'FAIL'}',
    );
    output.writeln(
      'Protected compatibility categories: '
      '${MigrationSubsystem.all.map((item) => item.name).join(', ')}',
    );
    output.writeln(
      'Full compatibility inventory: '
      '${compatibility.passed ? 'PASS' : 'FAIL'}',
    );
    _writeCommandOutput(output, 'Dart unit tests', unitTests);
    _writeCommandOutput(output, 'Compatibility categories', compatibility);
    output.write('Regression rule: ${passed ? 'PASS' : 'FAIL'}');
    return output.toString();
  }

  static void _writeCommandOutput(
    StringBuffer output,
    String label,
    GateCommandResult result,
  ) {
    final details = <String>[
      result.stdout.trim(),
      result.stderr.trim(),
    ].where((value) => value.isNotEmpty).join('\n');
    if (details.isNotEmpty) {
      output
        ..writeln('\n$label output:')
        ..writeln(details);
    }
  }
}

/// Runs the CLI and returns a process-compatible status code.
int executeMigrationRegressionGate(
  List<String> arguments, {
  IOSink? outputSink,
  IOSink? errorSink,
  GateCommandRunner? commandRunner,
  Directory? workingDirectory,
}) {
  try {
    final subsystem = _parseSubsystem(arguments);
    final report = MigrationRegressionGate(
      subsystem,
      commandRunner: commandRunner,
      workingDirectory: workingDirectory,
    ).run();
    outputSink?.writeln(report.format());
    return report.passed ? 0 : 1;
  } on ArgumentError catch (error) {
    errorSink?.writeln('Migration regression gate failed: $error');
    return 1;
  }
}

MigrationSubsystem _parseSubsystem(List<String> arguments) {
  if (arguments.length != 2 || arguments.first != '--subsystem') {
    throw ArgumentError(
      'Usage: migration_regression_gate.dart --subsystem '
      '<${MigrationSubsystem.all.map((item) => item.name).join('|')}>',
    );
  }
  return MigrationSubsystem.named(arguments[1]) ??
      (throw ArgumentError.value(
        arguments[1],
        'subsystem',
        'must name a registered compatibility category',
      ));
}

void main(List<String> arguments) {
  final status = executeMigrationRegressionGate(
    arguments,
    outputSink: stdout,
    errorSink: stderr,
  );
  if (status != 0) {
    exitCode = status;
  }
}
