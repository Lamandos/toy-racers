import 'dart:math' as math;

import '../car/car_config.dart';
import '../car/car_state.dart';
import '../math/float32.dart';
import 'surface_speed_config.dart';
import 'surface_type.dart';

/// Mutable, per-car surface state that belongs to the simulation rather than rendering.
final class SurfaceSpeedState {
  SurfaceSpeedState({double speedMultiplier = 1})
    : _speedMultiplier = Float32.narrow(speedMultiplier) {
    if (_speedMultiplier < 0 || _speedMultiplier > 1) {
      throw ArgumentError.value(
        speedMultiplier,
        'speedMultiplier',
        'must be in the range [0, 1]',
      );
    }
  }

  double _speedMultiplier;

  double get speedMultiplier => _speedMultiplier;
  set speedMultiplier(double value) {
    final narrowed = Float32.narrow(value);
    if (narrowed < 0 || narrowed > 1) {
      throw ArgumentError.value(
        value,
        'speedMultiplier',
        'must be in the range [0, 1]',
      );
    }
    _speedMultiplier = narrowed;
  }
}

/// Applies the reference-compatible surface response after each car update.
abstract interface class SurfaceSpeedSystem {
  factory SurfaceSpeedSystem({SurfaceSpeedConfig? config}) =
      DefaultSurfaceSpeedSystem;

  void update({
    required CarState carState,
    required CarConfig carConfig,
    required SurfaceSpeedState surfaceState,
    required SurfaceType surface,
    required double deltaSeconds,
  });
}

/// Gradually lowers a car's speed limit off-road and restores it on-road.
///
/// The system runs after physics and collision response during each fixed step.
final class DefaultSurfaceSpeedSystem implements SurfaceSpeedSystem {
  DefaultSurfaceSpeedSystem({SurfaceSpeedConfig? config})
    : _config = config ?? SurfaceSpeedConfig();

  final SurfaceSpeedConfig _config;

  @override
  void update({
    required CarState carState,
    required CarConfig carConfig,
    required SurfaceSpeedState surfaceState,
    required SurfaceType surface,
    required double deltaSeconds,
  }) {
    final step = _validatedStep(deltaSeconds);
    if (step == 0) {
      return;
    }

    final targetMultiplier = surface.isRoad
        ? 1.0
        : _config.offRoadSpeedMultiplier;
    final changePerSecond = Float32.divide(
      Float32.subtract(1, _config.offRoadSpeedMultiplier),
      _config.transitionSeconds,
    );
    surfaceState.speedMultiplier = _moveToward(
      surfaceState.speedMultiplier,
      targetMultiplier,
      Float32.multiply(changePerSecond, step),
    );
    _applySpeedLimit(carState, carConfig, surfaceState.speedMultiplier);
  }

  static double _validatedStep(double deltaSeconds) {
    final step = Float32.narrow(deltaSeconds);
    if (step < 0) {
      throw ArgumentError.value(
        deltaSeconds,
        'deltaSeconds',
        'must not be negative',
      );
    }
    return step;
  }

  static void _applySpeedLimit(
    CarState state,
    CarConfig config,
    double speedMultiplier,
  ) {
    final basis = _SurfaceBasis.fromDegrees(state.rotationDegrees);
    final longitudinalSpeed = basis.forwardDot(
      state.velocityX,
      state.velocityY,
    );
    final lateralSpeed = basis.rightDot(state.velocityX, state.velocityY);
    final limitedLongitudinalSpeed = Float32.clamp(
      longitudinalSpeed,
      Float32.multiply(-config.maxReverseSpeed, speedMultiplier),
      Float32.multiply(config.maxForwardSpeed, speedMultiplier),
    );
    final lateralSpeedLimit = Float32.multiply(
      config.maxForwardSpeed,
      speedMultiplier,
    );
    final limitedLateralSpeed = Float32.clamp(
      lateralSpeed,
      -lateralSpeedLimit,
      lateralSpeedLimit,
    );

    state.velocityX = Float32.add(
      Float32.multiply(basis.forwardX, limitedLongitudinalSpeed),
      Float32.multiply(basis.rightX, limitedLateralSpeed),
    );
    state.velocityY = Float32.add(
      Float32.multiply(basis.forwardY, limitedLongitudinalSpeed),
      Float32.multiply(basis.rightY, limitedLateralSpeed),
    );
    state.longitudinalSpeed = limitedLongitudinalSpeed;
    state.lateralSpeed = limitedLateralSpeed;
  }

  static double _moveToward(double value, double target, double amount) {
    if (value < target) {
      return _minimum(Float32.add(value, amount), target);
    }
    if (value > target) {
      return _maximum(Float32.subtract(value, amount), target);
    }
    return target;
  }

  static double _minimum(double left, double right) =>
      left < right ? left : right;

  static double _maximum(double left, double right) =>
      left > right ? left : right;
}

final class _SurfaceBasis {
  const _SurfaceBasis({
    required this.forwardX,
    required this.forwardY,
    required this.rightX,
    required this.rightY,
  });

  final double forwardX;
  final double forwardY;
  final double rightX;
  final double rightY;

  factory _SurfaceBasis.fromDegrees(double rotationDegrees) {
    final radians = rotationDegrees * _radiansPerDegree;
    final forwardX = Float32.narrow(math.cos(radians));
    final forwardY = Float32.narrow(math.sin(radians));
    return _SurfaceBasis(
      forwardX: forwardX,
      forwardY: forwardY,
      rightX: Float32.narrow(-forwardY),
      rightY: forwardX,
    );
  }

  double forwardDot(double x, double y) =>
      Float32.add(Float32.multiply(x, forwardX), Float32.multiply(y, forwardY));

  double rightDot(double x, double y) =>
      Float32.add(Float32.multiply(x, rightX), Float32.multiply(y, rightY));

  // Matches java.lang.Math.toRadians' binary64 conversion constant.
  static const double _radiansPerDegree = 0.017453292519943295;
}
