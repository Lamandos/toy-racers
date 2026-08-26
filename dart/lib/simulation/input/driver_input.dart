import '../math/float32.dart';

/// A portable control command produced by the player or an AI driver.
///
/// Commands retain their raw binary32 values until the simulation boundary
/// explicitly calls [normalized]. This preserves the compatibility contract's
/// one-time normalization after an optional input tweak has been applied.
final class DriverInput {
  DriverInput({double throttle = 0, double brake = 0, double steering = 0})
    : throttle = Float32.narrow(throttle),
      brake = Float32.narrow(brake),
      steering = Float32.narrow(steering);

  final double throttle;
  final double brake;
  final double steering;

  /// A zero command. Each call returns an immutable value.
  static DriverInput get none => DriverInput();

  /// Applies the reference control ranges once.
  DriverInput normalized() => DriverInput(
    throttle: Float32.clamp(throttle, 0, 1),
    brake: Float32.clamp(brake, 0, 1),
    steering: Float32.clamp(steering, -1, 1),
  );

  /// Adds a behavioral input tweak before applying the reference ranges once.
  ///
  /// This maps to `BehavioralInput.withTweak` in the Kotlin compatibility
  /// runner. It is intentionally distinct from Kotlin's device-input merge.
  DriverInput combinedWith(DriverInput other) => DriverInput(
    throttle: Float32.clamp(Float32.add(throttle, other.throttle), 0, 1),
    brake: Float32.clamp(Float32.add(brake, other.brake), 0, 1),
    steering: Float32.clamp(Float32.add(steering, other.steering), -1, 1),
  );

  @override
  bool operator ==(Object other) =>
      other is DriverInput &&
      throttle == other.throttle &&
      brake == other.brake &&
      steering == other.steering;

  @override
  int get hashCode => Object.hash(throttle, brake, steering);
}
