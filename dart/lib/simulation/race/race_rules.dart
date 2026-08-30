import 'dart:math' as math;

import '../math/float32.dart';
import '../track/track.dart';
import '../track/track_geometry.dart';
import '../track/track_point.dart';
import 'race_progress.dart';

/// Advances ordered checkpoint, lap, and timing state from simulated movement.
///
/// Callers can disable progression for a teleport or respawn while retaining
/// timer advancement. This intentionally preserves the Kotlin rule behaviour,
/// including its single-gate-per-update progression.
final class RaceRules {
  RaceRules(this._track, {this.requiredLaps = defaultLapCount}) {
    if (requiredLaps <= 0) {
      throw ArgumentError.value(
        requiredLaps,
        'requiredLaps',
        'must be positive',
      );
    }
  }

  final Track _track;
  final int requiredLaps;
  int _nextFinishPosition = 1;

  /// Synchronizes a restored fixture's finish state before further updates.
  void synchronizeFinishOrdering(Iterable<RaceProgress> progresses) {
    final finishPositions = <int>[];
    for (final progress in progresses) {
      if (progress.finished) {
        final finishPosition = progress.finishPosition;
        if (finishPosition == null) {
          throw ArgumentError('Finished progress must have a finish position');
        }
        finishPositions.add(finishPosition);
      }
    }
    if (finishPositions.toSet().length != finishPositions.length) {
      throw ArgumentError('Finish positions must be unique');
    }
    if (finishPositions.isEmpty) {
      return;
    }
    final highestPosition = finishPositions.reduce(math.max);
    if (highestPosition == _maximumInt) {
      throw ArgumentError(
        'Finish position is too large to assign another result',
      );
    }
    _nextFinishPosition = math.max(_nextFinishPosition, highestPosition + 1);
  }

  /// Clears finish ordering before a new race starts.
  void resetFinishOrdering() => _nextFinishPosition = 1;

  /// Applies one participant's elapsed time and possible gate crossing.
  void update({
    required RaceProgress progress,
    required TrackPoint previousPosition,
    required TrackPoint currentPosition,
    required double deltaSeconds,
    bool allowProgress = true,
  }) {
    final delta = Float32.narrow(deltaSeconds);
    if (delta < 0) {
      throw ArgumentError.value(
        deltaSeconds,
        'deltaSeconds',
        'must not be negative',
      );
    }
    if (progress.finished) {
      return;
    }

    progress.totalRaceTime = Float32.add(progress.totalRaceTime, delta);
    if (!allowProgress) {
      return;
    }

    if (progress.currentCheckpointIndex < _track.checkpoints.length) {
      final checkpoint = _track.checkpoints[progress.currentCheckpointIndex];
      if (_crossesForwardGate(
        previous: previousPosition,
        current: currentPosition,
        gate: checkpoint.gate,
        forwardX: checkpoint.forwardX,
        forwardY: checkpoint.forwardY,
      )) {
        progress.currentCheckpointIndex++;
      }
      return;
    }

    if (!_crossesForwardStartLine(previousPosition, currentPosition)) {
      return;
    }
    _completeLap(progress);
  }

  void _completeLap(RaceProgress progress) {
    progress.completedLaps++;
    final lapTime = Float32.subtract(
      progress.totalRaceTime,
      progress.lapStartTime,
    );
    final bestLapTime = progress.bestLapTime;
    progress.bestLapTime = bestLapTime == null || lapTime < bestLapTime
        ? lapTime
        : bestLapTime;
    progress.lapStartTime = progress.totalRaceTime;
    progress.currentCheckpointIndex = 0;

    if (progress.completedLaps >= requiredLaps) {
      progress.finished = true;
      progress.finishPosition = _nextFinishPosition++;
    }
  }

  bool _crossesForwardStartLine(TrackPoint previous, TrackPoint current) {
    final startLine = _track.startLine;
    final centerX = Float32.add(
      startLine.bounds.x,
      Float32.divide(startLine.bounds.width, 2),
    );
    final centerY = Float32.add(
      startLine.bounds.y,
      Float32.divide(startLine.bounds.height, 2),
    );
    final forwardLength = _vectorLength(startLine.forwardX, startLine.forwardY);
    final perpendicularX = Float32.divide(-startLine.forwardY, forwardLength);
    final perpendicularY = Float32.divide(startLine.forwardX, forwardLength);
    final halfLength = Float32.add(
      Float32.divide(
        Float32.multiply(perpendicularX.abs(), startLine.bounds.width),
        2,
      ),
      Float32.divide(
        Float32.multiply(perpendicularY.abs(), startLine.bounds.height),
        2,
      ),
    );
    final gate = TrackSegment(
      TrackPoint(
        Float32.subtract(centerX, Float32.multiply(perpendicularX, halfLength)),
        Float32.subtract(centerY, Float32.multiply(perpendicularY, halfLength)),
      ),
      TrackPoint(
        Float32.add(centerX, Float32.multiply(perpendicularX, halfLength)),
        Float32.add(centerY, Float32.multiply(perpendicularY, halfLength)),
      ),
    );
    return _crossesForwardGate(
      previous: previous,
      current: current,
      gate: gate,
      forwardX: startLine.forwardX,
      forwardY: startLine.forwardY,
    );
  }

  bool _crossesForwardGate({
    required TrackPoint previous,
    required TrackPoint current,
    required TrackSegment gate,
    required double forwardX,
    required double forwardY,
  }) {
    final forwardLength = _vectorLength(forwardX, forwardY);
    final normalX = Float32.divide(forwardX, forwardLength);
    final normalY = Float32.divide(forwardY, forwardLength);
    final previousDistance = _dotFromGate(previous, gate, normalX, normalY);
    final currentDistance = _dotFromGate(current, gate, normalX, normalY);
    if (previousDistance >= -_crossingEpsilon ||
        currentDistance < -_crossingEpsilon) {
      return false;
    }

    final movementX = Float32.subtract(current.x, previous.x);
    final movementY = Float32.subtract(current.y, previous.y);
    final movementAlongNormal = Float32.add(
      Float32.multiply(movementX, normalX),
      Float32.multiply(movementY, normalY),
    );
    if (movementAlongNormal <= _crossingEpsilon) {
      return false;
    }

    final crossingFraction = Float32.divide(
      previousDistance,
      Float32.subtract(previousDistance, currentDistance),
    );
    final crossingX = Float32.add(
      previous.x,
      Float32.multiply(movementX, crossingFraction),
    );
    final crossingY = Float32.add(
      previous.y,
      Float32.multiply(movementY, crossingFraction),
    );
    final gateX = Float32.subtract(gate.end.x, gate.start.x);
    final gateY = Float32.subtract(gate.end.y, gate.start.y);
    final gateLengthSquared = Float32.add(
      Float32.multiply(gateX, gateX),
      Float32.multiply(gateY, gateY),
    );
    final gateFraction = Float32.divide(
      Float32.add(
        Float32.multiply(Float32.subtract(crossingX, gate.start.x), gateX),
        Float32.multiply(Float32.subtract(crossingY, gate.start.y), gateY),
      ),
      gateLengthSquared,
    );
    return gateFraction >= -_crossingEpsilon &&
        gateFraction <= Float32.add(1, _crossingEpsilon);
  }

  double _dotFromGate(
    TrackPoint point,
    TrackSegment gate,
    double normalX,
    double normalY,
  ) => Float32.add(
    Float32.multiply(Float32.subtract(point.x, gate.start.x), normalX),
    Float32.multiply(Float32.subtract(point.y, gate.start.y), normalY),
  );

  double _vectorLength(double x, double y) => Float32.narrow(
    math.sqrt(Float32.add(Float32.multiply(x, x), Float32.multiply(y, y))),
  );

  static const int defaultLapCount = 3;
  static const int _maximumInt = 2147483647;
  static final double _crossingEpsilon = Float32.narrow(0.0001);
}
