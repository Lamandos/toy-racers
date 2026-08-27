import 'dart:math' as math;

import '../input/player_input.dart';
import '../math/float32.dart';
import 'car_config.dart';
import 'car_state.dart';

/// Deterministic reference-compatible arcade vehicle integrator.
///
/// It owns throttle, brake, reverse, steering, grip, drift, and position
/// integration. Callers supply an explicit fixed timestep; no rendering or
/// wall-clock state participates in an update.
final class CarPhysics {
  /// Advances [state] by an explicit fixed [deltaSeconds] using [input].
  void update({
    required CarState state,
    required CarConfig config,
    required PlayerInput input,
    required double deltaSeconds,
  }) {
    final step = Float32.narrow(deltaSeconds);
    if (step < 0) {
      throw ArgumentError.value(
        deltaSeconds,
        'deltaSeconds',
        'must not be negative',
      );
    }
    if (step == 0) {
      return;
    }

    final normalizedInput = input.normalized();
    var basis = _Basis.fromDegrees(state.rotationDegrees);

    state.velocityX = Float32.add(
      state.velocityX,
      Float32.multiply(
        Float32.multiply(
          Float32.multiply(basis.forwardX, config.acceleration),
          normalizedInput.throttle,
        ),
        step,
      ),
    );
    state.velocityY = Float32.add(
      state.velocityY,
      Float32.multiply(
        Float32.multiply(
          Float32.multiply(basis.forwardY, config.acceleration),
          normalizedInput.throttle,
        ),
        step,
      ),
    );

    var longitudinalSpeed = basis.forwardDot(state.velocityX, state.velocityY);
    final lateralSpeedBeforeSteering = basis.rightDot(
      state.velocityX,
      state.velocityY,
    );
    if (normalizedInput.brake > 0) {
      final brakingDistance = Float32.multiply(
        Float32.multiply(config.brakeForce, normalizedInput.brake),
        step,
      );
      if (longitudinalSpeed > _stopEpsilon) {
        longitudinalSpeed = _moveToward(longitudinalSpeed, 0, brakingDistance);
      } else {
        longitudinalSpeed = Float32.subtract(
          longitudinalSpeed,
          Float32.multiply(
            Float32.multiply(config.reverseAcceleration, normalizedInput.brake),
            step,
          ),
        );
      }
    }

    longitudinalSpeed = Float32.clamp(
      _moveToward(
        longitudinalSpeed,
        0,
        Float32.multiply(config.rollingResistance, step),
      ),
      -config.maxReverseSpeed,
      config.maxForwardSpeed,
    );

    final targetDriftAmount = _targetDriftAmount(
      longitudinalSpeed: longitudinalSpeed,
      lateralSpeed: lateralSpeedBeforeSteering,
      steering: normalizedInput.steering,
      config: config,
    );
    state.driftAmount = _moveToward(
      state.driftAmount,
      targetDriftAmount,
      Float32.multiply(
        targetDriftAmount > state.driftAmount
            ? config.driftEntryResponse
            : config.driftExitResponse,
        step,
      ),
    );

    final velocityBeforeSteeringX = Float32.add(
      Float32.multiply(basis.forwardX, longitudinalSpeed),
      Float32.multiply(basis.rightX, lateralSpeedBeforeSteering),
    );
    final velocityBeforeSteeringY = Float32.add(
      Float32.multiply(basis.forwardY, longitudinalSpeed),
      Float32.multiply(basis.rightY, lateralSpeedBeforeSteering),
    );

    final steeringAuthority = Float32.clamp(
      Float32.divide(longitudinalSpeed.abs(), _steeringReferenceSpeed),
      0,
      1,
    );
    state.angularVelocity = Float32.multiply(
      Float32.multiply(
        Float32.multiply(
          Float32.multiply(-normalizedInput.steering, config.steeringSpeed),
          _interpolate(1, config.driftSteeringMultiplier, state.driftAmount),
        ),
        steeringAuthority,
      ),
      _signOrZero(longitudinalSpeed),
    );
    state.rotationDegrees = Float32.wrapDegrees(
      Float32.add(
        state.rotationDegrees,
        Float32.multiply(state.angularVelocity, step),
      ),
    );

    basis = _Basis.fromDegrees(state.rotationDegrees);
    longitudinalSpeed = basis.forwardDot(
      velocityBeforeSteeringX,
      velocityBeforeSteeringY,
    );
    var lateralSpeed = basis.rightDot(
      velocityBeforeSteeringX,
      velocityBeforeSteeringY,
    );
    final effectiveGrip = Float32.multiply(
      config.grip,
      _interpolate(1, config.driftGripMultiplier, state.driftAmount),
    );
    lateralSpeed = Float32.multiply(
      lateralSpeed,
      _nonNegative(
        Float32.subtract(
          1,
          Float32.multiply(
            Float32.multiply(config.lateralFriction, effectiveGrip),
            step,
          ),
        ),
      ),
    );
    longitudinalSpeed = _moveToward(
      longitudinalSpeed,
      0,
      Float32.multiply(
        Float32.multiply(
          Float32.multiply(config.driftDrag, state.driftAmount),
          lateralSpeed.abs(),
        ),
        step,
      ),
    );

    longitudinalSpeed = Float32.clamp(
      longitudinalSpeed,
      -config.maxReverseSpeed,
      config.maxForwardSpeed,
    );
    state.velocityX = Float32.add(
      Float32.multiply(basis.forwardX, longitudinalSpeed),
      Float32.multiply(basis.rightX, lateralSpeed),
    );
    state.velocityY = Float32.add(
      Float32.multiply(basis.forwardY, longitudinalSpeed),
      Float32.multiply(basis.rightY, lateralSpeed),
    );
    state.longitudinalSpeed = longitudinalSpeed;
    state.lateralSpeed = lateralSpeed;
    state.x = Float32.add(state.x, Float32.multiply(state.velocityX, step));
    state.y = Float32.add(state.y, Float32.multiply(state.velocityY, step));
  }

  double _targetDriftAmount({
    required double longitudinalSpeed,
    required double lateralSpeed,
    required double steering,
    required CarConfig config,
  }) {
    if (longitudinalSpeed < config.driftEntrySpeed ||
        Float32.multiply(steering, lateralSpeed) < 0) {
      return 0;
    }

    final speedRatio = Float32.clamp(
      Float32.divide(
        Float32.subtract(longitudinalSpeed, config.driftEntrySpeed),
        config.driftEntrySpeed,
      ),
      0,
      1,
    );
    final steeringRatio = Float32.clamp(
      Float32.divide(
        Float32.subtract(steering.abs(), config.driftSteeringThreshold),
        Float32.subtract(1, config.driftSteeringThreshold),
      ),
      0,
      1,
    );
    return Float32.multiply(speedRatio, steeringRatio);
  }

  static double _interpolate(double from, double to, double amount) =>
      Float32.add(from, Float32.multiply(Float32.subtract(to, from), amount));

  static double _moveToward(double value, double target, double amount) {
    if (value < target) {
      return _minimum(Float32.add(value, amount), target);
    }
    if (value > target) {
      return _maximum(Float32.subtract(value, amount), target);
    }
    return target;
  }

  static double _signOrZero(double value) {
    if (value > _stopEpsilon) {
      return 1;
    }
    if (value < -_stopEpsilon) {
      return -1;
    }
    return 0;
  }

  static double _minimum(double left, double right) =>
      left < right ? left : right;

  static double _maximum(double left, double right) =>
      left > right ? left : right;

  static double _nonNegative(double value) => _maximum(0, value);

  static final double fixedDeltaSeconds = Float32.fixedDeltaSeconds;
  static final double maxFrameDeltaSeconds = Float32.narrow(0.25);
  static final double _steeringReferenceSpeed = Float32.narrow(12);
  static final double _stopEpsilon = Float32.narrow(0.01);
}

final class _Basis {
  const _Basis({
    required this.forwardX,
    required this.forwardY,
    required this.rightX,
    required this.rightY,
  });

  final double forwardX;
  final double forwardY;
  final double rightX;
  final double rightY;

  factory _Basis.fromDegrees(double rotationDegrees) {
    final radians = rotationDegrees * _radiansPerDegree;
    final forwardX = Float32.narrow(math.cos(radians));
    final forwardY = Float32.narrow(math.sin(radians));
    return _Basis(
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

  static const double _radiansPerDegree = math.pi / 180.0;
}
