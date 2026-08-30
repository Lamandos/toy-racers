import 'dart:ui';

import 'package:flame/components.dart';
import 'package:toy_racers/simulation.dart';

import '../rendering/race_world_projection.dart';

/// Draws immutable track geometry; collision remains entirely in simulation.
final class TrackComponent extends Component {
  TrackComponent({required this.track, required this.projection})
    : super(priority: 0);

  final Track track;
  final RaceWorldProjection projection;

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      projection.rectangleFor(track.worldBounds),
      Paint()..color = _surfaceColor(track.backgroundSurface),
    );
    for (final region in track.surfaceRegions) {
      canvas.drawRect(
        projection.rectangleFor(region.bounds),
        Paint()..color = _surfaceColor(region.surface),
      );
    }
    final outerRoad = track.roadOuter;
    final innerRoad = track.roadInner;
    if (outerRoad != null && innerRoad != null) {
      canvas.drawPath(_polygonPath(outerRoad), Paint()..color = _asphaltColor);
      canvas.drawPath(
        _polygonPath(innerRoad),
        Paint()..color = _surfaceColor(track.backgroundSurface),
      );
      return;
    }
    canvas.drawRect(
      projection.rectangleFor(track.outerBoundary),
      Paint()..color = _asphaltColor,
    );
  }

  Path _polygonPath(TrackPolygon polygon) {
    final first = projection.positionFor(
      polygon.vertices.first.x,
      polygon.vertices.first.y,
    );
    final path = Path()..moveTo(first.x, first.y);
    for (final vertex in polygon.vertices.skip(1)) {
      final point = projection.positionFor(vertex.x, vertex.y);
      path.lineTo(point.x, point.y);
    }
    return path..close();
  }

  Color _surfaceColor(SurfaceType surface) => switch (surface) {
    SurfaceType.asphalt => _asphaltColor,
    SurfaceType.parquet => const Color(0xffd2b48c),
    SurfaceType.tile => const Color(0xffb9d1d8),
    SurfaceType.grass => const Color(0xff76a957),
    SurfaceType.boost => const Color(0xffd6b640),
    SurfaceType.oil => const Color(0xff594d58),
  };

  static const Color _asphaltColor = Color(0xff5b616a);
}
