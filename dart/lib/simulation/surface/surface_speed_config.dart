import '../math/float32.dart';

/// Gradual speed-limit transition between road and off-road surfaces.
final class SurfaceSpeedConfig {
  SurfaceSpeedConfig({
    double offRoadSpeedMultiplier = 0.3,
    double transitionSeconds = 3,
  }) : offRoadSpeedMultiplier = Float32.narrow(offRoadSpeedMultiplier),
       transitionSeconds = Float32.narrow(transitionSeconds) {
    if (this.offRoadSpeedMultiplier < 0 || this.offRoadSpeedMultiplier > 1) {
      throw ArgumentError.value(
        offRoadSpeedMultiplier,
        'offRoadSpeedMultiplier',
        'must be in the range [0, 1]',
      );
    }
    if (this.transitionSeconds <= 0) {
      throw ArgumentError.value(
        transitionSeconds,
        'transitionSeconds',
        'must be greater than zero',
      );
    }
  }

  final double offRoadSpeedMultiplier;
  final double transitionSeconds;
}
