import '../math/float32.dart';

/// Immutable arcade-handling configuration expressed in world units and seconds.
final class CarConfig {
  CarConfig({
    double acceleration = 26,
    double brakeForce = 38,
    double reverseAcceleration = 15,
    double maxForwardSpeed = 34,
    double maxReverseSpeed = 13,
    double steeringSpeed = 145,
    double grip = 1,
    double lateralFriction = 7,
    double rollingResistance = 4,
    double driftEntrySpeed = 16,
    double driftSteeringThreshold = 0.55,
    double driftGripMultiplier = 0.30,
    double driftSteeringMultiplier = 1.18,
    double driftEntryResponse = 5,
    double driftExitResponse = 8,
    double driftDrag = 0.8,
    double collisionRadius = 0.81,
    double collisionLongitudinalOffset = 0.81,
    double width = 1.8,
    double length = 3.4,
  }) : acceleration = Float32.narrow(acceleration),
       brakeForce = Float32.narrow(brakeForce),
       reverseAcceleration = Float32.narrow(reverseAcceleration),
       maxForwardSpeed = Float32.narrow(maxForwardSpeed),
       maxReverseSpeed = Float32.narrow(maxReverseSpeed),
       steeringSpeed = Float32.narrow(steeringSpeed),
       grip = Float32.narrow(grip),
       lateralFriction = Float32.narrow(lateralFriction),
       rollingResistance = Float32.narrow(rollingResistance),
       driftEntrySpeed = Float32.narrow(driftEntrySpeed),
       driftSteeringThreshold = Float32.narrow(driftSteeringThreshold),
       driftGripMultiplier = Float32.narrow(driftGripMultiplier),
       driftSteeringMultiplier = Float32.narrow(driftSteeringMultiplier),
       driftEntryResponse = Float32.narrow(driftEntryResponse),
       driftExitResponse = Float32.narrow(driftExitResponse),
       driftDrag = Float32.narrow(driftDrag),
       collisionRadius = Float32.narrow(collisionRadius),
       collisionLongitudinalOffset = Float32.narrow(
         collisionLongitudinalOffset,
       ),
       width = Float32.narrow(width),
       length = Float32.narrow(length) {
    if (this.acceleration < 0 ||
        this.brakeForce < 0 ||
        this.reverseAcceleration < 0 ||
        this.steeringSpeed < 0 ||
        this.grip < 0 ||
        this.lateralFriction < 0 ||
        this.rollingResistance < 0 ||
        this.driftDrag < 0 ||
        this.collisionLongitudinalOffset < 0) {
      throw ArgumentError('Non-negative car settings must not be negative');
    }
    if (this.maxForwardSpeed <= 0 ||
        this.maxReverseSpeed <= 0 ||
        this.driftEntrySpeed <= 0 ||
        this.driftEntryResponse <= 0 ||
        this.driftExitResponse <= 0 ||
        this.collisionRadius <= 0 ||
        this.width <= 0 ||
        this.length <= 0) {
      throw ArgumentError('Positive car settings must be greater than zero');
    }
    if (this.driftSteeringThreshold < 0 || this.driftSteeringThreshold >= 1) {
      throw ArgumentError.value(
        driftSteeringThreshold,
        'driftSteeringThreshold',
        'must be in the range [0, 1)',
      );
    }
    if (this.driftGripMultiplier < 0 || this.driftGripMultiplier > 1) {
      throw ArgumentError.value(
        driftGripMultiplier,
        'driftGripMultiplier',
        'must be in the range [0, 1]',
      );
    }
    if (this.driftSteeringMultiplier < 1) {
      throw ArgumentError.value(
        driftSteeringMultiplier,
        'driftSteeringMultiplier',
        'must be greater than or equal to 1',
      );
    }
    if (this.collisionRadius * 2 > this.width) {
      throw ArgumentError('Collision shape must fit inside car width');
    }
    if (this.collisionLongitudinalOffset + this.collisionRadius >
        this.length / 2) {
      throw ArgumentError('Collision shape must fit inside car length');
    }
  }

  final double acceleration;
  final double brakeForce;
  final double reverseAcceleration;
  final double maxForwardSpeed;
  final double maxReverseSpeed;
  final double steeringSpeed;
  final double grip;
  final double lateralFriction;
  final double rollingResistance;
  final double driftEntrySpeed;
  final double driftSteeringThreshold;
  final double driftGripMultiplier;
  final double driftSteeringMultiplier;
  final double driftEntryResponse;
  final double driftExitResponse;
  final double driftDrag;
  final double collisionRadius;
  final double collisionLongitudinalOffset;
  final double width;
  final double length;
}
