import '../math/float32.dart';

/// An immutable point in world coordinates, where positive Y points upward.
final class TrackPoint {
  TrackPoint(double x, double y) : x = Float32.narrow(x), y = Float32.narrow(y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is TrackPoint && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}
