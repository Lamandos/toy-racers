import 'dart:math' as math;

import 'package:toy_racers/simulation.dart';

/// Result of advancing [FixedTimestepScheduler] for one Flame render frame.
final class FixedTimestepResult {
  const FixedTimestepResult({
    required this.physicalSteps,
    required this.interpolationFactor,
  });

  /// Number of completed fixed simulation steps during the render frame.
  final int physicalSteps;

  /// Remaining presentation time as a fraction of one fixed step.
  final double interpolationFactor;
}

/// Converts Flame render deltas into bounded fixed simulation steps.
///
/// This presentation-layer scheduler is deliberately separate from gameplay.
/// It samples Flame's variable render cadence, then invokes [onFixedStep] in
/// chronological order at the reference `1 / 60` physics interval. Gameplay
/// state remains entirely owned by [RaceSession].
final class FixedTimestepScheduler {
  double _accumulatorSeconds = 0;

  /// Discards remaining render time, for example on pause or race restart.
  void reset() => _accumulatorSeconds = 0;

  /// Narrows and caps elapsed time accepted from Flame's render loop.
  static double boundedRenderDelta(double renderDeltaSeconds) {
    if (renderDeltaSeconds.isNaN || renderDeltaSeconds <= 0) {
      return 0;
    }
    final boundedDelta = renderDeltaSeconds.isFinite
        ? math.min(renderDeltaSeconds, CarPhysics.maxFrameDeltaSeconds)
        : CarPhysics.maxFrameDeltaSeconds;
    return Float32.narrow(boundedDelta);
  }

  /// Runs all fixed simulation ticks due for racing time in a render frame.
  ///
  /// [isSimulationActive] is evaluated both before and after each step so a
  /// pause or finish never retains whole ticks for a later frame.
  FixedTimestepResult advance({
    required double simulationDeltaSeconds,
    required bool Function() isSimulationActive,
    required void Function() onFixedStep,
  }) {
    if (!isSimulationActive()) {
      reset();
      return _result(0);
    }

    _accumulatorSeconds = Float32.add(
      _accumulatorSeconds,
      Float32.narrow(simulationDeltaSeconds),
    );
    var physicalSteps = 0;
    while (_accumulatorSeconds >= CarPhysics.fixedDeltaSeconds) {
      onFixedStep();
      physicalSteps++;
      _accumulatorSeconds = Float32.subtract(
        _accumulatorSeconds,
        CarPhysics.fixedDeltaSeconds,
      );
      if (!isSimulationActive()) {
        reset();
        return _result(physicalSteps);
      }
    }
    return _result(physicalSteps);
  }

  FixedTimestepResult _result(int physicalSteps) => FixedTimestepResult(
    physicalSteps: physicalSteps,
    interpolationFactor: _accumulatorSeconds / CarPhysics.fixedDeltaSeconds,
  );
}
