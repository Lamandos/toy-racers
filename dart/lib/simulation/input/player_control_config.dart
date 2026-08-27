import '../math/float32.dart';
import 'player_input.dart';

/// Player-specific input tuning kept separate from vehicle physics.
final class PlayerControlConfig {
  PlayerControlConfig({double steeringSensitivity = 0.85})
    : steeringSensitivity = Float32.narrow(steeringSensitivity) {
    if (this.steeringSensitivity < 0 || this.steeringSensitivity > 1) {
      throw ArgumentError.value(
        steeringSensitivity,
        'steeringSensitivity',
        'must be in the range [0, 1]',
      );
    }
  }

  final double steeringSensitivity;

  /// Scales only steering; throttle and brake retain their input values.
  PlayerInput applyTo(PlayerInput input) => PlayerInput(
    throttle: input.throttle,
    brake: input.brake,
    steering: Float32.multiply(input.steering, steeringSensitivity),
  );
}
