import '../math/float32.dart';
import 'track_point.dart';

/// One deterministic spawn position and heading on the starting grid.
final class StartGridPosition {
  StartGridPosition({required this.position, required double rotationDegrees})
    : rotationDegrees = Float32.narrow(rotationDegrees);

  final TrackPoint position;
  final double rotationDegrees;

  @override
  bool operator ==(Object other) =>
      other is StartGridPosition &&
      position == other.position &&
      rotationDegrees == other.rotationDegrees;

  @override
  int get hashCode => Object.hash(position, rotationDegrees);
}
