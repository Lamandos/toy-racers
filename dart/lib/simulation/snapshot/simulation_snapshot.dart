import '../math/float32.dart';
import '../race/race_phase.dart';

/// Immutable observation emitted by a deterministic simulation operation.
///
/// `CompatibilitySnapshot` and `CompatibilityTraceJson` provide the complete
/// schema-v2/v3 compatibility output without exposing rendering, device, or
/// platform state to the simulation.
final class SimulationSnapshot {
  SimulationSnapshot({
    required this.simulationTick,
    required this.racePhase,
    required double countdownRemainingSeconds,
    required double elapsedSimulationTime,
  }) : countdownRemainingSeconds = Float32.narrow(countdownRemainingSeconds),
       elapsedSimulationTime = Float32.narrow(elapsedSimulationTime) {
    if (simulationTick < 0) {
      throw ArgumentError.value(
        simulationTick,
        'simulationTick',
        'must not be negative',
      );
    }
    if (this.countdownRemainingSeconds < 0) {
      throw ArgumentError.value(
        countdownRemainingSeconds,
        'countdownRemainingSeconds',
        'must not be negative',
      );
    }
    if (this.elapsedSimulationTime < 0) {
      throw ArgumentError.value(
        elapsedSimulationTime,
        'elapsedSimulationTime',
        'must not be negative',
      );
    }
  }

  final int simulationTick;
  final RacePhase racePhase;
  final double countdownRemainingSeconds;
  final double elapsedSimulationTime;
}
