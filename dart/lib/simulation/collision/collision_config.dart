import '../math/float32.dart';

/// Tuning shared by deterministic track and car collision response.
final class CollisionConfig {
  CollisionConfig({
    double wallSpeedRetention = 0.65,
    double carRestitution = 0.15,
    double maxCarImpulse = 8,
  }) : wallSpeedRetention = Float32.narrow(wallSpeedRetention),
       carRestitution = Float32.narrow(carRestitution),
       maxCarImpulse = Float32.narrow(maxCarImpulse) {
    if (this.wallSpeedRetention < 0 || this.wallSpeedRetention > 1) {
      throw ArgumentError.value(
        wallSpeedRetention,
        'wallSpeedRetention',
        'must be in the range [0, 1]',
      );
    }
    if (this.carRestitution < 0 || this.carRestitution > 1) {
      throw ArgumentError.value(
        carRestitution,
        'carRestitution',
        'must be in the range [0, 1]',
      );
    }
    if (this.maxCarImpulse < 0) {
      throw ArgumentError.value(
        maxCarImpulse,
        'maxCarImpulse',
        'must not be negative',
      );
    }
  }

  final double wallSpeedRetention;
  final double carRestitution;
  final double maxCarImpulse;
}
