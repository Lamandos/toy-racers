import 'dart:ui';

import 'package:flame/components.dart';
import 'package:toy_racers/simulation.dart';

import '../rendering/race_world_projection.dart';
import '../rendering/raster_asset_loader.dart';

/// Draws an authored track image with geometry as the custom-track fallback.
final class TrackComponent extends Component {
  TrackComponent({required this.track, required this.projection})
    : super(priority: 0);

  final Track track;
  final RaceWorldProjection projection;
  Image? _image;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final assetPath = _assetPathFor(track);
    if (assetPath != null) {
      _image = await RasterAssetLoader.load(assetPath);
    }
  }

  @override
  void onRemove() {
    _image?.dispose();
    _image = null;
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    final image = _image;
    if (image == null) {
      _renderProceduralTrack(canvas);
      return;
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      projection.rectangleFor(track.worldBounds),
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  void _renderProceduralTrack(Canvas canvas) {
    canvas.drawRect(
      projection.rectangleFor(track.worldBounds),
      Paint()..color = _surfaceColor(track.backgroundSurface),
    );
    final outerRoad = track.roadOuter;
    final innerRoad = track.roadInner;
    if (outerRoad == null || innerRoad == null) {
      canvas.drawRect(
        projection.rectangleFor(track.outerBoundary),
        Paint()..color = _asphaltColor,
      );
      _renderSurfaceRegions(canvas);
    } else {
      _renderSurfaceRegions(canvas);
      canvas.drawPath(_polygonPath(outerRoad), Paint()..color = _asphaltColor);
      canvas.drawPath(
        _polygonPath(innerRoad),
        Paint()..color = _surfaceColor(track.backgroundSurface),
      );
    }
    _renderObstacles(canvas);
  }

  void _renderSurfaceRegions(Canvas canvas) {
    for (final region in track.surfaceRegions) {
      canvas.drawRect(
        projection.rectangleFor(region.bounds),
        Paint()..color = _surfaceColor(region.surface),
      );
    }
  }

  void _renderObstacles(Canvas canvas) {
    final obstaclePaint = Paint()..color = _obstacleColor;
    for (final obstacle in track.innerObstacles) {
      canvas.drawRect(projection.rectangleFor(obstacle), obstaclePaint);
    }
    for (final shape in track.collisionShapes) {
      switch (shape) {
        case TrackCircle():
          final center = projection.positionFor(shape.center.x, shape.center.y);
          canvas.drawCircle(
            Offset(center.x, center.y),
            shape.radius,
            obstaclePaint,
          );
        case TrackPolygon():
          canvas.drawPath(_polygonPath(shape), obstaclePaint);
      }
    }
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

  String? _assetPathFor(Track value) => switch (value.id) {
    'track-01' => 'assets/tracks/track_01.png',
    'track-02' => 'assets/tracks/track_02.png',
    _ => null,
  };

  static const Color _asphaltColor = Color(0xff5b616a);
  static const Color _obstacleColor = Color(0xff8c6241);
}
