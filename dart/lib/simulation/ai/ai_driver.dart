import '../car/car_state.dart';
import '../input/driver_input.dart';

/// Produces a deterministic driving command for a non-player participant.
///
/// Drivers read simulation state and return controls. They must not mutate a
/// car directly, use wall-clock time, or depend on presentation state.
abstract interface class AiDriver {
  DriverInput update({
    required CarState carState,
    required double deltaSeconds,
  });
}
