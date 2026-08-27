import 'dart:math' as math;

import '../input/player_input.dart';
import '../math/float32.dart';
import 'car_config.dart';
import 'car_state.dart';

/// Contract for deterministic car integration.
///
/// The default factory keeps the original construction syntax while allowing
/// callers to provide test or platform-specific implementations through the
/// interface.
abstract interface class CarPhysics {
  factory CarPhysics() = DefaultCarPhysics;

  /// Advances [state] by an explicit fixed [deltaSeconds] using [input].
  void update({
    required CarState state,
    required CarConfig config,
    required PlayerInput input,
    required double deltaSeconds,
  });

  /// The fixed physics step used by the reference simulation.
  static final double fixedDeltaSeconds = Float32.fixedDeltaSeconds;

  /// Maximum frame delta accepted by a real-time adapter.
  static final double maxFrameDeltaSeconds = Float32.narrow(0.25);
}

/// Reference-compatible arcade vehicle integrator.
final class DefaultCarPhysics implements CarPhysics {
  @override
  void update({
    required CarState state,
    required CarConfig config,
    required PlayerInput input,
    required double deltaSeconds,
  }) {
    final step = _validatedStep(deltaSeconds);
    if (step == 0) {
      return;
    }

    final normalizedInput = input.normalized();
    var basis = _Basis.fromDegrees(state.rotationDegrees);
    _applyAcceleration(state, config, normalizedInput, basis, step);

    var speeds = _speedsInBasis(state, basis);
    speeds = _applyBraking(speeds, config, normalizedInput, step);
    speeds = _applyRollingResistance(speeds, config, step);
    state.driftAmount = _nextDriftAmount(
      speeds: speeds,
      steering: normalizedInput.steering,
      currentDriftAmount: state.driftAmount,
      config: config,
      step: step,
    );

    final velocityBeforeSteering = _velocityFromSpeeds(basis, speeds);
    _applySteering(state, config, normalizedInput, speeds.longitudinal, step);

    basis = _Basis.fromDegrees(state.rotationDegrees);
    speeds = _reprojectVelocity(velocityBeforeSteering, basis);
    speeds = _applyGripAndDriftDrag(speeds, state.driftAmount, config, step);
    _storeFinalState(state, basis, speeds, step);
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

  static void _applyAcceleration(
    CarState state,
    CarConfig config,
    PlayerInput input,
    _Basis basis,
    double step,
  ) {
    state.velocityX = _acceleratedVelocity(
      state.velocityX,
      basis.forwardX,
      config.acceleration,
      input.throttle,
      step,
    );
    state.velocityY = _acceleratedVelocity(
      state.velocityY,
      basis.forwardY,
      config.acceleration,
      input.throttle,
      step,
    );
  }

  static double _acceleratedVelocity(
    double velocity,
    double forwardComponent,
    double acceleration,
    double throttle,
    double step,
  ) => Float32.add(
    velocity,
    Float32.multiply(
      Float32.multiply(
        Float32.multiply(forwardComponent, acceleration),
        throttle,
      ),
      step,
    ),
  );

  static _SpeedComponents _speedsInBasis(CarState state, _Basis basis) =>
      _SpeedComponents(
        longitudinal: basis.forwardDot(state.velocityX, state.velocityY),
        lateral: basis.rightDot(state.velocityX, state.velocityY),
      );

  static _SpeedComponents _applyBraking(
    _SpeedComponents speeds,
    CarConfig config,
    PlayerInput input,
    double step,
  ) {
    if (input.brake <= 0) {
      return speeds;
    }

    final brakingDistance = Float32.multiply(
      Float32.multiply(config.brakeForce, input.brake),
      step,
    );
    final longitudinalSpeed = speeds.longitudinal > _stopEpsilon
        ? _moveToward(speeds.longitudinal, 0, brakingDistance)
        : Float32.subtract(
            speeds.longitudinal,
            Float32.multiply(
              Float32.multiply(config.reverseAcceleration, input.brake),
              step,
            ),
          );
    return _SpeedComponents(
      longitudinal: longitudinalSpeed,
      lateral: speeds.lateral,
    );
  }

  static _SpeedComponents _applyRollingResistance(
    _SpeedComponents speeds,
    CarConfig config,
    double step,
  ) => _SpeedComponents(
    longitudinal: Float32.clamp(
      _moveToward(
        speeds.longitudinal,
        0,
        Float32.multiply(config.rollingResistance, step),
      ),
      -config.maxReverseSpeed,
      config.maxForwardSpeed,
    ),
    lateral: speeds.lateral,
  );

  static double _nextDriftAmount({
    required _SpeedComponents speeds,
    required double steering,
    required double currentDriftAmount,
    required CarConfig config,
    required double step,
  }) {
    final targetDriftAmount = _targetDriftAmount(
      longitudinalSpeed: speeds.longitudinal,
      lateralSpeed: speeds.lateral,
      steering: steering,
      config: config,
    );
    final response = targetDriftAmount > currentDriftAmount
        ? config.driftEntryResponse
        : config.driftExitResponse;
    return _moveToward(
      currentDriftAmount,
      targetDriftAmount,
      Float32.multiply(response, step),
    );
  }

  static _Velocity _velocityFromSpeeds(_Basis basis, _SpeedComponents speeds) =>
      _Velocity(
        x: Float32.add(
          Float32.multiply(basis.forwardX, speeds.longitudinal),
          Float32.multiply(basis.rightX, speeds.lateral),
        ),
        y: Float32.add(
          Float32.multiply(basis.forwardY, speeds.longitudinal),
          Float32.multiply(basis.rightY, speeds.lateral),
        ),
      );

  static void _applySteering(
    CarState state,
    CarConfig config,
    PlayerInput input,
    double longitudinalSpeed,
    double step,
  ) {
    final steeringAuthority = Float32.clamp(
      Float32.divide(longitudinalSpeed.abs(), _steeringReferenceSpeed),
      0,
      1,
    );
    state.angularVelocity = Float32.multiply(
      Float32.multiply(
        Float32.multiply(
          Float32.multiply(-input.steering, config.steeringSpeed),
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
  }

  static _SpeedComponents _reprojectVelocity(
    _Velocity velocity,
    _Basis basis,
  ) => _SpeedComponents(
    longitudinal: basis.forwardDot(velocity.x, velocity.y),
    lateral: basis.rightDot(velocity.x, velocity.y),
  );

  static _SpeedComponents _applyGripAndDriftDrag(
    _SpeedComponents speeds,
    double driftAmount,
    CarConfig config,
    double step,
  ) {
    final effectiveGrip = Float32.multiply(
      config.grip,
      _interpolate(1, config.driftGripMultiplier, driftAmount),
    );
    final lateralSpeed = Float32.multiply(
      speeds.lateral,
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
    final longitudinalSpeed = _moveToward(
      speeds.longitudinal,
      0,
      Float32.multiply(
        Float32.multiply(
          Float32.multiply(config.driftDrag, driftAmount),
          lateralSpeed.abs(),
        ),
        step,
      ),
    );
    return _SpeedComponents(
      longitudinal: Float32.clamp(
        longitudinalSpeed,
        -config.maxReverseSpeed,
        config.maxForwardSpeed,
      ),
      lateral: lateralSpeed,
    );
  }

  static void _storeFinalState(
    CarState state,
    _Basis basis,
    _SpeedComponents speeds,
    double step,
  ) {
    state.velocityX = Float32.add(
      Float32.multiply(basis.forwardX, speeds.longitudinal),
      Float32.multiply(basis.rightX, speeds.lateral),
    );
    state.velocityY = Float32.add(
      Float32.multiply(basis.forwardY, speeds.longitudinal),
      Float32.multiply(basis.rightY, speeds.lateral),
    );
    state.longitudinalSpeed = speeds.longitudinal;
    state.lateralSpeed = speeds.lateral;
    state.x = Float32.add(state.x, Float32.multiply(state.velocityX, step));
    state.y = Float32.add(state.y, Float32.multiply(state.velocityY, step));
  }

  static double _targetDriftAmount({
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

  static final double _steeringReferenceSpeed = Float32.narrow(12);
  static final double _stopEpsilon = Float32.narrow(0.01);
}

final class _SpeedComponents {
  const _SpeedComponents({required this.longitudinal, required this.lateral});

  final double longitudinal;
  final double lateral;
}

final class _Velocity {
  const _Velocity({required this.x, required this.y});

  final double x;
  final double y;
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

  // Matches java.lang.Math.toRadians' binary64 conversion constant.
  static const double _radiansPerDegree = 0.017453292519943295;
}
