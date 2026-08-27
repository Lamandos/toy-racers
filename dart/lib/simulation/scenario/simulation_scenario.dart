/// A parsed, language-neutral scenario identity for deterministic replay.
///
/// This model keeps the signed-64-bit seed and fixed tick counts at the
/// simulation edge. Pass seeds from a JSON boundary as decimal strings so web
/// builds do not round values outside JavaScript's safe-integer range.
final class SimulationScenario {
  SimulationScenario({
    required String id,
    required Object seed,
    required String trackId,
    required String playerCarId,
    required this.ticks,
    required this.snapshotIntervalTicks,
  }) : id = _requireNotBlank(id, 'id'),
       seed = _parseSeed(seed),
       trackId = _requireNotBlank(trackId, 'trackId'),
       playerCarId = _requireNotBlank(playerCarId, 'playerCarId') {
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

  static final BigInt _minimumSignedInt64 = BigInt.parse(
    '-9223372036854775808',
  );
  static final BigInt _maximumSignedInt64 = BigInt.parse('9223372036854775807');
  static const int _maximumTickCount = 2147483647;

  final String id;
  final String seed;
  final String trackId;
  final String playerCarId;
  final int ticks;
  final int snapshotIntervalTicks;

  /// Returns the exact signed integer represented by [seed].
  BigInt get seedValue => BigInt.parse(seed);

  static String _parseSeed(Object seed) {
    final parsed = switch (seed) {
      String value => BigInt.tryParse(value),
      int value => BigInt.from(value),
      BigInt value => value,
      _ => null,
    };
    if (parsed == null ||
        parsed < _minimumSignedInt64 ||
        parsed > _maximumSignedInt64) {
      throw ArgumentError.value(
        seed,
        'seed',
        'must be a signed 64-bit integer or its decimal string',
      );
    }
    return parsed.toString();
  }

  static String _requireNotBlank(String value, String name) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, name, 'must not be blank');
    }
    return value;
  }
}
