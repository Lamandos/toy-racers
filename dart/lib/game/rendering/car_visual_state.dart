import 'package:flame/components.dart';
import 'package:toy_racers/simulation.dart';

import 'race_world_projection.dart';

/// A render-only car pose calculated from two simulation observations.
///
/// It intentionally contains no velocity integration or race state. Flame
/// consumes this value between deterministic [RaceSession] fixed steps.
final class CarVisualState {
  // Keep the public parameter optional for legacy callers while retaining a
  // const constructor without sharing a mutable zero vector.
  const CarVisualState({
    required this.position,
    Vector2? velocity,
    required this.angle,
  }) : _velocity = velocity; // ignore: prefer_initializing_formals

  final Vector2 position;
  final Vector2? _velocity;
  final double angle;

  /// Returns the interpolated velocity, or zero for legacy poses.
  Vector2 get velocity => _velocity ?? Vector2.zero();

  factory CarVisualState.interpolate({
    required CarState previous,
    required CarState current,
    required double interpolationFactor,
    required RaceWorldProjection projection,
  }) {
    final factor = interpolationFactor.clamp(0.0, 1.0);
    final x = _interpolate(previous.x, current.x, factor);
    final y = _interpolate(previous.y, current.y, factor);
    final rotation = _interpolateRotation(
      previous.rotationDegrees,
      current.rotationDegrees,
      factor,
    );
    return CarVisualState(
      position: projection.positionFor(x, y),
      velocity: Vector2(
        _interpolate(previous.velocityX, current.velocityX, factor),
        -_interpolate(previous.velocityY, current.velocityY, factor),
      ),
      angle: projection.angleForDegrees(rotation),
    );
  }

  static double _interpolate(double start, double end, double factor) =>
      start + (end - start) * factor;

  static double _interpolateRotation(double start, double end, double factor) {
    final shortestDelta = ((end - start + 540) % 360) - 180;
    return start + shortestDelta * factor;
  }
}
