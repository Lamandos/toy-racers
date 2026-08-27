import '../math/float32.dart';
import 'player_input.dart';

export 'player_input.dart';

/// Backwards-compatible input contract from the initial simulation API.
@Deprecated('Use PlayerInput instead.')
final class DriverInput extends PlayerInput {
  DriverInput({super.throttle, super.brake, super.steering});

  DriverInput.from(PlayerInput input)
    : this(
        throttle: input.throttle,
        brake: input.brake,
        steering: input.steering,
      );

  /// A zero command with the legacy [DriverInput] type.
  static DriverInput get none => DriverInput();

  @override
  DriverInput normalized() => DriverInput(
    throttle: Float32.clamp(throttle, 0, 1),
    brake: Float32.clamp(brake, 0, 1),
    steering: Float32.clamp(steering, -1, 1),
  );

  /// Preserves the original additive merge semantics of [DriverInput].
  @override
  DriverInput combinedWith(PlayerInput other) => DriverInput(
    throttle: Float32.clamp(Float32.add(throttle, other.throttle), 0, 1),
    brake: Float32.clamp(Float32.add(brake, other.brake), 0, 1),
    steering: Float32.clamp(Float32.add(steering, other.steering), -1, 1),
  );
}
