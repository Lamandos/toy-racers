/// A parsed, language-neutral scenario identity for deterministic replay.
///
/// JSON decoding and schema validation belong in a future runner. This model
/// keeps the signed-64-bit seed and fixed tick counts at the simulation edge.
final class SimulationScenario {
  SimulationScenario({
    required String id,
    required this.seed,
    required String trackId,
    required String playerCarId,
    required this.ticks,
    required this.snapshotIntervalTicks,
  }) : id = _requireNotBlank(id, 'id'),
       trackId = _requireNotBlank(trackId, 'trackId'),
       playerCarId = _requireNotBlank(playerCarId, 'playerCarId') {
    if (seed < _minimumSignedInt64 || seed > _maximumSignedInt64) {
      throw ArgumentError.value(
        seed,
        'seed',
        'must fit in a signed 64-bit integer',
      );
    }
    if (ticks <= 0 || ticks > _maximumTickCount) {
      throw ArgumentError.value(
        ticks,
        'ticks',
        'must be in the range 1..$_maximumTickCount',
      );
    }
    if (snapshotIntervalTicks <= 0 ||
        snapshotIntervalTicks > _maximumTickCount) {
      throw ArgumentError.value(
        snapshotIntervalTicks,
        'snapshotIntervalTicks',
        'must be in the range 1..$_maximumTickCount',
      );
    }
  }

  static const int _minimumSignedInt64 = -9223372036854775808;
  static const int _maximumSignedInt64 = 9223372036854775807;
  static const int _maximumTickCount = 2147483647;

  final String id;
  final int seed;
  final String trackId;
  final String playerCarId;
  final int ticks;
  final int snapshotIntervalTicks;

  static String _requireNotBlank(String value, String name) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, name, 'must not be blank');
    }
    return value;
  }
}
