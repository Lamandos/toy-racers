import 'dart:math' as math;

import '../car/car_state.dart';
import '../math/float32.dart';
import '../track/track.dart';
import '../track/track_geometry.dart';
import '../track/track_point.dart';
import 'ai_config.dart';
import 'ai_race_context.dart';

/// Lightweight, deterministic obstacle queries for AI cars.
final class AiObstacleDetector {
  AiObstacleDetector(this.config);

  final AiConfig config;

  DetectedAiObstacle? nearestAhead(
    CarState carState,
    List<AiObstacle> obstacles,
  ) {
    final basis = _ForwardBasis.fromRotation(carState.rotationDegrees);
    DetectedAiObstacle? nearest;
    for (final obstacle in obstacles) {
      final deltaX = Float32.subtract(obstacle.x, carState.x);
      final deltaY = Float32.subtract(obstacle.y, carState.y);
      final forwardDistance = Float32.add(
        Float32.multiply(deltaX, basis.forwardX),
        Float32.multiply(deltaY, basis.forwardY),
      );
      final lateralDistance = Float32.add(
        Float32.multiply(deltaX, basis.rightX),
        Float32.multiply(deltaY, basis.rightY),
      );
      final laneWidth = Float32.add(
        config.obstacleLaneHalfWidth,
        obstacle.radius,
      );
      if (forwardDistance >= 0 &&
          forwardDistance <= config.obstacleDetectionDistance &&
          lateralDistance.abs() <= laneWidth &&
          (nearest == null || forwardDistance < nearest.forwardDistance)) {
        nearest = DetectedAiObstacle(
          obstacle: obstacle,
          forwardDistance: forwardDistance,
          lateralDistance: lateralDistance,
        );
      }
    }
    return nearest;
  }

  List<AiSensorRay> scanTrack(CarState carState, Track? track) {
    if (track == null) {
      return const <AiSensorRay>[];
    }
    return List<AiSensorRay>.unmodifiable(
      <double>[
        -config.sensorRayAngleDegrees,
        0,
        config.sensorRayAngleDegrees,
      ].map((offset) => _scanRay(carState, track, offset)),
    );
  }

  double passingClearance(
    CarState carState,
    List<AiObstacle> obstacles,
    double steeringDirection,
  ) {
    if (steeringDirection == 0) {
      throw ArgumentError.value(
        steeringDirection,
        'steeringDirection',
        'Passing direction must not be zero.',
      );
    }
    final basis = _ForwardBasis.fromRotation(carState.rotationDegrees);
    final targetLateral = steeringDirection < 0
        ? config.overtakeLaneOffset
        : -config.overtakeLaneOffset;
    double? nearest;
    for (final obstacle in obstacles) {
      final deltaX = Float32.subtract(obstacle.x, carState.x);
      final deltaY = Float32.subtract(obstacle.y, carState.y);
      final forwardDistance = Float32.add(
        Float32.multiply(deltaX, basis.forwardX),
        Float32.multiply(deltaY, basis.forwardY),
      );
      final lateralDistance = Float32.add(
        Float32.multiply(deltaX, basis.rightX),
        Float32.multiply(deltaY, basis.rightY),
      );
      final corridorHalfWidth = Float32.add(
        config.overtakeLaneHalfWidth,
        obstacle.radius,
      );
      if (forwardDistance >= 0 &&
          forwardDistance <= config.obstacleDetectionDistance &&
          Float32.subtract(lateralDistance, targetLateral).abs() <=
              corridorHalfWidth &&
          (nearest == null || forwardDistance < nearest)) {
        nearest = forwardDistance;
      }
    }
    return nearest ?? config.obstacleDetectionDistance;
  }

  AiSensorRay _scanRay(CarState carState, Track track, double offset) {
    final rayRotation = Float32.add(carState.rotationDegrees, offset);
    final radians = rayRotation * math.pi / 180;
    final directionX = Float32.narrow(math.cos(radians));
    final directionY = Float32.narrow(math.sin(radians));
    var distance = config.sensorRayStep;
    while (distance <= config.obstacleDetectionDistance) {
      final point = TrackPoint(
        Float32.add(carState.x, Float32.multiply(directionX, distance)),
        Float32.add(carState.y, Float32.multiply(directionY, distance)),
      );
      if (_isBlocked(track, point)) {
        break;
      }
      distance = Float32.add(distance, config.sensorRayStep);
    }
    final endpointDistance = _minimum(
      distance,
      config.obstacleDetectionDistance,
    );
    return AiSensorRay(
      start: TrackPoint(carState.x, carState.y),
      end: TrackPoint(
        Float32.add(carState.x, Float32.multiply(directionX, endpointDistance)),
        Float32.add(carState.y, Float32.multiply(directionY, endpointDistance)),
      ),
      hit: distance <= config.obstacleDetectionDistance,
      angleOffsetDegrees: offset,
    );
  }

  bool _isBlocked(Track track, TrackPoint point) {
    if (!track.worldBounds.containsPoint(point) ||
        track.innerObstacles.any((obstacle) => obstacle.containsPoint(point))) {
      return true;
    }
    return track.collisionShapes.any(
      (shape) => switch (shape) {
        TrackCircle() => _circleContains(shape, point),
        TrackPolygon() => shape.contains(point.x, point.y),
      },
    );
  }

  bool _circleContains(TrackCircle circle, TrackPoint point) {
    final deltaX = Float32.subtract(point.x, circle.center.x);
    final deltaY = Float32.subtract(point.y, circle.center.y);
    final distanceSquared = Float32.add(
      Float32.multiply(deltaX, deltaX),
      Float32.multiply(deltaY, deltaY),
    );
    return distanceSquared <= Float32.multiply(circle.radius, circle.radius);
  }

  static double _minimum(double left, double right) =>
      left < right ? left : right;
}

/// One car detected in the current forward lane.
final class DetectedAiObstacle {
  const DetectedAiObstacle({
    required this.obstacle,
    required this.forwardDistance,
    required this.lateralDistance,
  });

  final AiObstacle obstacle;
  final double forwardDistance;
  final double lateralDistance;
}

/// A fixed sensor-ray observation used by avoidance decisions and debugging.
final class AiSensorRay {
  const AiSensorRay({
    required this.start,
    required this.end,
    required this.hit,
    required this.angleOffsetDegrees,
  });

  final TrackPoint start;
  final TrackPoint end;
  final bool hit;
  final double angleOffsetDegrees;

  double distance() => Float32.narrow(
    math.sqrt(
      Float32.add(
        Float32.multiply(Float32.subtract(end.x, start.x), end.x - start.x),
        Float32.multiply(Float32.subtract(end.y, start.y), end.y - start.y),
      ),
    ),
  );
}

final class _ForwardBasis {
  const _ForwardBasis({
    required this.forwardX,
    required this.forwardY,
    required this.rightX,
    required this.rightY,
  });

  factory _ForwardBasis.fromRotation(double rotationDegrees) {
    final radians = rotationDegrees * math.pi / 180;
    final forwardX = Float32.narrow(math.cos(radians));
    final forwardY = Float32.narrow(math.sin(radians));
    return _ForwardBasis(
      forwardX: forwardX,
      forwardY: forwardY,
      rightX: Float32.narrow(-forwardY),
      rightY: forwardX,
    );
  }

  final double forwardX;
  final double forwardY;
  final double rightX;
  final double rightY;
}
