import '../car/car_config.dart';
import '../car/car_state.dart';
import '../math/float32.dart';
import 'surface_type.dart';

/// Mutable, per-car surface state that belongs to the simulation rather than rendering.
final class SurfaceSpeedState {
  SurfaceSpeedState({double speedMultiplier = 1})
    : _speedMultiplier = Float32.narrow(speedMultiplier) {
    if (_speedMultiplier < 0 || _speedMultiplier > 1) {
      throw ArgumentError.value(
        speedMultiplier,
        'speedMultiplier',
        'must be in the range [0, 1]',
      );
    }
  }

  double _speedMultiplier;

  double get speedMultiplier => _speedMultiplier;
  set speedMultiplier(double value) {
    final narrowed = Float32.narrow(value);
    if (narrowed < 0 || narrowed > 1) {
      throw ArgumentError.value(
        value,
        'speedMultiplier',
        'must be in the range [0, 1]',
      );
    }
    _speedMultiplier = narrowed;
  }
}

/// Applies the reference-compatible surface response after each car update.
abstract interface class SurfaceSpeedSystem {
  void update({
    required CarState carState,
    required CarConfig carConfig,
    required SurfaceSpeedState surfaceState,
    required SurfaceType surface,
    required double deltaSeconds,
  });
}
