import 'dart:ui';

import 'package:flame/components.dart';
import 'package:toy_racers/simulation.dart';

import '../rendering/race_world_projection.dart';
import '../rendering/raster_asset_loader.dart';

/// Draws the authored track image; collision remains entirely in simulation.
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
  void render(Canvas canvas) {
    final image = _image;
    if (image == null) {
      canvas.drawRect(
        projection.rectangleFor(track.worldBounds),
        Paint()..color = const Color(0xff10141d),
      );
      return;
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      projection.rectangleFor(track.worldBounds),
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  String? _assetPathFor(Track value) => switch (value.id) {
    'track-01' => 'assets/tracks/track_01.png',
    'track-02' => 'assets/tracks/track_02.png',
    _ => null,
  };
}
