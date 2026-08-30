import 'package:flame/components.dart';
import 'package:toy_racers/simulation.dart';

import 'race_world_projection.dart';

/// A render-only car pose calculated from two simulation observations.
///
/// It intentionally contains no velocity integration or race state. Flame
/// consumes this value between deterministic [RaceSession] fixed steps.
final class CarVisualState {
  const CarVisualState({required this.position, required this.angle});

  final Vector2 position;
  final double angle;

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
