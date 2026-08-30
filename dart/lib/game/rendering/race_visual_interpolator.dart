import 'package:toy_racers/simulation.dart';

/// Tracks presentation-only remainder time between deterministic fixed steps.
///
/// The simulation remains the sole owner of tick accumulation and state
/// changes. This helper only derives a `0..1` factor for drawing the already
/// exposed previous and current car states.
final class RaceVisualInterpolator {
  double _remainderSeconds = 0;

  /// Discards presentation time carried over from a previous race.
  void reset() => _remainderSeconds = 0;

  double advance({
    required double frameDeltaSeconds,
    required RacePhase phaseBeforeAdvance,
    required RacePhase phaseAfterAdvance,
    required double countdownRemainingSeconds,
    required int physicalSteps,
  }) {
    _remainderSeconds += _racingPartOfFrame(
      frameDeltaSeconds,
      phaseBeforeAdvance,
      countdownRemainingSeconds,
    );
    _remainderSeconds -= physicalSteps * CarPhysics.fixedDeltaSeconds;

    if (phaseAfterAdvance == RacePhase.finished ||
        phaseAfterAdvance == RacePhase.loading ||
        phaseAfterAdvance == RacePhase.ready) {
      _remainderSeconds = 0;
    }
    _remainderSeconds = _remainderSeconds.clamp(
      0.0,
      CarPhysics.fixedDeltaSeconds,
    );
    return _remainderSeconds / CarPhysics.fixedDeltaSeconds;
  }

  double _racingPartOfFrame(
    double frameDeltaSeconds,
    RacePhase phase,
    double countdownRemainingSeconds,
  ) => switch (phase) {
    RacePhase.racing => frameDeltaSeconds,
    RacePhase.countdown =>
      (frameDeltaSeconds - countdownRemainingSeconds).clamp(
        0.0,
        frameDeltaSeconds,
      ),
    RacePhase.loading ||
    RacePhase.ready ||
    RacePhase.paused ||
    RacePhase.finished => 0,
  };
}
