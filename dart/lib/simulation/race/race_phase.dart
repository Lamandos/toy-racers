import '../math/float32.dart';

/// Legal high-level phases of one race simulation.
enum RacePhase { loading, ready, countdown, racing, paused, finished }

/// Mutable lifecycle state that owns countdown time in simulation seconds.
final class RaceState {
  RaceState({double countdownDurationSeconds = 3})
    : _countdownDurationSeconds = Float32.narrow(countdownDurationSeconds),
      _countdownRemainingSeconds = Float32.narrow(countdownDurationSeconds) {
    if (_countdownDurationSeconds <= 0) {
      throw ArgumentError.value(
        countdownDurationSeconds,
        'countdownDurationSeconds',
        'must be a positive finite number',
      );
    }
  }

  final double _countdownDurationSeconds;
  RacePhase _phase = RacePhase.loading;
  double _countdownRemainingSeconds;

  RacePhase get phase => _phase;
  double get countdownRemainingSeconds => _countdownRemainingSeconds;

  void markReady() => _transition(RacePhase.loading, RacePhase.ready);

  void startCountdown() {
    _transition(RacePhase.ready, RacePhase.countdown);
    _countdownRemainingSeconds = _countdownDurationSeconds;
  }

  void pause() => _transition(RacePhase.racing, RacePhase.paused);

  void resume() => _transition(RacePhase.paused, RacePhase.racing);

  void finish() => _transition(RacePhase.racing, RacePhase.finished);

  void _transition(RacePhase expected, RacePhase next) {
    if (_phase != expected) {
      throw StateError('Expected race phase $expected, but was $_phase');
    }
    _phase = next;
  }
}
