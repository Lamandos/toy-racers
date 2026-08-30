import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:toy_racers/simulation.dart';

import 'behavior_runner.dart';

/// One stress fixture and the normalized Dart trace written for it.
final class StressTraceRequest {
  const StressTraceRequest({required this.scenario, required this.output});

  final File scenario;
  final File output;
}

/// Replays the long-running compatibility fixtures and checks Dart determinism.
final class StressDeterminismRunner {
  StressDeterminismRunner({
    this.repeatCount = _requiredRepeatCount,
    BehaviorRunner? behaviorRunner,
    CompatibilityScenarioParser? scenarioParser,
  }) : _behaviorRunner = behaviorRunner ?? BehaviorRunner(),
       _scenarioParser = scenarioParser ?? const CompatibilityScenarioParser();

  final int repeatCount;
  final BehaviorRunner _behaviorRunner;
  final CompatibilityScenarioParser _scenarioParser;

  StressDeterminismReport run(List<StressTraceRequest> requests) {
    if (repeatCount < 1) {
      throw ArgumentError.value(repeatCount, 'repeatCount', 'must be positive');
    }
    final scenarios = <_StressScenario>[
      for (final request in requests)
        _StressScenario(request, _readScenario(request.scenario)),
    ];
    if (scenarios.length != _stressFixtureCount) {
      throw ArgumentError(
        'Expected $_stressFixtureCount stress fixtures, found ${scenarios.length}.',
      );
    }
    final shortScenario = _findScenario(scenarios, _shortScenarioTicks);
    final longScenario = _findScenario(scenarios, _longScenarioTicks);

    final shortOutput = _runAndEncode(shortScenario.scenario);
    shortScenario.request.output.parent.createSync(recursive: true);
    shortScenario.request.output.writeAsStringSync(shortOutput);

    late final String firstLongOutput;
    late final String normalizedHash;
    for (var run = 0; run < repeatCount; run++) {
      final output = _runAndEncode(longScenario.scenario);
      if (run == 0) {
        firstLongOutput = output;
        normalizedHash = normalizedOutputHash(output);
      } else if (normalizedOutputHash(output) != normalizedHash ||
          output != firstLongOutput) {
        throw StateError(
          'Dart stress output changed on repeat ${run + 1} of $repeatCount.',
        );
      }
    }
    longScenario.request.output.parent.createSync(recursive: true);
    longScenario.request.output.writeAsStringSync(firstLongOutput);

    return StressDeterminismReport(
      repeatCount: repeatCount,
      normalizedHash: normalizedHash,
      scenariosPassed: scenarios.length,
    );
  }

  CompatibilityScenario _readScenario(File scenarioFile) {
    final document = _scenarioParser.parseScenarioDocument(
      scenarioFile.readAsStringSync(),
      inputScriptSource: (filename) =>
          File('${scenarioFile.parent.path}${Platform.pathSeparator}$filename')
              .readAsStringSync(),
    );
    if (document.scenarios.length != 1) {
      throw ArgumentError(
        'A stress fixture must contain exactly one scenario.',
      );
    }
    return document.scenarios.single;
  }

  _StressScenario _findScenario(
    List<_StressScenario> scenarios,
    int expectedTicks,
  ) {
    final matches = scenarios
        .where((fixture) => fixture.scenario.ticks == expectedTicks)
        .toList();
    if (matches.length != 1) {
      throw ArgumentError(
        'Expected exactly one $expectedTicks-tick stress fixture, found ${matches.length}.',
      );
    }
    return matches.single;
  }

  String _runAndEncode(CompatibilityScenario scenario) {
    final trace = _behaviorRunner.replay(scenario);
    StressTraceValidator.validate(trace, scenario);
    final output = CompatibilityTraceJson.encode(trace);
    if (output.contains(_negativeZero)) {
      throw StateError(
        'Stress trace contains a negative zero after normalization.',
      );
    }
    return output;
  }

  static const int _longScenarioTicks = 5000;
  static const String _negativeZero = '-0.000000';
  static const int _requiredRepeatCount = 20;
  static const int _shortScenarioTicks = 1000;
  static const int _stressFixtureCount = 2;
}

/// Strict race invariants for the two published long-running fixtures.
final class StressTraceValidator {
  StressTraceValidator._();

  static void validate(
    CompatibilityTrace trace,
    CompatibilityScenario scenario,
  ) {
    final checkpointCount = _checkpointCount(scenario.trackId);
    _require(trace.scenarioId == scenario.id, 'scenario ID changed');
    _require(trace.seed == scenario.seed, 'seed changed');
    _require(
      trace.samples.length == scenario.ticks + _startSampleCount,
      'sample count is impossible for ${scenario.ticks} ticks',
    );
    _validateStartSamples(
      trace.samples.take(_startSampleCount).toList(),
      checkpointCount,
    );
    final simulationSamples = trace.samples.skip(_startSampleCount).toList();
    _validateSimulationSamples(simulationSamples, scenario, checkpointCount);
    _validateProgression(simulationSamples);
  }

  static int _checkpointCount(String trackId) {
    final track = TrackLoader(_readTmx).loadById(trackId);
    return track.checkpoints.length;
  }

  static String _readTmx(String path) => File(path).readAsStringSync();

  static void _validateStartSamples(
    List<CompatibilityTraceSample> samples,
    int checkpointCount,
  ) {
    _require(
      samples.map((sample) => sample.label).toList().join(',') ==
          'countdown,racing',
      'initial lifecycle states are invalid',
    );
    final countdown = samples.first.snapshot;
    final racing = samples.last.snapshot;
    _validateInitialSnapshot(countdown, 'countdown', 'active', true);
    _validateInitialSnapshot(racing, 'racing', 'complete', false);
    for (final snapshot in <CompatibilitySnapshot>[countdown, racing]) {
      _validateParticipants(snapshot, checkpointCount, 0);
      _validateFinishResults(snapshot, 0);
    }
  }

  static void _validateInitialSnapshot(
    CompatibilitySnapshot snapshot,
    String raceState,
    String countdownState,
    bool hasCountdown,
  ) {
    _require(
      snapshot.simulationTick == 0,
      'initial simulation tick is not zero',
    );
    _require(snapshot.raceState == raceState, 'initial race state is invalid');
    _require(
      snapshot.countdown.state == countdownState,
      'initial countdown state is invalid',
    );
    _require(
      hasCountdown
          ? snapshot.countdown.remainingSeconds > 0
          : snapshot.countdown.remainingSeconds == 0,
      'initial countdown duration is invalid',
    );
    _require(
      snapshot.elapsedSimulationTime == 0,
      'initial simulation time is invalid',
    );
  }

  static void _validateSimulationSamples(
    List<CompatibilityTraceSample> samples,
    CompatibilityScenario scenario,
    int checkpointCount,
  ) {
    _require(samples.length == scenario.ticks, 'physical samples are missing');
    for (var index = 0; index < samples.length; index++) {
      final sample = samples[index];
      final tick = index + 1;
      _require(
        sample.label == _simulationLabel,
        'unexpected sample at tick $tick',
      );
      _require(
        sample.tick == tick,
        'trace tick changed at physical tick $tick',
      );
      _validateSnapshot(sample.snapshot, tick, checkpointCount);
    }
  }

  static void _validateSnapshot(
    CompatibilitySnapshot snapshot,
    int tick,
    int checkpointCount,
  ) {
    _require(
      snapshot.simulationTick == tick,
      'simulation tick changed at tick $tick',
    );
    _require(
      snapshot.raceState == _racingState,
      'impossible race state at tick $tick',
    );
    _require(
      snapshot.countdown.state == _completeCountdown,
      'countdown resumed at tick $tick',
    );
    _require(
      snapshot.countdown.remainingSeconds == 0,
      'countdown duration changed at tick $tick',
    );
    _require(
      snapshot.elapsedSimulationTime == Float32.elapsedSimulationTime(tick),
      'simulation time changed at tick $tick',
    );
    _require(
      snapshot.currentLap >= 1 &&
          snapshot.currentLap <= RaceRules.defaultLapCount,
      'current lap is invalid at tick $tick',
    );
    _require(
      snapshot.currentProgress.checkpoint >= 0 &&
          snapshot.currentProgress.checkpoint <= checkpointCount &&
          snapshot.currentProgress.completedLaps >= 0 &&
          snapshot.currentProgress.completedLaps < RaceRules.defaultLapCount,
      'player progress is invalid at tick $tick',
    );
    _validateParticipants(snapshot, checkpointCount, tick);
    _validateFinishResults(snapshot, tick);
  }

  static void _validateParticipants(
    CompatibilitySnapshot snapshot,
    int checkpointCount,
    int tick,
  ) {
    final participants = snapshot.participants;
    _require(
      _sameValues(
        participants.map((participant) => participant.id),
        _participantIds,
      ),
      'participant IDs are corrupted at tick $tick',
    );
    final positions =
        participants.map((participant) => participant.racePosition).toList()
          ..sort();
    _require(
      _sameValues(
        positions,
        List<int>.generate(participants.length, (index) => index + 1),
      ),
      'race positions are corrupted at tick $tick',
    );
    for (final participant in participants) {
      _validateParticipant(participant, checkpointCount, tick);
    }
    final expectedRanking =
        List<CompatibilityParticipantSnapshot>.of(participants)
          ..sort((left, right) {
            final position = left.racePosition.compareTo(right.racePosition);
            return position != 0 ? position : left.id.compareTo(right.id);
          });
    _require(
      _sameValues(
        snapshot.ranking,
        expectedRanking.map((participant) => participant.id),
      ),
      'ranking is corrupted at tick $tick',
    );
  }

  static void _validateParticipant(
    CompatibilityParticipantSnapshot participant,
    int checkpointCount,
    int tick,
  ) {
    _require(
      participant.checkpoint >= 0 && participant.checkpoint <= checkpointCount,
      'checkpoint is invalid for ${participant.id} at tick $tick',
    );
    _require(
      participant.lap >= 0 && participant.lap <= RaceRules.defaultLapCount,
      'lap is invalid for ${participant.id} at tick $tick',
    );
    _require(
      participant.finished
          ? participant.lap == RaceRules.defaultLapCount
          : participant.lap < RaceRules.defaultLapCount,
      'finished state is impossible for ${participant.id} at tick $tick',
    );
    final numbers = <double>[
      participant.x,
      participant.y,
      participant.rotation,
      participant.velocityX,
      participant.velocityY,
      participant.angularVelocity,
      participant.longitudinalSpeed,
      participant.lateralSpeed,
      participant.driftAmount,
    ];
    _require(
      numbers.every((value) => value.isFinite),
      'NaN or Infinity at tick $tick',
    );
    _require(
      participant.rotation >= 0 && participant.rotation < _fullTurnDegrees,
      'rotation is invalid for ${participant.id} at tick $tick',
    );
    final velocity = math.sqrt(
      participant.velocityX * participant.velocityX +
          participant.velocityY * participant.velocityY,
    );
    _require(
      velocity <= _maximumAllowedVelocity,
      'velocity exploded for ${participant.id} at tick $tick',
    );
  }

  static void _validateFinishResults(CompatibilitySnapshot snapshot, int tick) {
    final resultIds = snapshot.finishResults
        .map((result) => result.participantId)
        .toList();
    _require(
      _sameValues(snapshot.finishedParticipants, resultIds),
      'finished participant order is corrupted at tick $tick',
    );
    final finishedIds = snapshot.participants
        .where((participant) => participant.finished)
        .map((participant) => participant.id)
        .toList();
    _require(
      _sameValues(
        finishedIds.toSet().toList()..sort(),
        resultIds.toSet().toList()..sort(),
      ),
      'finished participants are corrupted at tick $tick',
    );
    final positions = snapshot.finishResults
        .map((result) => result.finishPosition)
        .toList();
    _require(
      _sameValues(
        positions,
        List<int>.generate(positions.length, (index) => index + 1),
      ),
      'finish positions are corrupted at tick $tick',
    );
    for (final result in snapshot.finishResults) {
      _require(
        result.elapsedSimulationTime.isFinite &&
            result.elapsedSimulationTime >= 0 &&
            result.bestLapTime != null &&
            result.bestLapTime!.isFinite &&
            result.bestLapTime! >= 0,
        'finish result is invalid at tick $tick',
      );
    }
  }

  static void _validateProgression(List<CompatibilityTraceSample> samples) {
    for (var index = 1; index < samples.length; index++) {
      final previous = samples[index - 1].snapshot.participants;
      final current = samples[index].snapshot.participants;
      for (var participant = 0; participant < current.length; participant++) {
        final before = previous[participant];
        final after = current[participant];
        final progresses =
            after.lap > before.lap ||
            (after.lap == before.lap && after.checkpoint >= before.checkpoint);
        _require(
          progresses,
          'progress regressed for ${after.id} at tick ${samples[index].tick}',
        );
      }
    }
  }

  static void _require(bool condition, String message) {
    if (!condition) {
      throw StateError('Stress trace invariant failed: $message');
    }
  }

  static bool _sameValues<T>(Iterable<T> left, Iterable<T> right) {
    final leftValues = left.toList();
    final rightValues = right.toList();
    if (leftValues.length != rightValues.length) {
      return false;
    }
    for (var index = 0; index < leftValues.length; index++) {
      if (leftValues[index] != rightValues[index]) {
        return false;
      }
    }
    return true;
  }

  static final double _maximumAllowedVelocity =
      CarConfig().maxForwardSpeed *
      _maximumPerformanceMultiplier *
      _collisionVelocityAllowance;
  static const double _collisionVelocityAllowance = 3;
  static const String _completeCountdown = 'complete';
  static const double _fullTurnDegrees = 360;
  static const double _maximumPerformanceMultiplier = 1.100000023841858;
  static const String _racingState = 'racing';
  static const String _simulationLabel = 'simulation';
  static const int _startSampleCount = 2;
  static const List<String> _participantIds = <String>[
    'ai-0',
    'ai-1',
    'ai-2',
    'ai-3',
    'ai-4',
    'player',
  ];
}

/// Stable 64-bit FNV-1a hash for a canonical UTF-8 behavior trace.
String normalizedOutputHash(String output) {
  var hash = _fnvOffsetBasis;
  for (final byte in utf8.encode(output)) {
    hash ^= BigInt.from(byte);
    hash = (hash * _fnvPrime) & _fnvMask;
  }
  return hash.toRadixString(16).padLeft(_hashHexDigits, '0');
}

/// Summary emitted after the complete Dart stress and determinism run.
final class StressDeterminismReport {
  const StressDeterminismReport({
    required this.repeatCount,
    required this.normalizedHash,
    required this.scenariosPassed,
  });

  final int repeatCount;
  final String normalizedHash;
  final int scenariosPassed;

  String format() =>
      '''Dart stress:
1,000 ticks PASS
5,000 ticks PASS
Normalized output hash (FNV-1a-64): $normalizedHash
Dart determinism: $repeatCount / $repeatCount identical''';
}

/// Runs the command and returns a process-compatible status code.
int executeStressDeterminismRunner(
  List<String> arguments, {
  IOSink? outputSink,
  IOSink? errorSink,
}) {
  try {
    final options = _parseOptions(arguments);
    final report = StressDeterminismRunner(repeatCount: options.repeatCount)
        .run(options.requests);
    outputSink?.writeln(report.format());
    return 0;
  } on Object catch (error) {
    errorSink?.writeln('Dart stress runner failed: $error');
    return 1;
  }
}

_StressRunnerOptions _parseOptions(List<String> arguments) {
  if (arguments.length < 6 || arguments.first != _repeatCountOption) {
    throw ArgumentError(_usage);
  }
  final repeatCount = int.tryParse(arguments[1]);
  if (repeatCount == null || repeatCount < 1 || arguments.length.isOdd) {
    throw ArgumentError(_usage);
  }
  final requests = <StressTraceRequest>[];
  for (var index = 2; index < arguments.length; index += 4) {
    if (arguments[index] != _scenarioOption ||
        arguments[index + 2] != _outputOption) {
      throw ArgumentError(_usage);
    }
    requests.add(
      StressTraceRequest(
        scenario: File(arguments[index + 1]),
        output: File(arguments[index + 3]),
      ),
    );
  }
  return _StressRunnerOptions(repeatCount: repeatCount, requests: requests);
}

final class _StressScenario {
  const _StressScenario(this.request, this.scenario);

  final StressTraceRequest request;
  final CompatibilityScenario scenario;
}

final class _StressRunnerOptions {
  const _StressRunnerOptions({
    required this.repeatCount,
    required this.requests,
  });

  final int repeatCount;
  final List<StressTraceRequest> requests;
}

const int _hashHexDigits = 16;
const String _outputOption = '--output';
const String _repeatCountOption = '--repeat-count';
const String _scenarioOption = '--scenario';
const String _usage =
    'Usage: stress_determinism_runner.dart --repeat-count <positive-integer> '
    '--scenario <path> --output <path> [--scenario <path> --output <path>]';

final BigInt _fnvMask = (BigInt.one << 64) - BigInt.one;
final BigInt _fnvOffsetBasis = BigInt.parse('cbf29ce484222325', radix: 16);
final BigInt _fnvPrime = BigInt.parse('100000001b3', radix: 16);

void main(List<String> arguments) {
  final status = executeStressDeterminismRunner(
    arguments,
    outputSink: stdout,
    errorSink: stderr,
  );
  if (status != 0) {
    exitCode = status;
  }
}
