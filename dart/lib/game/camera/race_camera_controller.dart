import 'dart:ui';

import 'package:flame/components.dart';

/// Keeps the Flame camera centred on the rendered player car inside the track.
final class RaceCameraController {
  RaceCameraController({
    this.visibleWorldWidth = 27,
    this.visibleWorldHeight = 18,
  }) {
    if (visibleWorldWidth <= 0 || visibleWorldHeight <= 0) {
      throw ArgumentError('Camera viewport dimensions must be positive.');
    }
  }

  final double visibleWorldWidth;
  final double visibleWorldHeight;

  void configure(CameraComponent camera) {
    camera.viewfinder.visibleGameSize = Vector2(
      visibleWorldWidth,
      visibleWorldHeight,
    );
  }

  void follow({
    required CameraComponent camera,
    required Vector2 visualPosition,
    required Rect worldBounds,
  }) {
    camera.viewfinder.position = Vector2(
      _boundedAxis(
        visualPosition.x,
        worldBounds.left,
        worldBounds.right,
        visibleWorldWidth,
      ),
      _boundedAxis(
        visualPosition.y,
        worldBounds.top,
        worldBounds.bottom,
        visibleWorldHeight,
      ),
    );
  }

  double _boundedAxis(
    double value,
    double minimum,
    double maximum,
    double span,
  ) {
    if (maximum - minimum <= span) {
      return (minimum + maximum) / 2;
    }
    return value.clamp(minimum + span / 2, maximum - span / 2);
  }
}
