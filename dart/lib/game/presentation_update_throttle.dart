/// Schedules presentation-only updates at a stable maximum frequency.
///
/// It never affects simulation ticks. Keeping Flutter overlays and browser
/// audio updates below the render cadence leaves the frame budget to Flame.
final class PresentationUpdateThrottle {
  PresentationUpdateThrottle({required this.intervalSeconds}) {
    if (!intervalSeconds.isFinite || intervalSeconds <= 0) {
      throw ArgumentError.value(
        intervalSeconds,
        'intervalSeconds',
        'must be positive and finite',
      );
    }
  }

  final double intervalSeconds;
  double _elapsedSeconds = 0;

  /// Returns true when enough presentation time has elapsed for an update.
  bool isDue(double elapsedSeconds) {
    if (!elapsedSeconds.isFinite || elapsedSeconds <= 0) {
      return false;
    }
    _elapsedSeconds += elapsedSeconds;
    if (_elapsedSeconds < intervalSeconds) {
      return false;
    }
    _elapsedSeconds %= intervalSeconds;
    return true;
  }

  /// Drops retained frame time when the presentation changes immediately.
  void reset() => _elapsedSeconds = 0;
}
