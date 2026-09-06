import 'dart:io';

/// Enforces the line-coverage contract for the deterministic Dart modules.
final class DartSimulationCoverageGate {
  const DartSimulationCoverageGate({this.minimumPercent = 95});

  final int minimumPercent;

  DartCoverageReport evaluate(String lcov) {
    final totals = <String, _CoverageTotal>{
      for (final module in _criticalModules) module: _CoverageTotal(),
    };
    String? currentModule;
    for (final line in lcov.split('\n')) {
      if (line.startsWith(_sourceFilePrefix)) {
        currentModule = _moduleForSourceLine(line);
        continue;
      }
      if (!line.startsWith(_lineCoveragePrefix) || currentModule == null) {
        continue;
      }
      totals[currentModule]!.add(_hitCount(line));
    }
    return DartCoverageReport(
      minimumPercent: minimumPercent,
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

  String? _moduleForSourceLine(String line) {
    if (!line.startsWith(_sourceFilePrefix)) {
      return null;
    }
    final path = line.substring(_sourceFilePrefix.length).replaceAll('\\', '/');
    for (final module in _criticalModules) {
      if (path.startsWith('lib/simulation/$module/') ||
          path.contains('/lib/simulation/$module/')) {
        return module;
      }
    }
    return null;
  }

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
    required this.modules,
  });

  final int minimumPercent;
  final Map<String, DartModuleCoverage> modules;

  bool get passed =>
      modules.values.every((coverage) => coverage.meets(minimumPercent));

  String format() => modules.values
      .map(
        (coverage) =>
            '${coverage.module}: ${coverage.hitLines} / ${coverage.foundLines} '
            '(${coverage.percentText}) ${coverage.meets(minimumPercent) ? 'PASS' : 'FAIL'}',
      )
      .join('\n');
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

int executeDartCoverageGate(List<String> arguments, {IOSink? outputSink}) {
  if (arguments.length != 2 || arguments.first != '--lcov') {
    throw ArgumentError('Usage: coverage_gate.dart --lcov <path>');
  }
  final report = const DartSimulationCoverageGate().evaluate(
    File(arguments[1]).readAsStringSync(),
  );
  outputSink?.writeln('Dart critical simulation coverage (minimum 95%):');
  outputSink?.writeln(report.format());
  return report.passed ? 0 : 1;
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
