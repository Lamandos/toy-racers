import '../car/car_state.dart';
import '../math/float32.dart';
import 'ai_config.dart';

/// Detects stalled, wrong-way, and off-road drivers, escalating to respawn.
final class AiRecoveryController {
  AiRecoveryController(this.config);

  final AiConfig config;
  double _stuckTime = 0;
  double _wrongWayTime = 0;
  double _offTrackTime = 0;
  double _recoveryTimeRemaining = 0;

  void reset() {
    _stuckTime = 0;
    _wrongWayTime = 0;
    _offTrackTime = 0;
    _recoveryTimeRemaining = 0;
  }

  AiRecoveryAction update({
    required CarState carState,
    required double headingErrorDegrees,
    required bool isOnTrack,
    required double deltaSeconds,
  }) {
    final delta = Float32.narrow(deltaSeconds);
    if (_recoveryTimeRemaining > 0) {
      _recoveryTimeRemaining = Float32.subtract(_recoveryTimeRemaining, delta);
      if (_recoveryTimeRemaining > 0) {
        return AiRecoveryAction.reverse;
      }
      final recovered =
          carState.longitudinalSpeed.abs() >= config.stuckSpeed &&
          headingErrorDegrees.abs() <= config.wrongWayAngleDegrees &&
          isOnTrack;
      reset();
      return recovered ? AiRecoveryAction.none : AiRecoveryAction.respawn;
    }

    _stuckTime = carState.longitudinalSpeed.abs() < config.stuckSpeed
        ? Float32.add(_stuckTime, delta)
        : 0;
    _wrongWayTime = headingErrorDegrees.abs() > config.wrongWayAngleDegrees
        ? Float32.add(_wrongWayTime, delta)
        : 0;
    _offTrackTime = !isOnTrack ? Float32.add(_offTrackTime, delta) : 0;
    if (_offTrackTime >= config.offTrackDurationSeconds) {
      reset();
      return AiRecoveryAction.respawn;
    }
    if (_stuckTime >= config.stuckDurationSeconds ||
        _wrongWayTime >= config.wrongWayDurationSeconds) {
      _recoveryTimeRemaining = config.recoveryDurationSeconds;
      return AiRecoveryAction.reverse;
    }
    return AiRecoveryAction.none;
  }
}

/// The recovery operation to apply after a driver has observed one tick.
enum AiRecoveryAction { none, reverse, respawn }
