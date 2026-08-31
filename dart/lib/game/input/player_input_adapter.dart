import 'package:toy_racers/simulation.dart';

/// Presentation-side source of normalized player driving commands.
///
/// Implementations may consume platform-specific events, but only expose the
/// portable [PlayerInput] consumed by the deterministic race simulation.
abstract interface class PlayerInputAdapter {
  /// Returns the latest command with throttle, brake, and steering in range.
  PlayerInput readInput();
}

/// Adapts an existing command callback to the platform input boundary.
final class CallbackPlayerInputAdapter implements PlayerInputAdapter {
  const CallbackPlayerInputAdapter(this._readRawInput);

  final PlayerInput Function() _readRawInput;

  @override
  PlayerInput readInput() => _readRawInput().normalized();
}

/// Merges simultaneous platform commands into one normalized player command.
final class CombinedPlayerInputAdapter implements PlayerInputAdapter {
  CombinedPlayerInputAdapter(Iterable<PlayerInputAdapter> adapters)
    : _adapters = List<PlayerInputAdapter>.unmodifiable(adapters);

  final List<PlayerInputAdapter> _adapters;

  @override
  PlayerInput readInput() => _adapters.fold(
    PlayerInput.none,
    (input, adapter) => input.combinedWith(adapter.readInput()),
  );
}
