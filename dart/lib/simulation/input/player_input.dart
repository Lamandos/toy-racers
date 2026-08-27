import '../math/float32.dart';

/// A portable player command produced by keyboard, touch, or an AI driver.
///
/// Keyboard and touch are input provenance only: both adapters must provide
/// this same normalized command shape. Raw binary32 values are retained until
/// the simulation boundary calls [normalized].
class PlayerInput {
  PlayerInput({double throttle = 0, double brake = 0, double steering = 0})
    : throttle = Float32.narrow(throttle),
      brake = Float32.narrow(brake),
      steering = Float32.narrow(steering);

  final double throttle;
  final double brake;
  final double steering;

  /// The immutable neutral command.
  static final PlayerInput none = PlayerInput();

  /// Applies the reference control ranges once.
  PlayerInput normalized() => PlayerInput(
    throttle: Float32.clamp(throttle, 0, 1),
    brake: Float32.clamp(brake, 0, 1),
    steering: Float32.clamp(steering, -1, 1),
  );

  /// Merges simultaneous keyboard and touch commands as in the reference.
  PlayerInput combinedWith(PlayerInput other) => PlayerInput(
    throttle: _maximumPedal(throttle, other.throttle),
    brake: _maximumPedal(brake, other.brake),
    steering: Float32.clamp(Float32.add(steering, other.steering), -1, 1),
  ).normalized();

  /// Applies one scenario input tweak before the single normalization pass.
  ///
  /// This is intentionally distinct from [combinedWith], which represents
  /// simultaneous device commands rather than a compatibility-fixture delta.
  PlayerInput withTweak(PlayerInput delta) => PlayerInput(
    throttle: Float32.clamp(Float32.add(throttle, delta.throttle), 0, 1),
    brake: Float32.clamp(Float32.add(brake, delta.brake), 0, 1),
    steering: Float32.clamp(Float32.add(steering, delta.steering), -1, 1),
  ).normalized();

  @override
  bool operator ==(Object other) =>
      other is PlayerInput &&
      throttle == other.throttle &&
      brake == other.brake &&
      steering == other.steering;

  @override
  int get hashCode => Object.hash(throttle, brake, steering);

  static double _maximumPedal(double value, double other) {
    if (value == other && value == 0) {
      return 0;
    }
    return value > other ? value : other;
  }
}
