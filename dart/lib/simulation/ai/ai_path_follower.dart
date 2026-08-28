import 'dart:math' as math;

import '../car/car_state.dart';
import '../math/float32.dart';
import '../track/track_point.dart';
import 'ai_config.dart';

/// Owns deterministic waypoint progression and racing-line variation.
final class AiPathFollower {
  AiPathFollower({
    required Iterable<TrackPoint> racingLine,
    required TrackPoint initialPosition,
    required this.config,
    required this.racingLineBias,
  }) : racingLine = List<TrackPoint>.unmodifiable(racingLine) {
    if (this.racingLine.length < _minimumRacingLinePoints) {
      throw ArgumentError('Racing line must contain at least 3 points.');
    }
    _targetWaypointIndex = _waypointAfterNearest(initialPosition);
  }

  static const int _minimumRacingLinePoints = 3;

  final List<TrackPoint> racingLine;
  final AiConfig config;
  final double racingLineBias;
  late int _targetWaypointIndex;

  int get targetWaypointIndex => _targetWaypointIndex;

  void reset(TrackPoint position) {
    _targetWaypointIndex = _waypointAfterNearest(position);
  }

  void update(TrackPoint position) {
    var checked = 0;
    final radiusSquared = Float32.multiply(
      config.waypointRadius,
      config.waypointRadius,
    );
    while (checked < racingLine.length &&
        _distanceSquared(position, racingLine[_targetWaypointIndex]) <=
            radiusSquared) {
      _targetWaypointIndex = (_targetWaypointIndex + 1) % racingLine.length;
      checked++;
    }
  }

  TrackPoint target() {
    final index =
        (_targetWaypointIndex + config.lookAheadPoints - 1) % racingLine.length;
    final point = racingLine[index];
    if (racingLineBias == 0) {
      return point;
    }
    final next = racingLine[(index + 1) % racingLine.length];
    final deltaX = Float32.subtract(next.x, point.x);
    final deltaY = Float32.subtract(next.y, point.y);
    final length = Float32.narrow(
      math.sqrt(
        Float32.add(
          Float32.multiply(deltaX, deltaX),
          Float32.multiply(deltaY, deltaY),
        ),
      ),
    );
    if (length == 0) {
      return point;
    }
    return TrackPoint(
      Float32.subtract(
        point.x,
        Float32.multiply(
          Float32.multiply(Float32.divide(deltaY, length), racingLineBias),
          config.racingLineBiasDistance,
        ),
      ),
      Float32.add(
        point.y,
        Float32.multiply(
          Float32.multiply(Float32.divide(deltaX, length), racingLineBias),
          config.racingLineBiasDistance,
        ),
      ),
    );
  }

  double headingError(CarState carState, {TrackPoint? targetPoint}) {
    final target = targetPoint ?? this.target();
    final angle = Float32.narrow(
      math.atan2(
            Float32.subtract(target.y, carState.y),
            Float32.subtract(target.x, carState.x),
          ) *
          _degreesPerRadian,
    );
    return Float32.normalizeSignedDegrees(
      Float32.subtract(angle, carState.rotationDegrees),
    );
  }

  double turnAheadDegrees(CarState carState) {
    final target = racingLine[_targetWaypointIndex];
    final next =
        racingLine[(_targetWaypointIndex + config.lookAheadPoints) %
            racingLine.length];
    final approach = Float32.narrow(
      math.atan2(
            Float32.subtract(target.y, carState.y),
            Float32.subtract(target.x, carState.x),
          ) *
          _degreesPerRadian,
    );
    final exit = Float32.narrow(
      math.atan2(
            Float32.subtract(next.y, target.y),
            Float32.subtract(next.x, target.x),
          ) *
          _degreesPerRadian,
    );
    return Float32.normalizeSignedDegrees(Float32.subtract(exit, approach))
        .abs();
  }

  int _waypointAfterNearest(TrackPoint position) {
    var nearestIndex = 0;
    var nearestDistance = _distanceSquared(position, racingLine.first);
    for (var index = 1; index < racingLine.length; index++) {
      final distance = _distanceSquared(position, racingLine[index]);
      if (distance < nearestDistance) {
        nearestIndex = index;
        nearestDistance = distance;
      }
    }
    return (nearestIndex + 1) % racingLine.length;
  }

  double _distanceSquared(TrackPoint first, TrackPoint second) => Float32.add(
    Float32.multiply(Float32.subtract(second.x, first.x), second.x - first.x),
    Float32.multiply(Float32.subtract(second.y, first.y), second.y - first.y),
  );

  static final double _degreesPerRadian = 180 / math.pi;
}
