import 'dart:io';

/// Enforces the line-coverage contract for the deterministic Dart modules.
final class DartSimulationCoverageGate {
  const DartSimulationCoverageGate({this.minimumPercent = 95});

  final int minimumPercent;

  DartCoverageReport evaluate(
    String lcov, {
    required Iterable<String> criticalSourceFiles,
  }) {
    final totals = <String, _CoverageTotal>{
      for (final module in _criticalModules) module: _CoverageTotal(),
    };
    final reportedSourceFiles = <String>{};
    String? currentModule;
    for (final line in lcov.split('\n')) {
      if (line.startsWith(_sourceFilePrefix)) {
        final sourceFile = _sourceFileForLine(line);
        currentModule = _moduleForSourceFile(sourceFile);
        if (currentModule != null) {
          reportedSourceFiles.add(sourceFile!);
        }
        continue;
      }
      if (!line.startsWith(_lineCoveragePrefix) || currentModule == null) {
        continue;
      }
      totals[currentModule]!.add(_hitCount(line));
    }
    return DartCoverageReport(
      minimumPercent: minimumPercent,
      missingSourceFiles: _missingSourceFiles(
        criticalSourceFiles,
        reportedSourceFiles,
      ),
      modules: <String, DartModuleCoverage>{
        for (final entry in totals.entries)
          entry.key: DartModuleCoverage(
            module: entry.key,
            hitLines: entry.value.hitLines,
            foundLines: entry.value.foundLines,
          ),
      },
    );
  }

  String? _sourceFileForLine(String line) {
    if (!line.startsWith(_sourceFilePrefix)) {
      return null;
    }
    final path = line.substring(_sourceFilePrefix.length).replaceAll('\\', '/');
    const simulationPath = 'lib/simulation/';
    final pathIndex = path.indexOf(simulationPath);
    if (pathIndex < 0 || (pathIndex > 0 && path[pathIndex - 1] != '/')) {
      return null;
    }
    return path.substring(pathIndex);
  }

  String? _moduleForSourceFile(String? sourceFile) {
    if (sourceFile == null) {
      return null;
    }
    for (final module in _criticalModules) {
      if (sourceFile.startsWith('lib/simulation/$module/')) {
        return module;
      }
    }
    return null;
  }

  Set<String> _missingSourceFiles(
    Iterable<String> criticalSourceFiles,
    Set<String> reportedSourceFiles,
  ) => criticalSourceFiles
      .map(_sourceFileForPath)
      .whereType<String>()
      .toSet()
      .difference(reportedSourceFiles);

  String? _sourceFileForPath(String path) =>
      _sourceFileForLine('$_sourceFilePrefix$path');

  int _hitCount(String line) {
    final fields = line.substring(_lineCoveragePrefix.length).split(',');
    if (fields.length < 2) {
      throw FormatException('Invalid LCOV line coverage record: $line');
    }
    return int.parse(fields[1]);
  }

  static const List<String> _criticalModules = <String>[
    'ai',
    'car',
    'collision',
    'race',
  ];
  static const String _lineCoveragePrefix = 'DA:';
  static const String _sourceFilePrefix = 'SF:';
}

/// Line-coverage results for all critical simulation modules.
final class DartCoverageReport {
  const DartCoverageReport({
    required this.minimumPercent,
    required this.missingSourceFiles,
    required this.modules,
  });

  final int minimumPercent;
  final Set<String> missingSourceFiles;
  final Map<String, DartModuleCoverage> modules;

  bool get passed =>
      missingSourceFiles.isEmpty &&
      modules.values.every((coverage) => coverage.meets(minimumPercent));

  String format() {
    final moduleCoverage = modules.values
        .map(
          (coverage) =>
              '${coverage.module}: ${coverage.hitLines} / ${coverage.foundLines} '
              '(${coverage.percentText}) ${coverage.meets(minimumPercent) ? 'PASS' : 'FAIL'}',
        )
        .join('\n');
    if (missingSourceFiles.isEmpty) {
      return moduleCoverage;
    }
    final missingFiles = missingSourceFiles.toList()..sort();
    return '$moduleCoverage\nMissing critical source files from LCOV:\n'
        '${missingFiles.join('\n')}';
  }
}

/// Line coverage for one critical simulation module.
final class DartModuleCoverage {
  const DartModuleCoverage({
    required this.module,
    required this.hitLines,
    required this.foundLines,
  });

  final String module;
  final int hitLines;
  final int foundLines;

  bool meets(int minimumPercent) =>
      foundLines > 0 && hitLines * 100 >= foundLines * minimumPercent;

  String get percentText => foundLines == 0
      ? '0.00%'
      : '${(hitLines * 100 / foundLines).toStringAsFixed(2)}%';
}

final class _CoverageTotal {
  var hitLines = 0;
  var foundLines = 0;

  void add(int hitCount) {
    foundLines++;
    if (hitCount > 0) {
      hitLines++;
    }
  }
}

int executeDartCoverageGate(
  List<String> arguments, {
  IOSink? outputSink,
  Directory? sourceRoot,
}) {
  if (arguments.length != 2 || arguments.first != '--lcov') {
    throw ArgumentError('Usage: coverage_gate.dart --lcov <path>');
  }
  final report = const DartSimulationCoverageGate().evaluate(
    File(arguments[1]).readAsStringSync(),
    criticalSourceFiles: _criticalSourceFiles(sourceRoot ?? Directory.current),
  );
  outputSink?.writeln('Dart critical simulation coverage (minimum 95%):');
  outputSink?.writeln(report.format());
  return report.passed ? 0 : 1;
}

Set<String> _criticalSourceFiles(Directory sourceRoot) {
  final rootPath = sourceRoot.absolute.path.replaceAll('\\', '/');
  final sourceFiles = <String>{};
  for (final module in DartSimulationCoverageGate._criticalModules) {
    final moduleDirectory = Directory('$rootPath/lib/simulation/$module');
    if (!moduleDirectory.existsSync()) {
      throw StateError(
        'Critical source directory is missing: ${moduleDirectory.path}',
      );
    }
    for (final entity in moduleDirectory.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final sourcePath = entity.absolute.path.replaceAll('\\', '/');
        sourceFiles.add(sourcePath.substring(rootPath.length + 1));
      }
    }
  }
  return sourceFiles;
}

void main(List<String> arguments) {
  try {
    final status = executeDartCoverageGate(arguments, outputSink: stdout);
    if (status != 0) {
      exitCode = status;
    }
  } on Object catch (error) {
    stderr.writeln('Dart coverage gate failed: $error');
    exitCode = 1;
  }
}
