import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _prohibitedImports = RegExp(
  r'''^\s*import\s+['"](?:package:flutter/[^'"]+|package:flame/[^'"]+|dart:ui)['"]''',
  multiLine: true,
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

  test(
    'simulation sources do not depend on presentation or wall-clock APIs',
    () {
      final sourceFiles = <File>[
        File('lib/simulation.dart'),
        ...Directory('lib/simulation')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart')),
      ];
      const prohibitedWallClockReferences = <String>[
        'DateTime.now',
        'Stopwatch(',
        'Timer(',
      ];

      for (final sourceFile in sourceFiles) {
        final source = sourceFile.readAsStringSync();
        expect(
          _prohibitedImports.hasMatch(source),
          isFalse,
          reason: '${sourceFile.path} must not import presentation APIs',
        );
        for (final reference in prohibitedWallClockReferences) {
          expect(
            source.contains(reference),
            isFalse,
            reason: '${sourceFile.path} must not reference $reference',
          );
        }
      }
    },
  );

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
