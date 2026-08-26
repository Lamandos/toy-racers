import '../math/float32.dart';
import 'track_point.dart';

/// Immutable simulation data for a race track.
///
/// Track loading and full collision/checkpoint geometry will be added beside
/// this model. The racing line is already immutable so AI implementations
/// cannot change shared track data while a race is running.
final class Track {
  Track({
    required String id,
    required Iterable<TrackPoint> racingLine,
    double racingLineWaypointRadius = 3,
  }) : id = _requireId(id),
       racingLine = List<TrackPoint>.unmodifiable(racingLine),
       racingLineWaypointRadius = Float32.narrow(racingLineWaypointRadius) {
    if (this.racingLine.length < _minimumRacingLinePoints) {
      throw ArgumentError.value(
        this.racingLine.length,
        'racingLine',
        'must contain at least $_minimumRacingLinePoints points',
      );
    }
    if (this.racingLineWaypointRadius <= 0) {
      throw ArgumentError.value(
        racingLineWaypointRadius,
        'racingLineWaypointRadius',
        'must be greater than zero',
      );
    }
  }

  static const int _minimumRacingLinePoints = 3;

  final String id;
  final List<TrackPoint> racingLine;
  final double racingLineWaypointRadius;

  static String _requireId(String id) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be blank');
    }
    return id;
  }
}
