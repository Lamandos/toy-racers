import '../car/car_state.dart';
import '../input/driver_input.dart';
import '../track/track_point.dart';
import 'ai_race_context.dart';

/// The deterministic result of one [AiDriver] update.
///
/// [requestRespawn] is consumed by the race session after the command has
/// been observed. This keeps recovery an explicit part of the simulation
/// contract instead of requiring shared mutable state between the driver and
/// session.
final class AiDriverDecision {
  AiDriverDecision({required PlayerInput input, this.requestRespawn = false})
    : input = DriverInput.from(input);

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

/// Optional route-awareness capability used when saving AI recovery states.
///
/// Keeping this capability separate preserves source compatibility for
/// existing [AiDriver] implementations that only provide [AiDriver.update].
abstract interface class RouteAwareAiDriver {
  /// Whether [carState] is aligned closely enough with this driver's route to
  /// become a valid recovery position.
  bool isFacingRoute(CarState carState);
}

/// Optional state-reset capability used after an AI respawn.
///
/// Stateful drivers can clear recovery timers and retarget their route after
/// the session restores the car. Stateless drivers do not need to implement
/// this capability.
abstract interface class ResettableAiDriver {
  void reset(TrackPoint restoredPosition);
}
