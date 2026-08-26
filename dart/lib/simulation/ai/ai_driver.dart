import '../car/car_state.dart';
import '../input/driver_input.dart';
import 'ai_race_context.dart';

/// The deterministic result of one [AiDriver] update.
///
/// [requestRespawn] is consumed by the race session after the command has
/// been observed. This keeps recovery an explicit part of the simulation
/// contract instead of requiring shared mutable state between the driver and
/// session.
final class AiDriverDecision {
  AiDriverDecision({required this.input, this.requestRespawn = false});

  final DriverInput input;
  final bool requestRespawn;
}

/// Produces a deterministic driving command for a non-player participant.
///
/// Drivers read simulation state and return controls plus any deterministic
/// recovery request. They must not mutate a car directly, use wall-clock time,
/// or depend on presentation state.
abstract interface class AiDriver {
  AiDriverDecision update({
    required CarState carState,
    required double deltaSeconds,
    required AiRaceContext context,
  });
}
