import 'dart:io';

import 'package:toy_racers/simulation.dart';

import 'behavior_runner.dart';
import 'full_behavioral_gate.dart' show BehavioralInventory;

/// Replays the complete Dart behavioral inventory and compares canonical traces.
final class DartBehavioralStabilityRunner {
  DartBehavioralStabilityRunner(
    this.repositoryRoot, {
    this.repeatCount = _requiredRepeatCount,
    this.replay,
  });

  final Directory repositoryRoot;
  final int repeatCount;
  final BehavioralTraceReplay? replay;

  DartBehavioralStabilityReport run() {
    if (repeatCount < 2) {
      throw ArgumentError.value(
        repeatCount,
        'repeatCount',
        'must be at least 2',
      );
    }
    final scratch = Directory.systemTemp.createTempSync(
      'toy-racers-dart-behavioral-stability-',
    );
    try {
      final inventory = BehavioralInventory.load(repositoryRoot, scratch);
      final baseline = _replayInventory(inventory);
      for (var run = 2; run <= repeatCount; run++) {
        _verifyStable(baseline, _replayInventory(inventory), run);
      }
      return DartBehavioralStabilityReport(
        fixtureCount: baseline.length,
        repeatCount: repeatCount,
      );
    } finally {
      scratch.deleteSync(recursive: true);
    }
  }

  Map<String, String> _replayInventory(BehavioralInventory inventory) {
    final traceReplay = replay;
    if (traceReplay != null) {
      return Map<String, String>.unmodifiable(traceReplay(inventory));
    }
    final tmxSource = _readTmx(repositoryRoot);
    final fileRunner = BehaviorRunner(tmxSource: tmxSource);
    final legacyRunner = BehaviorRunner(
      tmxSource: tmxSource,
      continueAfterFinish: false,
    );
    return Map<String, String>.unmodifiable(<String, String>{
      for (final fixture in inventory.fixtures)
        fixture.label: CompatibilityTraceJson.encode(
          (fixture.category == BehavioralInventory.legacyCategory
                  ? legacyRunner
                  : fileRunner)
              .replay(fixture.scenario),
        ),
    });
  }

  void _verifyStable(
    Map<String, String> baseline,
    Map<String, String> replay,
    int run,
  ) {
    if (baseline.length != replay.length) {
      throw StateError(
        'Dart behavioral fixture count changed on suite run $run: '
        '${baseline.length} became ${replay.length}.',
      );
    }
    for (final entry in baseline.entries) {
      if (replay[entry.key] != entry.value) {
        throw StateError(
          'Dart behavioral fixture ${entry.key} diverged on suite run $run.',
        );
      }
    }
  }

  static String Function(String) _readTmx(Directory repositoryRoot) {
    final dartDirectory = Directory.fromUri(
      repositoryRoot.uri.resolve('dart/'),
    );
    return (assetPath) =>
        File.fromUri(dartDirectory.uri.resolve(assetPath)).readAsStringSync();
  }

  static const int _requiredRepeatCount = 20;
}

/// A test seam for replaying every fixture into its normalized trace.
typedef BehavioralTraceReplay = Map<String, String> Function(
  BehavioralInventory inventory,
);

/// Summary of an exact canonical-output stability check.
final class DartBehavioralStabilityReport {
  const DartBehavioralStabilityReport({
    required this.fixtureCount,
    required this.repeatCount,
  });

  final int fixtureCount;
  final int repeatCount;

  String format() =>
      'Dart behavioral stability: $repeatCount / $repeatCount identical '
      '($fixtureCount fixtures each).';
}

int executeDartBehavioralStability(
  List<String> arguments, {
  IOSink? outputSink,
}) {
  final repositoryRoot = _parseRepositoryRoot(arguments);
  final report = DartBehavioralStabilityRunner(repositoryRoot).run();
  outputSink?.writeln(report.format());
  return 0;
}

Directory _parseRepositoryRoot(List<String> arguments) {
  if (arguments.length != 2 || arguments.first != '--repository-root') {
    throw ArgumentError(
      'Usage: dart_behavioral_stability.dart --repository-root <path>',
    );
  }
  final root = Directory(arguments[1]).absolute;
  if (!Directory.fromUri(root.uri.resolve('compatibility/')).existsSync() ||
      !Directory.fromUri(root.uri.resolve('dart/')).existsSync()) {
    throw ArgumentError('${root.path} is not a Toy Racers repository root.');
  }
  return root;
}

void main(List<String> arguments) {
  try {
    executeDartBehavioralStability(arguments, outputSink: stdout);
  } on Object catch (error) {
    stderr.writeln('Dart behavioral stability failed: $error');
    exitCode = 1;
  }
}
