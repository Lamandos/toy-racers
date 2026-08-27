import '../math/float32.dart';
import 'track_point.dart';

/// An axis-aligned rectangle in binary32 world coordinates.
final class TrackRectangle {
  TrackRectangle(double x, double y, double width, double height)
    : x = Float32.narrow(x),
      y = Float32.narrow(y),
      width = Float32.narrow(width),
      height = Float32.narrow(height) {
    if (this.width <= 0) {
      throw ArgumentError.value(width, 'width', 'must be positive');
    }
    if (this.height <= 0) {
      throw ArgumentError.value(height, 'height', 'must be positive');
    }
  }

  final double x;
  final double y;
  final double width;
  final double height;

  double get maxX => Float32.add(x, width);
  double get maxY => Float32.add(y, height);

  bool containsPoint(TrackPoint point) => contains(point.x, point.y);

  bool contains(double pointX, double pointY) {
    final x = Float32.narrow(pointX);
    final y = Float32.narrow(pointY);
    return x >= this.x && x <= maxX && y >= this.y && y <= maxY;
  }

  bool containsRectangle(TrackRectangle other) =>
      other.x >= x && other.y >= y && other.maxX <= maxX && other.maxY <= maxY;

  @override
  bool operator ==(Object other) =>
      other is TrackRectangle &&
      x == other.x &&
      y == other.y &&
      width == other.width &&
      height == other.height;

  @override
  int get hashCode => Object.hash(x, y, width, height);
}

/// A non-degenerate line segment in binary32 world coordinates.
final class TrackSegment {
  TrackSegment(this.start, this.end) {
    if (start == end) {
      throw ArgumentError('Segment endpoints must be different.');
    }
  }

  final TrackPoint start;
  final TrackPoint end;

  @override
  bool operator ==(Object other) =>
      other is TrackSegment && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// A solid shape read from the Tiled `collisions` object layer.
sealed class TrackCollisionShape {
  const TrackCollisionShape();
}

/// A circular solid shape in binary32 world coordinates.
final class TrackCircle extends TrackCollisionShape {
  TrackCircle({required this.center, required double radius})
    : radius = Float32.narrow(radius) {
    if (this.radius <= 0) {
      throw ArgumentError.value(radius, 'radius', 'must be positive');
    }
  }

  final TrackPoint center;
  final double radius;

  @override
  bool operator ==(Object other) =>
      other is TrackCircle && center == other.center && radius == other.radius;

  @override
  int get hashCode => Object.hash(center, radius);
}

/// A polygonal solid or road contour.
///
/// Tiled authoring may use either winding direction. Containment uses the
/// same ray-crossing calculation and binary32 intermediate values as Kotlin.
final class TrackPolygon extends TrackCollisionShape {
  TrackPolygon(Iterable<TrackPoint> vertices)
    : vertices = List<TrackPoint>.unmodifiable(vertices) {
    if (this.vertices.length < _minimumVertices) {
      throw ArgumentError.value(
        this.vertices.length,
        'vertices',
        'must contain at least $_minimumVertices points',
      );
    }
  }

  static const int _minimumVertices = 3;

  final List<TrackPoint> vertices;

  bool contains(double pointX, double pointY) {
    final x = Float32.narrow(pointX);
    final y = Float32.narrow(pointY);
    var inside = false;
    var previous = vertices.last;
    for (final current in vertices) {
      if (_crossesRay(current, previous, x, y)) {
        inside = !inside;
      }
      previous = current;
    }
    return inside;
  }

  bool _crossesRay(
    TrackPoint current,
    TrackPoint previous,
    double x,
    double y,
  ) {
    if ((current.y > y) == (previous.y > y)) {
      return false;
    }
    final numerator = Float32.multiply(
      Float32.subtract(previous.x, current.x),
      Float32.subtract(y, current.y),
    );
    final edgeX = Float32.add(
      Float32.divide(numerator, Float32.subtract(previous.y, current.y)),
      current.x,
    );
    return x < edgeX;
  }

  @override
  bool operator ==(Object other) =>
      other is TrackPolygon && _sameVertices(other.vertices);

  bool _sameVertices(List<TrackPoint> other) {
    if (vertices.length != other.length) {
      return false;
    }
    for (var index = 0; index < vertices.length; index++) {
      if (vertices[index] != other[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(vertices);
}
