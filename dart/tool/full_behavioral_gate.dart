import 'dart:convert';
import 'dart:io';

import 'package:toy_racers/simulation.dart';

export 'behavioral_inventory.dart';

import 'behavioral_inventory.dart';
import 'behavior_runner.dart';

/// Replays every versioned Dart compatibility fixture against its Kotlin golden.
///
/// The gate is deliberately a headless, explicit command. It never regenerates
/// or writes a golden master, and a failed comparison produces a non-zero exit
/// status before presentation-layer work can proceed.
final class FullBehavioralGate {
  FullBehavioralGate(this.repositoryRoot, {BehaviorTraceComparator? comparator})
    // Keep the public test seam named `comparator`; the backing field is private.
    // ignore: prefer_initializing_formals
    : _comparator = comparator,
      _fileRunner = BehaviorRunner(tmxSource: _readTmx(repositoryRoot)),
      _legacyRunner = BehaviorRunner(
        tmxSource: _readTmx(repositoryRoot),
        continueAfterFinish: false,
      );

  final Directory repositoryRoot;
  final BehaviorTraceComparator? _comparator;
  final BehaviorRunner _fileRunner;
  final BehaviorRunner _legacyRunner;

  BehavioralGateReport run() {
    final scratch = Directory.systemTemp.createTempSync(
      'toy-racers-full-behavioral-gate-',
    );
    final goldenBefore = _goldenContents();
    try {
      final inventory = BehavioralInventory.load(repositoryRoot, scratch);
      final generated = <_GeneratedBehavioralFixture>[
        for (final fixture in inventory.fixtures)
          _generateFixture(fixture, scratch),
      ];
      final results = _compareFixtures(generated, scratch);
      return BehavioralGateReport(
        results: results,
        unexpectedGoldenChanges: _changedGoldenFiles(goldenBefore),
      );
    } finally {
      scratch.deleteSync(recursive: true);
    }
  }

  _GeneratedBehavioralFixture _generateFixture(
    BehavioralFixture fixture,
    Directory scratch,
  ) {
    final actual = File.fromUri(
      scratch.uri.resolve('actual/${fixture.outputPath}'),
    );
    actual.parent.createSync(recursive: true);
    actual.writeAsStringSync(
      CompatibilityTraceJson.encode(
        _runnerFor(fixture).replay(fixture.scenario),
      ),
    );
    return _GeneratedBehavioralFixture(fixture, actual);
  }

  List<BehavioralFixtureResult> _compareFixtures(
    List<_GeneratedBehavioralFixture> generated,
    Directory scratch,
  ) {
    final comparator = _comparator;
    if (comparator != null) {
      return <BehavioralFixtureResult>[
        for (final item in generated) _compareFixture(item, comparator),
      ];
    }
    try {
      _compareWithKotlin(repositoryRoot, generated, scratch);
      return <BehavioralFixtureResult>[
        for (final item in generated)
          BehavioralFixtureResult(fixture: item.fixture),
      ];
    } on Object catch (error) {
      return <BehavioralFixtureResult>[
        for (final item in generated)
          BehavioralFixtureResult(fixture: item.fixture, failure: '$error'),
      ];
    }
  }

  BehavioralFixtureResult _compareFixture(
    _GeneratedBehavioralFixture item,
    BehaviorTraceComparator comparator,
  ) {
    try {
      comparator(repositoryRoot, item.fixture.expectedGolden, item.actual);
      return BehavioralFixtureResult(fixture: item.fixture);
    } on Object catch (error) {
      return BehavioralFixtureResult(fixture: item.fixture, failure: '$error');
    }
  }

  BehaviorRunner _runnerFor(BehavioralFixture fixture) =>
      fixture.category == BehavioralInventory.legacyCategory
      ? _legacyRunner
      : _fileRunner;

  Map<String, String> _goldenContents() {
    final contents = <String, String>{};
    for (final file in _goldenFiles()) {
      contents[file.absolute.path] = base64Encode(file.readAsBytesSync());
    }
    return contents;
  }

  List<String> _changedGoldenFiles(Map<String, String> before) {
    final after = _goldenContents();
    final paths = <String>{...before.keys, ...after.keys}.toList()..sort();
    return <String>[
      for (final path in paths)
        if (before[path] != after[path]) path,
    ];
  }

  List<File> _goldenFiles() {
    final compatibilityGoldens = Directory.fromUri(
      repositoryRoot.uri.resolve('compatibility/golden/'),
    );
    final legacyGolden = File.fromUri(
      repositoryRoot.uri.resolve('core/src/test/resources/compat/goldens.json'),
    );
    return <File>[..._jsonFiles(compatibilityGoldens), legacyGolden];
  }

  static String Function(String) _readTmx(Directory repositoryRoot) {
    final dartDirectory = Directory.fromUri(
      repositoryRoot.uri.resolve('dart/'),
    );
    return (assetPath) =>
        File.fromUri(dartDirectory.uri.resolve(assetPath)).readAsStringSync();
  }

  static void _compareWithKotlin(
    Directory repositoryRoot,
    List<_GeneratedBehavioralFixture> generated,
    Directory scratch,
  ) {
    final manifest = File.fromUri(
      scratch.uri.resolve('comparison-manifest.json'),
    );
    manifest.writeAsStringSync(
      jsonEncode(<Map<String, String>>[
        for (final item in generated)
          <String, String>{
            'label': item.fixture.label,
            'expected': item.fixture.expectedGolden.absolute.path,
            'actual': item.actual.absolute.path,
          },
      ]),
    );
    final wrapperName = Platform.isWindows ? 'gradlew.bat' : 'gradlew';
    final wrapper = File.fromUri(repositoryRoot.uri.resolve(wrapperName));
    final result = Process.runSync(wrapper.path, <String>[
      ':core:compareBehaviorTraces',
      '-Pmanifest=${manifest.absolute.path}',
      '--quiet',
    ], workingDirectory: repositoryRoot.path);
    if (result.exitCode != 0) {
      throw StateError(_comparisonFailure(result));
    }
  }

  static String _comparisonFailure(ProcessResult result) {
    final output = <String>[
      result.stderr.toString().trim(),
      result.stdout.toString().trim(),
    ].where((value) => value.isNotEmpty).join('\n');
    return output.isEmpty ? 'Kotlin trace comparator failed.' : output;
  }
}

final class _GeneratedBehavioralFixture {
  const _GeneratedBehavioralFixture(this.fixture, this.actual);

  final BehavioralFixture fixture;
  final File actual;
}

/// A completed comparison; [failure] is populated only for a deterministic mismatch.
final class BehavioralFixtureResult {
  const BehavioralFixtureResult({required this.fixture, this.failure});

  final BehavioralFixture fixture;
  final String? failure;

  bool get passed => failure == null;
}

/// Stable machine-readable-in-text summary for the Dart behavioral gate.
final class BehavioralGateReport {
  BehavioralGateReport({
    required List<BehavioralFixtureResult> results,
    required List<String> unexpectedGoldenChanges,
  }) : results = List<BehavioralFixtureResult>.unmodifiable(results),
       unexpectedGoldenChanges = List<String>.unmodifiable(
         unexpectedGoldenChanges,
       );

  final List<BehavioralFixtureResult> results;
  final List<String> unexpectedGoldenChanges;

  int get passed => results.where((result) => result.passed).length;
  int get failed => results.length - passed;
  bool get passedAll =>
      failed == 0 &&
      unexpectedGoldenChanges.isEmpty &&
      results.isNotEmpty &&
      _requiredCategories.every(_categoryPassed);

  String format() {
    final output = StringBuffer('Dart behavioral compatibility:\n');
    output.writeln(
      'Passed: ${passedAll ? 'ALL' : '$passed / ${results.length}'}',
    );
    output.writeln('Failed: $failed');
    output.writeln('Skipped: 0');
    output.writeln(
      'Unexpected golden changes: ${unexpectedGoldenChanges.length}',
    );
    output.writeln(
      '$passed / ${results.length} ${passedAll ? 'PASS' : 'FAIL'}',
    );
    for (final category in _requiredCategories) {
      output.writeln(
        '${_displayCategory(category)} ${_categoryPassed(category) ? 'PASS' : 'FAIL'}.',
      );
    }
    for (final result in results.where((result) => !result.passed)) {
      output.writeln('FAIL ${result.fixture.label}: ${result.failure}');
    }
    for (final file in unexpectedGoldenChanges) {
      output.writeln('UNEXPECTED GOLDEN CHANGE: $file');
    }
    return output.toString().trimRight();
  }

  bool _categoryPassed(String category) {
    final categoryResults = results
        .where((result) => _fixtureBelongsToCategory(result.fixture, category))
        .toList();
    return categoryResults.isNotEmpty &&
        categoryResults.every((result) => result.passed);
  }

  bool _fixtureBelongsToCategory(BehavioralFixture fixture, String category) {
    if (fixture.category == category) {
      return true;
    }
    if (fixture.category != BehavioralInventory.legacyCategory) {
      return false;
    }
    return category == 'full_race'
        ? fixture.scenario.fullRace
        : fixture.scenario.tags.contains(category);
  }

  static String _displayCategory(String category) =>
      category == 'ai' ? 'AI' : category;

  static const List<String> _requiredCategories = <String>[
    'car',
    'collision',
    'race',
    'track',
    'surface',
    'ai',
    'full_race',
  ];
}

/// Compares one actual Dart trace with its checked-in Kotlin golden trace.
typedef BehaviorTraceComparator = void Function(
  Directory repositoryRoot,
  File expected,
  File actual,
);

/// Runs the command and returns a process-compatible status code.
int executeFullBehavioralGate(
  List<String> arguments, {
  IOSink? outputSink,
  IOSink? errorSink,
  BehaviorTraceComparator? comparator,
}) {
  try {
    final repositoryRoot = _parseRepositoryRoot(arguments);
    final report = FullBehavioralGate(
      repositoryRoot,
      comparator: comparator,
    ).run();
    outputSink?.writeln(report.format());
    return report.passedAll ? 0 : 1;
  } on Object catch (error) {
    errorSink?.writeln('Full behavioral gate failed: $error');
    return 1;
  }
}

Directory _parseRepositoryRoot(List<String> arguments) {
  if (arguments.isEmpty) {
    return _findRepositoryRoot(Directory.current);
  }
  if (arguments.length != 2 || arguments.first != '--repository-root') {
    throw ArgumentError(
      'Usage: full_behavioral_gate.dart [--repository-root <path>]',
    );
  }
  return _findRepositoryRoot(Directory(arguments[1]));
}

Directory _findRepositoryRoot(Directory start) {
  var candidate = start.absolute;
  while (true) {
    if (_isRepositoryRoot(candidate)) {
      return candidate;
    }
    if (candidate.parent.path == candidate.path) {
      break;
    }
    candidate = candidate.parent;
  }
  throw ArgumentError('Could not find a Toy Racers repository root.');
}

bool _isRepositoryRoot(Directory directory) =>
    Directory.fromUri(directory.uri.resolve('compatibility/')).existsSync() &&
    Directory.fromUri(directory.uri.resolve('core/')).existsSync() &&
    Directory.fromUri(directory.uri.resolve('dart/')).existsSync();

List<File> _jsonFiles(Directory directory) =>
    directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList()
      ..sort((left, right) => left.path.compareTo(right.path));

void main(List<String> arguments) {
  final status = executeFullBehavioralGate(
    arguments,
    outputSink: stdout,
    errorSink: stderr,
  );
  if (status != 0) {
    exitCode = status;
  }
}
