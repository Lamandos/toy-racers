import '../car/car_config.dart';
import '../car/car_state.dart';
import '../math/float32.dart';
import '../track/track.dart';

/// Summary emitted by a deterministic collision resolution pass.
final class CollisionResult {
  CollisionResult({double maxImpactSpeed = 0})
    : _maxImpactSpeed = Float32.narrow(maxImpactSpeed);

  final double _maxImpactSpeed;

  double get maxImpactSpeed => _maxImpactSpeed;
}

/// Resolves ordered track and car contacts in the simulation layer.
///
/// The implementation is deferred until its full reference behavior can be
/// verified against compatibility fixtures. Flame's collision APIs do not
/// participate in this contract.
abstract interface class CollisionSystem {
  CollisionResult resolveTrackCollision({
    required CarState state,
    required CarConfig config,
    required Track track,
  });
}
