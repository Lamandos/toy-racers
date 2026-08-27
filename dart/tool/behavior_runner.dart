import 'dart:io';

import 'package:toy_racers/simulation.dart';

/// Fixed physical timestep required by the shared behavioral contract.
final double fixedBehaviorTimestep = Float32.divide(1, 60);

/// Replays one scenario and assembles its normalized schema-v3 trace.
final class BehaviorRunner {
  BehaviorRunner({
    CompatibilityScenarioParser? parser,
    BehaviorSimulationFactory? simulationFactory,
  }) : _parser = parser ?? const CompatibilityScenarioParser(),
       _simulationFactory = simulationFactory ?? createCompatibilitySimulation;

  final CompatibilityScenarioParser _parser;
  final BehaviorSimulationFactory _simulationFactory;

  /// Parses, replays, and returns exactly one scenario from [scenarioFile].
  CompatibilityTrace run(File scenarioFile) {
    final document = _parser.parseScenarioDocument(
      scenarioFile.readAsStringSync(),
      inputScriptSource: (filename) => _readInputScript(scenarioFile, filename),
    );
    if (document.scenarios.length != 1) {
      throw ArgumentError(
        'A behavior runner input must contain exactly one scenario.',
      );
    }
    return replay(document.scenarios.single);
  }

  /// Replays a parsed scenario through the configured pure-Dart simulation.
  CompatibilityTrace replay(CompatibilityScenario scenario) {
    final simulation = _simulationFactory(scenario);
    simulation.applyInitialStates(scenario.initialStates);
    final samples = <CompatibilityTraceSample>[];
    _addStartSamples(simulation, scenario, samples);
    _addSimulationSamples(simulation, scenario, samples);
    return CompatibilityTrace(
      scenarioId: scenario.id,
      seed: scenario.seed,
      samples: samples,
    );
  }

  String _readInputScript(File scenarioFile, String filename) {
    final script = File(
      '${scenarioFile.parent.path}${Platform.pathSeparator}$filename',
    );
    return script.readAsStringSync();
  }

  void _addStartSamples(
    BehaviorSimulation simulation,
    CompatibilityScenario scenario,
    List<CompatibilityTraceSample> samples,
  ) {
    if (scenario.tags.contains(_stateMachineTag)) {
      _addLifecycleSamples(simulation, samples);
      return;
    }
    _addSample(samples, _countdownLabel, 0, simulation.start());
    _addSample(samples, _racingLabel, 0, simulation.finishCountdown());
  }

  void _addLifecycleSamples(
    BehaviorSimulation simulation,
    List<CompatibilityTraceSample> samples,
  ) {
    _addSample(samples, _loadingLabel, 0, simulation.snapshot);
    _addSample(samples, _readyLabel, 0, simulation.markReadyForLifecycle());
    _addSample(
      samples,
      _countdownLabel,
      0,
      simulation.startCountdownForLifecycle(),
    );
    _addSample(
      samples,
      _countdownLabel,
      0,
      simulation.advanceCountdown(_countdownSampleSeconds),
    );
    _addSample(
      samples,
      _countdownLabel,
      0,
      simulation.advanceCountdown(_countdownSampleSeconds),
    );
    _addSample(
      samples,
      _countdownLabel,
      0,
      simulation.advanceCountdown(fixedBehaviorTimestep),
    );
    _addSample(samples, _racingLabel, 0, simulation.finishCountdown());
  }

  void _addSimulationSamples(
    BehaviorSimulation simulation,
    CompatibilityScenario scenario,
    List<CompatibilityTraceSample> samples,
  ) {
    var raceFinished = false;
    var previousPlayer = _player(simulation.snapshot);
    for (var tick = 1; tick <= scenario.ticks; tick++) {
      final snapshot = simulation.advance(
        input: DriverInput.from(scenario.inputForTick(tick)),
        deltaSeconds: fixedBehaviorTimestep,
      );
      final finishedThisTick =
          snapshot.raceState == _finishedState && !raceFinished;
      if (_shouldSample(tick, scenario, finishedThisTick)) {
        _addSample(samples, _simulationLabel, tick, snapshot);
      }
      if (scenario.tags.contains(_eventSnapshotsTag)) {
        _addEventSamples(samples, tick, previousPlayer, snapshot);
      }
      previousPlayer = _player(snapshot);
      raceFinished = raceFinished || finishedThisTick;
    }
  }

  bool _shouldSample(
    int tick,
    CompatibilityScenario scenario,
    bool finishedThisTick,
  ) =>
      tick == 1 ||
      tick % scenario.snapshotIntervalTicks == 0 ||
      tick == scenario.ticks ||
      finishedThisTick;

  void _addEventSamples(
    List<CompatibilityTraceSample> samples,
    int tick,
    CompatibilityParticipantSnapshot previousPlayer,
    CompatibilitySnapshot snapshot,
  ) {
    final currentPlayer = _player(snapshot);
    if (currentPlayer.checkpoint > previousPlayer.checkpoint) {
      _addSample(samples, _checkpointLabel, tick, snapshot);
    }
    if (currentPlayer.lap > previousPlayer.lap) {
      _addSample(samples, _lapLabel, tick, snapshot);
    }
    if (currentPlayer.finished && !previousPlayer.finished) {
      _addSample(samples, _finishLabel, tick, snapshot);
    }
  }

  CompatibilityParticipantSnapshot _player(CompatibilitySnapshot snapshot) =>
      snapshot.participants.firstWhere(
        (participant) => participant.id == _playerId,
      );

  void _addSample(
    List<CompatibilityTraceSample> samples,
    String label,
    int tick,
    CompatibilitySnapshot snapshot,
  ) {
    samples.add(
      CompatibilityTraceSample(label: label, tick: tick, snapshot: snapshot),
    );
  }

  static const String _checkpointLabel = 'checkpoint';
  static const String _countdownLabel = 'countdown';
  static const double _countdownSampleSeconds = 1;
  static const String _eventSnapshotsTag = 'event-snapshots';
  static const String _finishLabel = 'finish';
  static const String _finishedState = 'finished';
  static const String _lapLabel = 'lap';
  static const String _loadingLabel = 'loading';
  static const String _playerId = 'player';
  static const String _racingLabel = 'racing';
  static const String _readyLabel = 'ready';
  static const String _simulationLabel = 'simulation';
  static const String _stateMachineTag = 'state-machine';
}

/// Factory function type used to replace the simulation during migration.
typedef BehaviorSimulationFactory = BehaviorSimulation Function(
  CompatibilityScenario scenario,
);

/// Parsed command-line file locations for [BehaviorRunner].
final class BehaviorRunnerOptions {
  BehaviorRunnerOptions({required this.scenario, required this.output});

  final File scenario;
  final File output;

  static BehaviorRunnerOptions parse(List<String> arguments) {
    final values = <String, String>{};
    for (var index = 0; index < arguments.length; index += 2) {
      final name = arguments[index];
      if (!_optionNames.contains(name)) {
        throw ArgumentError('Unknown option: $name');
      }
      final value = index + 1 < arguments.length ? arguments[index + 1] : null;
      if (value == null || value.startsWith('--')) {
        throw ArgumentError('Missing value for $name');
      }
      if (values.containsKey(name)) {
        throw ArgumentError('Option may only be supplied once: $name');
      }
      values[name] = value;
    }
    return BehaviorRunnerOptions(
      scenario: File(_requiredValue(values, _scenarioOption)),
      output: File(_requiredValue(values, _outputOption)),
    );
  }

  static String _requiredValue(Map<String, String> values, String name) =>
      values[name] ?? (throw ArgumentError('Missing $name'));

  static const String _outputOption = '--output';
  static const String _scenarioOption = '--scenario';
  static const Set<String> _optionNames = <String>{
    _scenarioOption,
    _outputOption,
  };
}

/// Executes the command and returns a process-compatible status code.
int executeBehaviorRunner(List<String> arguments, {IOSink? errorSink}) {
  try {
    final options = BehaviorRunnerOptions.parse(arguments);
    final trace = BehaviorRunner().run(options.scenario);
    options.output.parent.createSync(recursive: true);
    options.output.writeAsStringSync(CompatibilityTraceJson.encode(trace));
    return 0;
  } on Object catch (error) {
    errorSink?.writeln('Behavior runner failed: $error');
    return 1;
  }
}

void main(List<String> arguments) {
  final status = executeBehaviorRunner(arguments, errorSink: stderr);
  if (status != 0) {
    exitCode = status;
  }
}
