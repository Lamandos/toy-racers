import 'dart:math' as math;

/// Frame-local target levels for the long-lived race samples.
final class RaceAudioMix {
  const RaceAudioMix({
    required this.engineVolume,
    required this.enginePitch,
    required this.driftVolume,
    required this.driftPitch,
    required this.brakingVolume,
    required this.gravelVolume,
    required this.grassVolume,
  });

  final double engineVolume;
  final double enginePitch;
  final double driftVolume;
  final double driftPitch;
  final double brakingVolume;
  final double gravelVolume;
  final double grassVolume;
}

/// Mirrors the reference mix while deliberately excluding it from simulation.
RaceAudioMix calculateRaceAudioMix({
  required double speed,
  required double maxSpeed,
  required double throttle,
  required double brake,
  required double driftAmount,
  required bool racing,
  required bool offRoad,
  required bool grass,
  required bool paused,
  required double sfxVolume,
}) {
  final speedRatio = _ratio(speed.abs(), maxSpeed);
  final activeRaceVolume = paused || !racing ? 0.0 : sfxVolume;
  final normalizedThrottle = throttle.clamp(0, 1).toDouble();
  final normalizedBrake = brake.clamp(0, 1).toDouble();
  final normalizedDrift = driftAmount.clamp(0, 1).toDouble();
  final wheelspinVolume = offRoad ? normalizedThrottle * activeRaceVolume : 0.0;
  return RaceAudioMix(
    engineVolume: paused
        ? 0
        : (_idleVolume + normalizedThrottle * _throttleVolume) * sfxVolume,
    enginePitch: 0.96 + speedRatio * 0.08,
    driftVolume: normalizedDrift * speedRatio * activeRaceVolume,
    driftPitch: 0.9 + speedRatio * 0.25,
    brakingVolume:
        normalizedBrake * _forwardRatio(speed, maxSpeed) * activeRaceVolume,
    gravelVolume: offRoad && !grass ? wheelspinVolume : 0,
    grassVolume: grass ? wheelspinVolume : 0,
  );
}

double _ratio(double numerator, double denominator) {
  if (!denominator.isFinite || denominator <= 0) {
    return 0;
  }
  return (numerator / denominator).clamp(0, 1).toDouble();
}

double _forwardRatio(double speed, double maxSpeed) =>
    _ratio(math.max(speed, 0), maxSpeed);

const double _idleVolume = 0.18;
const double _throttleVolume = 0.62;
