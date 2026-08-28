import '../math/float32.dart';

/// Mutable checkpoint, lap, and timer state for one race participant.
///
/// Timers are stored as binary32 values because Kotlin accumulates them in
/// `Float` fields, rather than deriving them from a simulation tick count.
final class RaceProgress {
  RaceProgress({
    this.currentCheckpointIndex = 0,
    this.completedLaps = 0,
    double lapStartTime = 0,
    double? bestLapTime,
    double totalRaceTime = 0,
    this.finished = false,
    this.finishPosition,
  }) : _lapStartTime = Float32.narrow(lapStartTime),
       _bestLapTime = bestLapTime == null ? null : Float32.narrow(bestLapTime),
       _totalRaceTime = Float32.narrow(totalRaceTime);

  int currentCheckpointIndex;
  int completedLaps;
  double _lapStartTime;
  double? _bestLapTime;
  double _totalRaceTime;
  bool finished;
  int? finishPosition;

  double get lapStartTime => _lapStartTime;
  set lapStartTime(double value) => _lapStartTime = Float32.narrow(value);

  double? get bestLapTime => _bestLapTime;
  set bestLapTime(double? value) =>
      _bestLapTime = value == null ? null : Float32.narrow(value);

  double get totalRaceTime => _totalRaceTime;
  set totalRaceTime(double value) => _totalRaceTime = Float32.narrow(value);
}
