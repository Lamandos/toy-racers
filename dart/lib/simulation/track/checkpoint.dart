import '../math/float32.dart';
import 'track_geometry.dart';

/// An ordered gate that must be crossed in its forward direction.
final class Checkpoint {
  Checkpoint({
    required this.order,
    required this.gate,
    required double forwardX,
    required double forwardY,
  }) : forwardX = Float32.narrow(forwardX),
       forwardY = Float32.narrow(forwardY) {
    if (order < 0) {
      throw ArgumentError.value(order, 'order', 'must not be negative');
    }
    if (this.forwardX == 0 && this.forwardY == 0) {
      throw ArgumentError('Checkpoint forward direction must not be zero.');
    }
  }

  final int order;
  final TrackSegment gate;
  final double forwardX;
  final double forwardY;

  @override
  bool operator ==(Object other) =>
      other is Checkpoint &&
      order == other.order &&
      gate == other.gate &&
      forwardX == other.forwardX &&
      forwardY == other.forwardY;

  @override
  int get hashCode => Object.hash(order, gate, forwardX, forwardY);
}
