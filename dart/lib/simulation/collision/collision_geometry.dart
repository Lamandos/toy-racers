import 'dart:math' as math;

import '../car/car_config.dart';
import '../car/car_state.dart';
import '../math/float32.dart';
import '../track/track_geometry.dart';
import '../track/track_point.dart';

/// Binary32 geometry helpers shared only by collision resolution code.
final class CollisionGeometry {
  CollisionGeometry._();

  static const double minimumDistance = 0.0001;

  static List<CollisionCircle> carCircles(CarState state, CarConfig config) {
    final basis = CollisionBasis.fromDegrees(state.rotationDegrees);
    final multipliers = config.collisionLongitudinalOffset == 0
        ? const <double>[0]
        : const <double>[-1, 0, 1];
    return <CollisionCircle>[
      for (final multiplier in multipliers)
        CollisionCircle(
          x: Float32.add(
            state.x,
            Float32.multiply(
              basis.forwardX,
              Float32.multiply(config.collisionLongitudinalOffset, multiplier),
            ),
          ),
          y: Float32.add(
            state.y,
            Float32.multiply(
              basis.forwardY,
              Float32.multiply(config.collisionLongitudinalOffset, multiplier),
            ),
          ),
          radius: config.collisionRadius,
        ),
    ];
  }

  static CollisionCirclePair closestCirclePair(
    List<CollisionCircle> firstCircles,
    List<CollisionCircle> secondCircles,
  ) {
    CollisionCirclePair? closest;
    for (final firstCircle in firstCircles) {
      for (final secondCircle in secondCircles) {
        final candidate = CollisionCirclePair(
          firstCircle,
          secondCircle,
          lengthSquared(
            Float32.subtract(secondCircle.x, firstCircle.x),
            Float32.subtract(secondCircle.y, firstCircle.y),
          ),
        );
        if (closest == null ||
            candidate.distanceSquared < closest.distanceSquared) {
          closest = candidate;
        }
      }
    }
    return closest!;
  }

  static ClosestPolygonEdge closestPolygonEdge(
    TrackPoint point,
    TrackPolygon polygon,
  ) {
    ClosestPolygonEdge? closest;
    for (var index = 0; index < polygon.vertices.length; index++) {
      final start = polygon.vertices[index];
      final end = polygon.vertices[(index + 1) % polygon.vertices.length];
      final edgeX = Float32.subtract(end.x, start.x);
      final edgeY = Float32.subtract(end.y, start.y);
      final numerator = Float32.add(
        Float32.multiply(Float32.subtract(point.x, start.x), edgeX),
        Float32.multiply(Float32.subtract(point.y, start.y), edgeY),
      );
      final fraction = Float32.divide(numerator, lengthSquared(edgeX, edgeY));
      final clampedFraction = Float32.clamp(fraction, 0, 1);
      final edgePoint = TrackPoint(
        Float32.add(start.x, Float32.multiply(edgeX, clampedFraction)),
        Float32.add(start.y, Float32.multiply(edgeY, clampedFraction)),
      );
      final candidate = ClosestPolygonEdge(
        edgePoint,
        start,
        end,
        hypot(
          Float32.subtract(point.x, edgePoint.x),
          Float32.subtract(point.y, edgePoint.y),
        ),
      );
      if (closest == null || candidate.distance < closest.distance) {
        closest = candidate;
      }
    }
    return closest!;
  }

  static CollisionNormal outwardNormal(
    TrackPoint start,
    TrackPoint end,
    List<TrackPoint> vertices,
  ) {
    final edgeX = Float32.subtract(end.x, start.x);
    final edgeY = Float32.subtract(end.y, start.y);
    final length = hypot(edgeX, edgeY);
    var signedArea = 0.0;
    for (var index = 0; index < vertices.length; index++) {
      final current = vertices[index];
      final next = vertices[(index + 1) % vertices.length];
      signedArea += Float32.subtract(
        Float32.multiply(current.x, next.y),
        Float32.multiply(next.x, current.y),
      );
    }
    return signedArea >= 0
        ? CollisionNormal(
            Float32.divide(edgeY, length),
            Float32.divide(-edgeX, length),
          )
        : CollisionNormal(
            Float32.divide(-edgeY, length),
            Float32.divide(edgeX, length),
          );
  }

  static double lengthSquared(double x, double y) =>
      Float32.add(Float32.multiply(x, x), Float32.multiply(y, y));

  static double distanceFromSquared(double squared) =>
      Float32.narrow(math.sqrt(squared));

  static double hypot(double x, double y) =>
      distanceFromSquared(lengthSquared(x, y));

  static double dot(double x, double y, double basisX, double basisY) =>
      Float32.add(Float32.multiply(x, basisX), Float32.multiply(y, basisY));

  static void updateLongitudinalSpeed(CarState state) {
    final basis = CollisionBasis.fromDegrees(state.rotationDegrees);
    state.longitudinalSpeed = dot(
      state.velocityX,
      state.velocityY,
      basis.forwardX,
      basis.forwardY,
    );
    state.lateralSpeed = dot(
      state.velocityX,
      state.velocityY,
      Float32.narrow(-basis.forwardY),
      basis.forwardX,
    );
    if (hypot(state.velocityX, state.velocityY) < minimumDistance) {
      state.velocityX = 0;
      state.velocityY = 0;
      state.longitudinalSpeed = 0;
      state.lateralSpeed = 0;
    }
  }
}

final class CollisionBasis {
  const CollisionBasis({required this.forwardX, required this.forwardY});

  factory CollisionBasis.fromDegrees(double rotationDegrees) {
    final radians = rotationDegrees * _radiansPerDegree;
    return CollisionBasis(
      forwardX: Float32.narrow(math.cos(radians)),
      forwardY: Float32.narrow(math.sin(radians)),
    );
  }

  final double forwardX;
  final double forwardY;

  static const double _radiansPerDegree = 0.017453292519943295;
}

final class CollisionCircle {
  const CollisionCircle({
    required this.x,
    required this.y,
    required this.radius,
  });

  final double x;
  final double y;
  final double radius;
}

final class CollisionCirclePair {
  const CollisionCirclePair(
    this.firstCircle,
    this.secondCircle,
    this.distanceSquared,
  );

  final CollisionCircle firstCircle;
  final CollisionCircle secondCircle;
  final double distanceSquared;
}

final class ClosestPolygonEdge {
  const ClosestPolygonEdge(
    this.point,
    this.edgeStart,
    this.edgeEnd,
    this.distance,
  );

  final TrackPoint point;
  final TrackPoint edgeStart;
  final TrackPoint edgeEnd;
  final double distance;
}

final class CollisionNormal {
  const CollisionNormal(this.x, this.y);

  final double x;
  final double y;
}

final class CollisionPenetration {
  const CollisionPenetration(this.normal, this.penetration);

  final CollisionNormal normal;
  final double penetration;
}
