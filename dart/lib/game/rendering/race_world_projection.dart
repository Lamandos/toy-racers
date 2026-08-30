import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:toy_racers/simulation.dart';

/// Converts the simulation's upward-positive coordinates to Flame coordinates.
///
/// Simulation values remain untouched. This projection exists exclusively so
/// presentation components can draw an immutable [Track] and its car states
/// in Flutter's downward-positive canvas space.
final class RaceWorldProjection {
  RaceWorldProjection(this.worldBounds);

  final TrackRectangle worldBounds;

  Vector2 positionFor(double simulationX, double simulationY) =>
      Vector2(simulationX, worldBounds.maxY - simulationY);

  Rect rectangleFor(TrackRectangle rectangle) => Rect.fromLTWH(
    rectangle.x,
    worldBounds.maxY - rectangle.maxY,
    rectangle.width,
    rectangle.height,
  );

  double angleForDegrees(double simulationDegrees) {
    final normalizedDegrees = simulationDegrees % 360;
    return -(normalizedDegrees < 0
            ? normalizedDegrees + 360
            : normalizedDegrees) *
        math.pi /
        180;
  }
}
