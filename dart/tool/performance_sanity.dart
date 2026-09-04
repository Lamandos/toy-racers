import 'dart:convert';
import 'dart:io';

import 'package:toy_racers/simulation.dart';

/// Configuration for the repeatable headless long-race sanity check.
final class PerformanceSanityOptions {
  const PerformanceSanityOptions({
    this.warmupTicks = 500,
    this.measuredTicks = 5000,
    this.sampleEveryTicks = 500,
    this.allowedGrowthMiB = 64,
    this.stateOnly = false,
    this.reportOutput,
    this.stateOutput,
  });

  final int warmupTicks;
  final int measuredTicks;
  final int sampleEveryTicks;
  final int allowedGrowthMiB;
  final bool stateOnly;
  final File? reportOutput;
  final File? stateOutput;

  int get allowedGrowthBytes => allowedGrowthMiB * _bytesPerMiB;

  static PerformanceSanityOptions parse(List<String> arguments) {
    final values = <String, String>{};
    var stateOnly = false;
    for (var index = 0; index < arguments.length; index++) {
      final name = arguments[index];
      if (name == _stateOnlyOption) {
        stateOnly = true;
        continue;
      }
      if (!_valuedOptions.contains(name)) {
        throw ArgumentError('Unknown option: $name');
      }
      final value = index + 1 < arguments.length ? arguments[++index] : null;
      if (value == null || value.startsWith('--')) {
        throw ArgumentError('Missing value for $name');
      }
      if (values.containsKey(name)) {
        throw ArgumentError('Option may only be supplied once: $name');
      }
      values[name] = value;
    }
    return PerformanceSanityOptions(
      warmupTicks: _integer(values, _warmupOption, 500, minimum: 0),
      measuredTicks: _integer(values, _measuredOption, 5000),
      sampleEveryTicks: _integer(values, _sampleEveryOption, 500),
      allowedGrowthMiB: _integer(values, _allowedGrowthOption, 64),
      stateOnly: stateOnly,
      reportOutput: _file(values[_reportOutputOption]),
      stateOutput: _file(values[_stateOutputOption]),
    );
  }

  static int _integer(
    Map<String, String> values,
    String name,
    int defaultValue, {
    int minimum = 1,
  }) {
    final source = values[name];
    final value = source == null ? defaultValue : int.tryParse(source);
    if (value == null || value < minimum) {
      throw ArgumentError.value(source, name, 'must be at least $minimum');
    }
    return value;
  }

  static File? _file(String? path) => path == null ? null : File(path);

  static const int _bytesPerMiB = 1024 * 1024;
  static const String _allowedGrowthOption = '--allowed-growth-mib';
  static const String _measuredOption = '--measured-ticks';
  static const String _reportOutputOption = '--report-output';
  static const String _sampleEveryOption = '--sample-every-ticks';
  static const String _stateOnlyOption = '--state-only';
  static const String _stateOutputOption = '--state-output';
  static const String _warmupOption = '--warmup-ticks';
  static const Set<String> _valuedOptions = <String>{
    _allowedGrowthOption,
    _measuredOption,
    _reportOutputOption,
    _sampleEveryOption,
    _stateOutputOption,
    _warmupOption,
  };
}

/// Results from a fixed-input race without compatibility trace accumulation.
final class PerformanceSanityReport {
  const PerformanceSanityReport({
    required this.options,
    required this.elapsed,
    required this.rssSamplesBytes,
    required this.collectionBounds,
    required this.state,
  });

  final PerformanceSanityOptions options;
  final Duration elapsed;
  final List<int> rssSamplesBytes;
  final Map<String, int> collectionBounds;
  final Map<String, Object> state;

  int get measuredTicksPerSecond => elapsed.inMicroseconds == 0
      ? 0
      : options.measuredTicks *
            Duration.microsecondsPerSecond ~/
            elapsed.inMicroseconds;

  int get laterHalfPeakGrowthBytes {
    if (rssSamplesBytes.length < 2) {
      return 0;
    }
    final split = (rssSamplesBytes.length / 2).ceil();
    final earlyPeak = rssSamplesBytes.take(split).reduce(_maximum);
    final laterPeak = rssSamplesBytes.skip(split).reduce(_maximum);
    final growth = laterPeak - earlyPeak;
    return growth > 0 ? growth : 0;
  }

  bool get memoryStable =>
      laterHalfPeakGrowthBytes <= options.allowedGrowthBytes;

  Map<String, Object> toJson() => <String, Object>{
    'schemaVersion': 1,
    'result': memoryStable ? 'PASS' : 'FAIL',
    'warmupTicks': options.warmupTicks,
    'measuredTicks': options.measuredTicks,
    'sampleEveryTicks': options.sampleEveryTicks,
    'elapsedMilliseconds': elapsed.inMilliseconds,
    'measuredTicksPerSecond': measuredTicksPerSecond,
    'rssSamplesBytes': rssSamplesBytes,
    'laterHalfPeakGrowthBytes': laterHalfPeakGrowthBytes,
    'allowedGrowthBytes': options.allowedGrowthBytes,
    'collectionBounds': collectionBounds,
    'stateFingerprint': state['fingerprint']!,
  };

  static int _maximum(int left, int right) => left > right ? left : right;
}

/// Runs the same six-car production simulation assembly used by the Flame game.
final class PerformanceSanityRunner {
  PerformanceSanityRunner({
    TmxSource? tmxSource,
    int Function()? rssReader,
    Stopwatch Function()? stopwatchFactory,
  }) : _tmxSource = tmxSource ?? _readTmx,
       _rssReader = rssReader ?? _currentRss,
       _stopwatchFactory = stopwatchFactory ?? Stopwatch.new;

  final TmxSource _tmxSource;
  final int Function() _rssReader;
  final Stopwatch Function() _stopwatchFactory;

  PerformanceSanityReport run(PerformanceSanityOptions options) {
    final session = _createSession(
      TrackLoader(_tmxSource).load(TrackId.livingRoom),
    );
    _startRacing(session);
    _runTicks(session, options.warmupTicks);

    final rssSamples = <int>[];
    if (!options.stateOnly) {
      rssSamples.add(_rssReader());
    }
    final stopwatch = _stopwatchFactory()..start();
    for (var tick = 1; tick <= options.measuredTicks; tick++) {
      _runTick(session);
      if (!options.stateOnly && tick % options.sampleEveryTicks == 0) {
        rssSamples.add(_rssReader());
      }
    }
    stopwatch.stop();
    if (!options.stateOnly &&
        options.measuredTicks % options.sampleEveryTicks != 0) {
      rssSamples.add(_rssReader());
    }

    return PerformanceSanityReport(
      options: options,
      elapsed: stopwatch.elapsed,
      rssSamplesBytes: List<int>.unmodifiable(rssSamples),
      collectionBounds: _collectionBounds(session),
      state: _stateDocument(session, options),
    );
  }

  void _runTicks(RaceSession session, int count) {
    for (var tick = 0; tick < count; tick++) {
      _runTick(session);
    }
  }

  void _runTick(RaceSession session) {
    final result = session.advanceFixedStep(playerInput: PlayerInput.none);
    if (result.physicalSteps != 1) {
      throw StateError(
        'Long-race simulation stopped at tick ${session.snapshot.simulationTick}.',
      );
    }
  }

  static RaceSession _createSession(Track track) {
    final playerModel = CarModel.redStripe;
    final opponents = <CarModel>[
      ...CarModel.values.where((model) => model != playerModel),
      CarModel.values.firstWhere((model) => model != playerModel),
    ];
    return RaceSession(
      track: track,
      participants: <RaceParticipant>[
        _participant('player', track.startGrid.first, playerModel),
        for (var index = 0; index < opponents.length; index++)
          _participant(
            'ai-$index',
            track.startGrid[index + 1],
            opponents[index],
            driver: ReferenceAiDriver(
              racingLine: track.racingLine,
              initialPosition: track.startGrid[index + 1].position,
              config: AiConfig(waypointRadius: track.racingLineWaypointRadius),
              racingLineBias: _racingLineBiases[index],
              track: track,
            ),
          ),
      ],
    );
  }

  static RaceParticipant _participant(
    String id,
    StartGridPosition start,
    CarModel model, {
    AiDriver? driver,
  }) => RaceParticipant(
    id: id,
    carState: CarState(
      x: start.position.x,
      y: start.position.y,
      rotationDegrees: start.rotationDegrees,
    ),
    carConfig: model.performance.applyTo(),
    aiDriver: driver,
  );

  static void _startRacing(RaceSession session) {
    session.start();
    session.advanceLifecycle(
      elapsedSeconds: session.raceState.countdownDurationSeconds,
    );
    if (session.raceState.phase != RacePhase.racing) {
      throw StateError('Performance session did not complete its countdown.');
    }
  }

  static Map<String, int> _collectionBounds(RaceSession session) {
    final participantCount = session.participants.length;
    final track = session.track;
    final maximumContactsPerCirclePass =
        2 + track.innerObstacles.length + track.collisionShapes.length;
    return <String, int>{
      'participants': participantCount,
      'opponents': participantCount - 1,
      'trackInnerObstacles': track.innerObstacles.length,
      'trackCollisionShapes': track.collisionShapes.length,
      'trackSurfaceRegions': track.surfaceRegions.length,
      'trackCheckpoints': track.checkpoints.length,
      'trackStartGridPositions': track.startGrid.length,
      'trackRacingLinePoints': track.racingLine.length,
      'maximumAiObstaclesPerDriver': participantCount - 1,
      'maximumSensorRaysPerDriver': 3,
      'maximumSensorSamplesPerRay': 20,
      'maximumCollisionCirclesPerCar': 3,
      'maximumCollisionResolutionPasses': 4,
      'maximumTrackContactsPerCar': 3 * 4 * maximumContactsPerCirclePass,
      'maximumCarCollisionPairs':
          participantCount * (participantCount - 1) ~/ 2,
      'maximumFinishResults': participantCount,
      'renderCarComponents': participantCount,
      'renderWorldChildren': participantCount + 2,
      'pendingAudioMixes': 1,
      'retainedCarStateCopiesPerParticipant': 3,
      'retainedTickHistoryEntries': 0,
    };
  }

  static Map<String, Object> _stateDocument(
    RaceSession session,
    PerformanceSanityOptions options,
  ) {
    final positions = session.participantPositions;
    final body = <String, Object>{
      'schemaVersion': 1,
      'warmupTicks': options.warmupTicks,
      'measuredTicks': options.measuredTicks,
      'simulationTick': session.snapshot.simulationTick,
      'racePhase': session.raceState.phase.name,
      'participants': <Map<String, Object>>[
        for (final participant in session.participants)
          _participantState(participant, positions[participant.id]!),
      ],
    };
    final encoded = utf8.encode(jsonEncode(body));
    return <String, Object>{...body, 'fingerprint': _fnv1a64(encoded)};
  }

  static Map<String, Object> _participantState(
    RaceParticipant participant,
    int position,
  ) => <String, Object>{
    'id': participant.id,
    'position': position,
    'car': <int>[
      Float32.bits(participant.carState.x),
      Float32.bits(participant.carState.y),
      Float32.bits(participant.carState.rotationDegrees),
      Float32.bits(participant.carState.longitudinalSpeed),
      Float32.bits(participant.carState.velocityX),
      Float32.bits(participant.carState.velocityY),
      Float32.bits(participant.carState.angularVelocity),
      Float32.bits(participant.carState.lateralSpeed),
      Float32.bits(participant.carState.driftAmount),
    ],
    'progress': <Object?>[
      participant.progress.currentCheckpointIndex,
      participant.progress.completedLaps,
      Float32.bits(participant.progress.lapStartTime),
      participant.progress.bestLapTime == null
          ? null
          : Float32.bits(participant.progress.bestLapTime!),
      Float32.bits(participant.progress.totalRaceTime),
      participant.progress.finished,
      participant.progress.finishPosition,
    ],
  };

  static String _fnv1a64(List<int> bytes) {
    var hash = _fnvOffsetBasis;
    for (final byte in bytes) {
      hash ^= BigInt.from(byte);
      hash = (hash * _fnvPrime) & _fnvMask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  static int _currentRss() => ProcessInfo.currentRss;

  static String _readTmx(String assetPath) =>
      File(assetPath).readAsStringSync();

  static const List<double> _racingLineBiases = <double>[
    -0.36,
    0.27,
    -0.16,
    0.39,
    -0.28,
  ];
  static final BigInt _fnvMask = (BigInt.one << 64) - BigInt.one;
  static final BigInt _fnvOffsetBasis = BigInt.parse(
    'cbf29ce484222325',
    radix: 16,
  );
  static final BigInt _fnvPrime = BigInt.parse('100000001b3', radix: 16);
}

int executePerformanceSanity(
  List<String> arguments, {
  IOSink? outputSink,
  IOSink? errorSink,
}) {
  try {
    final options = PerformanceSanityOptions.parse(arguments);
    final report = PerformanceSanityRunner().run(options);
    final stateJson = const JsonEncoder.withIndent('  ').convert(report.state);
    _writeOptional(options.stateOutput, '$stateJson\n');
    if (options.stateOnly) {
      outputSink?.writeln(stateJson);
      return 0;
    }
    final reportJson = const JsonEncoder.withIndent('  ')
        .convert(report.toJson());
    _writeOptional(options.reportOutput, '$reportJson\n');
    outputSink?.writeln(reportJson);
    return report.memoryStable ? 0 : 1;
  } on Object catch (error) {
    errorSink?.writeln('Performance sanity check failed: $error');
    return 1;
  }
}

void _writeOptional(File? output, String contents) {
  if (output == null) {
    return;
  }
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(contents);
}

void main(List<String> arguments) {
  final status = executePerformanceSanity(
    arguments,
    outputSink: stdout,
    errorSink: stderr,
  );
  if (status != 0) {
    exitCode = status;
  }
}
