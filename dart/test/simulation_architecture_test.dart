import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/simulation_architecture.dart';

final _prohibitedImports = RegExp(
  r'''^[ \t]*import\b[^;]*(?:['"](?:package:flutter/[^'"]+|package:flame/[^'"]+|dart:ui)['"])[^;]*;''',
  multiLine: true,
);
final _prohibitedWallClockReferences = RegExp(
  r'''(?:DateTime\.(?:now|timestamp)\b|Stopwatch\s*\(|Timer(?:\s*\(|\.(?:periodic|run)\b)|Future(?:<[^>]+>)?\.delayed\b)''',
);

void main() {
  test('simulation keeps every required pure-Dart module boundary', () {
    const requiredDirectories = <String>[
      'lib/simulation/math',
      'lib/simulation/car',
      'lib/simulation/input',
      'lib/simulation/collision',
      'lib/simulation/surface',
      'lib/simulation/track',
      'lib/simulation/race',
      'lib/simulation/ai',
      'lib/simulation/scenario',
      'lib/simulation/snapshot',
    ];
    for (final path in requiredDirectories) {
      expect(Directory(path).existsSync(), isTrue, reason: '$path must exist');
    }
  });

  test('architecture rule recognizes complete presentation import URIs', () {
    expect(
      _prohibitedImports.hasMatch("import 'package:flutter/widgets.dart';"),
      isTrue,
    );
    expect(
      _prohibitedImports.hasMatch("import 'package:flame/game.dart';"),
      isTrue,
    );
    expect(_prohibitedImports.hasMatch("import 'dart:ui';"), isTrue);
  });

  test('architecture rule recognizes prohibited conditional imports', () {
    expect(
      _prohibitedImports.hasMatch(
        "import 'safe_stub.dart'\n"
        "    if (dart.library.ui) 'package:flutter/widgets.dart';",
      ),
      isTrue,
    );
  });

  test('architecture rule recognizes common wall-clock APIs', () {
    const wallClockExamples = <String>[
      'Future<void>.delayed(const Duration(seconds: 1));',
      'Future.delayed(const Duration(seconds: 1));',
      'Timer.periodic(const Duration(seconds: 1), callback);',
      'Timer.run(callback);',
      'DateTime.timestamp();',
    ];
    for (final source in wallClockExamples) {
      expect(
        _prohibitedWallClockReferences.hasMatch(source),
        isTrue,
        reason: '$source must be rejected',
      );
    }
  });

  test(
    'simulation sources do not depend on presentation or wall-clock APIs',
    () {
      expect(
        findSimulationArchitectureViolations(libDirectory: Directory('lib')),
        isEmpty,
      );
    },
  );

  test('architecture rule follows transitive local imports', () {
    final fixture = Directory.systemTemp.createTempSync(
      'toy-racers-architecture-',
    );
    try {
      final libDirectory = Directory('${fixture.path}/lib')
        ..createSync(recursive: true);
      Directory('${libDirectory.path}/simulation').createSync();
      Directory('${libDirectory.path}/platform').createSync();
      File('${libDirectory.path}/simulation.dart')
          .writeAsStringSync("export 'simulation/entry.dart';\n");
      File('${libDirectory.path}/simulation/entry.dart')
          .writeAsStringSync("import '../platform/input.dart';\n");
      File('${libDirectory.path}/platform/input.dart')
          .writeAsStringSync("import 'package:flutter/widgets.dart';\n");

      expect(
        findSimulationArchitectureViolations(libDirectory: libDirectory),
        hasLength(1),
      );
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test('architecture rule follows part and URI-based part of directives', () {
    final fixture = Directory.systemTemp.createTempSync(
      'toy-racers-architecture-parts-',
    );
    try {
      final libDirectory = Directory('${fixture.path}/lib')
        ..createSync(recursive: true);
      Directory('${libDirectory.path}/simulation').createSync();
      Directory('${libDirectory.path}/shared').createSync();
      File('${libDirectory.path}/simulation.dart')
          .writeAsStringSync("export 'simulation/entry.dart';\n");
      File('${libDirectory.path}/simulation/entry.dart')
          .writeAsStringSync("part '../shared/timing.dart';\n");
      File('${libDirectory.path}/shared/timing.dart')
          .writeAsStringSync("part of '../shared/timing_library.dart';\n");
      File('${libDirectory.path}/shared/timing_library.dart')
          .writeAsStringSync('final now = DateTime.now();\n');

      expect(
        findSimulationArchitectureViolations(libDirectory: libDirectory),
        hasLength(1),
      );
    } finally {
      fixture.deleteSync(recursive: true);
    }
  });

  test('simulation assembly runs with the Dart VM', () async {
    final result = await Process.run('dart', <String>[
      'run',
      'tool/simulation_architecture_check.dart',
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(
      result.stdout,
      'simulation-architecture-ok${Platform.lineTerminator}',
    );
  });
}
