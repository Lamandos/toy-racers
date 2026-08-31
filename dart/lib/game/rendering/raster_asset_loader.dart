import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Decodes a bundled raster image for the Flame presentation layer.
final class RasterAssetLoader {
  const RasterAssetLoader._();

  static Future<ui.Image> load(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }
}
