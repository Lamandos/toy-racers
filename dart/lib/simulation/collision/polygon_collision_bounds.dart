import 'dart:math' as math;

import '../math/float32.dart';
import '../track/track_geometry.dart';

/// Conservative bounds of the *rounded* edge projection used by the resolver.
/// A clamped fraction lies in [0, 1]. Binary32 multiplication and addition
/// are monotone, so both rounded endpoints bound every projected point.
final class PolygonCollisionBounds {
  PolygonCollisionBounds(TrackPolygon polygon) {
    for (var index = 0; index < polygon.vertices.length; index++) {
      final start = polygon.vertices[index];
      final end = polygon.vertices[(index + 1) % polygon.vertices.length];
      // Leave extreme/degenerate geometry to the reference narrow phase,
      // including its validation and exceptional arithmetic behavior.
      if (start.x.abs() > 1e6 ||
          start.y.abs() > 1e6 ||
          end.x.abs() > 1e6 ||
          end.y.abs() > 1e6 ||
          (end.x - start.x).abs() + (end.y - start.y).abs() < 1e-10) {
        _usable = false;
        return;
      }
      final projectedX = Float32.add(start.x, Float32.subtract(end.x, start.x));
      final projectedY = Float32.add(start.y, Float32.subtract(end.y, start.y));
      _minX = math.min(_minX, math.min(start.x, projectedX));
      _maxX = math.max(_maxX, math.max(start.x, projectedX));
      _minY = math.min(_minY, math.min(start.y, projectedY));
      _maxY = math.max(_maxY, math.max(start.y, projectedY));
    }
  }

  double _minX = double.infinity;
  double _maxX = double.negativeInfinity;
  double _minY = double.infinity;
  double _maxY = double.negativeInfinity;
  bool _usable = true;

  /// Only used after the original point-in-polygon check returned false.
  bool excludes(double x, double y, double radius) {
    if (!_usable || x.abs() > 1e6 || y.abs() > 1e6 || radius < 1e-10) {
      return false;
    }
    final dx = Float32.subtract(x, x.clamp(_minX, _maxX));
    final dy = Float32.subtract(y, y.clamp(_minY, _maxY));
    final minimumDistance = Float32.narrow(math.sqrt(dx * dx + dy * dy));
    return minimumDistance >= radius;
  }
}
