import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

/// Smoothly follows the rendered player while keeping the viewport on-track.
final class RaceCameraController {
  RaceCameraController({
    this.visibleWorldWidth = 24,
    this.visibleWorldHeight = 13.5,
    this.followSpeed = 6,
    this.lookAheadDistance = 4,
    this.shakeDecaySpeed = 12,
  }) {
    if (!visibleWorldWidth.isFinite ||
        !visibleWorldHeight.isFinite ||
        visibleWorldWidth <= 0 ||
        visibleWorldHeight <= 0) {
      throw ArgumentError('Camera viewport dimensions must be positive.');
    }
    if (!followSpeed.isFinite || followSpeed <= 0) {
      throw ArgumentError('Camera follow speed must be positive and finite.');
    }
    if (!lookAheadDistance.isFinite || lookAheadDistance < 0) {
      throw ArgumentError(
        'Camera look-ahead distance must be non-negative and finite.',
      );
    }
    if (!shakeDecaySpeed.isFinite || shakeDecaySpeed <= 0) {
      throw ArgumentError(
        'Camera shake decay speed must be positive and finite.',
      );
    }
  }

  final double visibleWorldWidth;
  final double visibleWorldHeight;
  final double followSpeed;
  final double lookAheadDistance;
  final double shakeDecaySpeed;
  Vector2? _centre;
  double _shakeAmount = 0;
  double _shakeTime = 0;

  void configure(CameraComponent camera) {
    camera.viewfinder.visibleGameSize = Vector2(
      visibleWorldWidth,
      visibleWorldHeight,
    );
  }

  /// Clears presentation state and snaps the camera to the current player.
  void reset({
    required CameraComponent camera,
    required Vector2 visualPosition,
    required Vector2 visualVelocity,
    required Rect worldBounds,
  }) {
    _centre = null;
    _shakeAmount = 0;
    _shakeTime = 0;
    follow(
      camera: camera,
      visualPosition: visualPosition,
      visualVelocity: visualVelocity,
      worldBounds: worldBounds,
      deltaSeconds: 0,
    );
  }

  /// Adds a bounded camera-shake impulse in presentation world units.
  void addShake(double amount, {double maximumAmount = 1.25}) {
    if (!amount.isFinite ||
        !maximumAmount.isFinite ||
        amount < 0 ||
        maximumAmount < 0) {
      throw ArgumentError(
        'Camera shake values must be finite and non-negative.',
      );
    }
    _shakeAmount = math.min(_shakeAmount + amount, maximumAmount);
  }

  void follow({
    required CameraComponent camera,
    required Vector2 visualPosition,
    required Vector2 visualVelocity,
    required Rect worldBounds,
    required double deltaSeconds,
  }) {
    final target = _targetFor(visualPosition, visualVelocity);
    final desiredCentre = _boundedPosition(target, worldBounds);
    _centre = _nextCentre(desiredCentre, deltaSeconds);
    _advanceShake(deltaSeconds);
    camera.viewfinder.position = _boundedPosition(
      _centre! + Vector2(_shakeX(), _shakeY()),
      worldBounds,
    );
  }

  Vector2 _targetFor(Vector2 position, Vector2 velocity) {
    final speed = velocity.length;
    if (speed <= 0.01) {
      return position.clone();
    }
    return position + velocity.normalized() * lookAheadDistance;
  }

  Vector2 _boundedPosition(Vector2 target, Rect bounds) => Vector2(
    _boundedAxis(target.x, bounds.left, bounds.right, visibleWorldWidth),
    _boundedAxis(target.y, bounds.top, bounds.bottom, visibleWorldHeight),
  );

  Vector2 _nextCentre(Vector2 desired, double deltaSeconds) {
    final previous = _centre;
    if (previous == null || deltaSeconds <= 0) {
      return desired;
    }
    final alpha = 1 - math.exp(-followSpeed * deltaSeconds);
    return previous + (desired - previous) * alpha;
  }

  void _advanceShake(double deltaSeconds) {
    if (deltaSeconds <= 0) {
      return;
    }
    _shakeTime += deltaSeconds;
    _shakeAmount *= math.exp(-shakeDecaySpeed * deltaSeconds);
    if (_shakeAmount < 0.001) {
      _shakeAmount = 0;
    }
  }

  double _shakeX() => math.sin(_shakeTime * 17 * math.pi) * _shakeAmount;

  double _shakeY() => math.cos(_shakeTime * 23 * math.pi) * _shakeAmount;

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
