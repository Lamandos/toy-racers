import '../math/float32.dart';
import '../track/track.dart';
import '../track/track_point.dart';
import 'race_progress.dart';

/// Immutable participant state used to calculate a live race position.
final class RaceCompetitor {
  const RaceCompetitor({
    required this.id,
    required this.progress,
    required this.position,
  });

  final String id;
  final RaceProgress progress;
  final TrackPoint position;
}

/// Ranks cars by finish result, completed gates, and distance to the next gate.
final class PositionTracker {
  PositionTracker(this._track);

  final Track _track;

  /// Returns one-based positions indexed by stable competitor ID.
  Map<String, int> positions(Iterable<RaceCompetitor> competitors) {
    final ordered = List<RaceCompetitor>.of(competitors);
    if (ordered.map((competitor) => competitor.id).toSet().length !=
        ordered.length) {
      throw ArgumentError('Competitor IDs must be unique');
    }
    ordered.sort(_compare);
    return <String, int>{
      for (var index = 0; index < ordered.length; index++)
        ordered[index].id: index + 1,
    };
  }

  int _compare(RaceCompetitor left, RaceCompetitor right) {
    final finished = _finishedOrder(left).compareTo(_finishedOrder(right));
    if (finished != 0) return finished;
    final finishPosition = _finishPosition(left)
        .compareTo(_finishPosition(right));
    if (finishPosition != 0) return finishPosition;
    final laps = right.progress.completedLaps.compareTo(
      left.progress.completedLaps,
    );
    if (laps != 0) return laps;
    final checkpoints = right.progress.currentCheckpointIndex.compareTo(
      left.progress.currentCheckpointIndex,
    );
    if (checkpoints != 0) return checkpoints;
    final distance = _distanceSquaredToNextGate(left)
        .compareTo(_distanceSquaredToNextGate(right));
    return distance != 0 ? distance : left.id.compareTo(right.id);
  }

  int _finishedOrder(RaceCompetitor competitor) =>
      competitor.progress.finished ? 0 : 1;

  int _finishPosition(RaceCompetitor competitor) =>
      competitor.progress.finishPosition ?? _maximumInt;

  double _distanceSquaredToNextGate(RaceCompetitor competitor) {
    final gateCenter = _nextGateCenter(competitor.progress);
    final deltaX = Float32.subtract(competitor.position.x, gateCenter.x);
    final deltaY = Float32.subtract(competitor.position.y, gateCenter.y);
    return Float32.add(
      Float32.multiply(deltaX, deltaX),
      Float32.multiply(deltaY, deltaY),
    );
  }

  TrackPoint _nextGateCenter(RaceProgress progress) {
    if (progress.currentCheckpointIndex < _track.checkpoints.length) {
      final gate = _track.checkpoints[progress.currentCheckpointIndex].gate;
      return TrackPoint(
        Float32.divide(Float32.add(gate.start.x, gate.end.x), 2),
        Float32.divide(Float32.add(gate.start.y, gate.end.y), 2),
      );
    }
    return TrackPoint(
      Float32.add(
        _track.startLine.bounds.x,
        Float32.divide(_track.startLine.bounds.width, 2),
      ),
      Float32.add(
        _track.startLine.bounds.y,
        Float32.divide(_track.startLine.bounds.height, 2),
      ),
    );
  }

  static const int _maximumInt = 2147483647;
}

/// Explicit race-domain name retained for source compatibility.
typedef RacePositionTracker = PositionTracker;
