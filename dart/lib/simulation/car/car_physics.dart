import '../input/driver_input.dart';
import 'car_config.dart';
import 'car_state.dart';

/// Deterministic vehicle integrator used by a [RaceSession].
///
/// The concrete reference-compatible integrator is intentionally introduced in
/// the physics migration task. Keeping the contract here prevents rendering or
/// input adapters from becoming an alternative source of vehicle movement.
abstract interface class CarPhysics {
  /// Advances [state] by an explicit fixed [deltaSeconds] using [input].
  void update({
    required CarState state,
    required CarConfig config,
    required DriverInput input,
    required double deltaSeconds,
  });
}
