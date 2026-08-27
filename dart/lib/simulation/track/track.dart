import '../math/float32.dart';
import '../surface/surface_type.dart';
import 'checkpoint.dart';
import 'start_grid_position.dart';
import 'track_geometry.dart';
import 'track_point.dart';

/// Immutable simulation data for one complete race track.
final class Track {
  Track({
    required String id,
    required String name,
    required this.worldBounds,
    required this.cameraBounds,
    required this.outerBoundary,
    Iterable<TrackRectangle> innerObstacles = const <TrackRectangle>[],
    Iterable<TrackCollisionShape> collisionShapes =
        const <TrackCollisionShape>[],
    required this.backgroundSurface,
    Iterable<SurfaceRegion> surfaceRegions = const <SurfaceRegion>[],
    this.roadOuter,
    this.roadInner,
    required this.startLine,
    required Iterable<Checkpoint> checkpoints,
    required Iterable<StartGridPosition> startGrid,
    required Iterable<TrackPoint> racingLine,
    double racingLineWaypointRadius = 3,
  }) : id = _requireText(id, 'id'),
       name = _requireText(name, 'name'),
       innerObstacles = List<TrackRectangle>.unmodifiable(innerObstacles),
       collisionShapes = List<TrackCollisionShape>.unmodifiable(
         collisionShapes,
       ),
       surfaceRegions = List<SurfaceRegion>.unmodifiable(surfaceRegions),
       checkpoints = List<Checkpoint>.unmodifiable(checkpoints),
       startGrid = List<StartGridPosition>.unmodifiable(startGrid),
       racingLine = List<TrackPoint>.unmodifiable(racingLine),
       racingLineWaypointRadius = Float32.narrow(racingLineWaypointRadius) {
    if (!worldBounds.containsRectangle(cameraBounds)) {
      throw ArgumentError('Camera bounds must be inside world bounds.');
    }
    if (!worldBounds.containsRectangle(outerBoundary)) {
      throw ArgumentError('Outer boundary must be inside world bounds.');
    }
    if (!innerObstacles.every(outerBoundary.containsRectangle)) {
      throw ArgumentError('Inner obstacles must be inside the outer boundary.');
    }
    if (!surfaceRegions.every(
      (region) => worldBounds.containsRectangle(region.bounds),
    )) {
      throw ArgumentError('Surface regions must be inside world bounds.');
    }
    if (!innerObstacles.every(worldBounds.containsRectangle)) {
      throw ArgumentError('Collision obstacles must be inside world bounds.');
    }
    if (!outerBoundary.containsRectangle(startLine.bounds)) {
      throw ArgumentError('Start line must be inside the outer boundary.');
    }
    if (checkpoints.isEmpty) {
      throw ArgumentError('Track must have checkpoints.');
    }
    if (!_hasOrderedCheckpoints(this.checkpoints)) {
      throw ArgumentError('Checkpoints must use contiguous ordered indices.');
    }
    if (!this.checkpoints.every(
      (checkpoint) =>
          worldBounds.containsPoint(checkpoint.gate.start) &&
          worldBounds.containsPoint(checkpoint.gate.end),
    )) {
      throw ArgumentError('Checkpoint gates must be inside world bounds.');
    }
    if (this.startGrid.isEmpty) {
      throw ArgumentError('Track must have start positions.');
    }
    if (!this.startGrid.every(
      (position) => worldBounds.containsPoint(position.position),
    )) {
      throw ArgumentError('Start positions must be inside world bounds.');
    }
    if (this.racingLine.length < _minimumRacingLinePoints) {
      throw ArgumentError.value(
        this.racingLine.length,
        'racingLine',
        'must contain at least $_minimumRacingLinePoints points',
      );
    }
    if (!this.racingLine.every(worldBounds.containsPoint)) {
      throw ArgumentError('Racing line must be inside world bounds.');
    }
    if (this.racingLineWaypointRadius <= 0) {
      throw ArgumentError.value(
        racingLineWaypointRadius,
        'racingLineWaypointRadius',
        'must be greater than zero',
      );
    }
    if ((roadOuter == null) != (roadInner == null)) {
      throw ArgumentError('Tiled road contours must be provided together.');
    }
  }

  static const int _minimumRacingLinePoints = 3;

  final String id;
  final String name;
  final TrackRectangle worldBounds;
  final TrackRectangle cameraBounds;
  final TrackRectangle outerBoundary;
  final List<TrackRectangle> innerObstacles;
  final List<TrackCollisionShape> collisionShapes;
  final SurfaceType backgroundSurface;
  final List<SurfaceRegion> surfaceRegions;
  final TrackPolygon? roadOuter;
  final TrackPolygon? roadInner;
  final StartLine startLine;
  final List<Checkpoint> checkpoints;
  final List<StartGridPosition> startGrid;
  final List<TrackPoint> racingLine;
  final double racingLineWaypointRadius;

  /// Returns the surface selected by the reference track rules at [point].
  SurfaceType surfaceAt(TrackPoint point) =>
      surfaceAtCoordinates(point.x, point.y);

  /// Returns the surface selected by the reference track rules at [x], [y].
  SurfaceType surfaceAtCoordinates(double x, double y) {
    final pointX = Float32.narrow(x);
    final pointY = Float32.narrow(y);
    if (innerObstacles.any((bounds) => bounds.contains(pointX, pointY))) {
      return backgroundSurface;
    }
    final insideTiledRoad =
        roadOuter?.contains(pointX, pointY) == true &&
        roadInner?.contains(pointX, pointY) == false;
    if (insideTiledRoad) {
      return SurfaceType.asphalt;
    }
    for (var index = surfaceRegions.length - 1; index >= 0; index--) {
      final region = surfaceRegions[index];
      if (region.bounds.contains(pointX, pointY)) {
        return region.surface;
      }
    }
    return backgroundSurface;
  }

  static bool _hasOrderedCheckpoints(List<Checkpoint> checkpoints) {
    for (var index = 0; index < checkpoints.length; index++) {
      if (checkpoints[index].order != index) {
        return false;
      }
    }
    return true;
  }

  static String _requireText(String value, String name) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, name, 'must not be blank');
    }
    return value;
  }
}

/// An ordered rectangular override of a track's background surface.
final class SurfaceRegion {
  const SurfaceRegion({required this.bounds, required this.surface});

  final TrackRectangle bounds;
  final SurfaceType surface;
}

/// The gate that completes a lap when crossed in its forward direction.
final class StartLine {
  StartLine({
    required this.bounds,
    required double forwardX,
    required double forwardY,
  }) : forwardX = Float32.narrow(forwardX),
       forwardY = Float32.narrow(forwardY) {
    if (this.forwardX == 0 && this.forwardY == 0) {
      throw ArgumentError('Start line forward direction must not be zero.');
    }
  }

  final TrackRectangle bounds;
  final double forwardX;
  final double forwardY;
}
