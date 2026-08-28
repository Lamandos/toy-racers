import '../car/car_config.dart';
import '../car/car_state.dart';
import '../math/float32.dart';
import '../track/track.dart';
import '../track/track_geometry.dart';
import '../track/track_point.dart';
import 'collision_config.dart';
import 'collision_geometry.dart';
import 'collision_result.dart';

export 'collision_result.dart';

/// Resolves ordered contacts in the pure-Dart simulation layer.
///
/// Collision geometry and response deliberately mirror the Kotlin oracle.
/// Flame may consume the resulting state for presentation, but it must not
/// replace this simulation result.
abstract interface class CollisionSystem {
  factory CollisionSystem({CollisionConfig? config}) = DefaultCollisionSystem;

  /// Resolves a car capsule against world bounds and ordered track solids.
  CollisionResult resolveTrackCollision({
    required CarState state,
    required CarConfig config,
    required Track track,
  });

  /// Resolves the nearest pair of circles from two ordered car capsules.
  CollisionResult resolveCarCollision({
    required CarState firstState,
    required CarConfig firstConfig,
    required CarState secondState,
    required CarConfig secondConfig,
  });
}

/// Reference-compatible, bounded circle and capsule contact resolver.
final class DefaultCollisionSystem implements CollisionSystem {
  DefaultCollisionSystem({CollisionConfig? config})
    : _config = config ?? CollisionConfig();

  static const int _maxResolutionPasses = 4;

  final CollisionConfig _config;

  @override
  CollisionResult resolveTrackCollision({
    required CarState state,
    required CarConfig config,
    required Track track,
  }) {
    final circleCount = CollisionGeometry.carCircles(state, config).length;
    final contacts = <CollisionContact>[];
    for (var index = 0; index < circleCount; index++) {
      final circle = CollisionGeometry.carCircles(state, config)[index];
      contacts.addAll(_resolveTrackCircle(state, circle, track).contacts);
    }
    return _resultFor(contacts);
  }

  @override
  CollisionResult resolveCarCollision({
    required CarState firstState,
    required CarConfig firstConfig,
    required CarState secondState,
    required CarConfig secondConfig,
  }) {
    final closestPair = CollisionGeometry.closestCirclePair(
      CollisionGeometry.carCircles(firstState, firstConfig),
      CollisionGeometry.carCircles(secondState, secondConfig),
    );
    final firstCircleState = firstState.copy()
      ..x = closestPair.firstCircle.x
      ..y = closestPair.firstCircle.y;
    final secondCircleState = secondState.copy()
      ..x = closestPair.secondCircle.x
      ..y = closestPair.secondCircle.y;
    final result = _resolveCarCircles(
      firstCircleState,
      closestPair.firstCircle.radius,
      secondCircleState,
      closestPair.secondCircle.radius,
    );
    _translateState(firstState, firstCircleState, closestPair.firstCircle);
    _translateState(secondState, secondCircleState, closestPair.secondCircle);
    _copyMotion(firstState, firstCircleState);
    _copyMotion(secondState, secondCircleState);
    return result;
  }

  CollisionResult _resolveTrackCircle(
    CarState state,
    CollisionCircle circle,
    Track track,
  ) {
    final circleState = state.copy()
      ..x = circle.x
      ..y = circle.y;
    final result = _resolveTrackCircleState(circleState, circle.radius, track);
    _translateState(state, circleState, circle);
    _copyMotion(state, circleState);
    return result;
  }

  CollisionResult _resolveTrackCircleState(
    CarState state,
    double radius,
    Track track,
  ) {
    _validateRadiusFitsTrack(radius, track.worldBounds);
    final contacts = <CollisionContact>[];
    for (var pass = 0; pass < _maxResolutionPasses; pass++) {
      final contactsBeforePass = contacts.length;
      _resolveOuterBoundary(state, radius, track.worldBounds, contacts);
      for (final obstacle in track.innerObstacles) {
        _resolveRectangleObstacle(state, radius, obstacle, contacts);
      }
      for (final shape in track.collisionShapes) {
        _resolveCollisionShape(state, radius, shape, contacts);
      }
      if (contacts.length == contactsBeforePass) {
        break;
      }
    }
    CollisionGeometry.updateLongitudinalSpeed(state);
    return _resultFor(contacts);
  }

  CollisionResult _resolveCarCircles(
    CarState first,
    double firstRadius,
    CarState second,
    double secondRadius,
  ) {
    _validatePositiveRadius(
      firstRadius,
      'First collision radius must be positive',
    );
    _validatePositiveRadius(
      secondRadius,
      'Second collision radius must be positive',
    );
    final offsetX = Float32.subtract(second.x, first.x);
    final offsetY = Float32.subtract(second.y, first.y);
    final distanceSquared = CollisionGeometry.lengthSquared(offsetX, offsetY);
    final combinedRadius = Float32.add(firstRadius, secondRadius);
    if (distanceSquared >= Float32.multiply(combinedRadius, combinedRadius)) {
      return CollisionResult.none;
    }

    final distance = CollisionGeometry.distanceFromSquared(distanceSquared);
    final normal = distance > CollisionGeometry.minimumDistance
        ? CollisionNormal(
            Float32.divide(offsetX, distance),
            Float32.divide(offsetY, distance),
          )
        : const CollisionNormal(1, 0);
    final penetration = Float32.subtract(combinedRadius, distance);
    final correction = Float32.divide(penetration, 2);
    first.x = Float32.subtract(first.x, Float32.multiply(normal.x, correction));
    first.y = Float32.subtract(first.y, Float32.multiply(normal.y, correction));
    second.x = Float32.add(second.x, Float32.multiply(normal.x, correction));
    second.y = Float32.add(second.y, Float32.multiply(normal.y, correction));

    final closingSpeed = _nonNegative(
      CollisionGeometry.dot(
        Float32.subtract(first.velocityX, second.velocityX),
        Float32.subtract(first.velocityY, second.velocityY),
        normal.x,
        normal.y,
      ),
    );
    final impulse = _minimum(
      Float32.divide(
        Float32.multiply(closingSpeed, Float32.add(1, _config.carRestitution)),
        2,
      ),
      _config.maxCarImpulse,
    );
    first.velocityX = Float32.subtract(
      first.velocityX,
      Float32.multiply(normal.x, impulse),
    );
    first.velocityY = Float32.subtract(
      first.velocityY,
      Float32.multiply(normal.y, impulse),
    );
    second.velocityX = Float32.add(
      second.velocityX,
      Float32.multiply(normal.x, impulse),
    );
    second.velocityY = Float32.add(
      second.velocityY,
      Float32.multiply(normal.y, impulse),
    );
    CollisionGeometry.updateLongitudinalSpeed(first);
    CollisionGeometry.updateLongitudinalSpeed(second);
    return CollisionResult(
      contacts: <CollisionContact>[
        CollisionContact(
          type: CollisionType.car,
          normalX: Float32.narrow(-normal.x),
          normalY: Float32.narrow(-normal.y),
          penetration: penetration,
          impactSpeed: closingSpeed,
        ),
      ],
    );
  }

  void _resolveCollisionShape(
    CarState state,
    double radius,
    TrackCollisionShape shape,
    List<CollisionContact> contacts,
  ) {
    switch (shape) {
      case TrackCircle():
        _resolveCircleObstacle(state, radius, shape, contacts);
      case TrackPolygon():
        _resolvePolygonObstacle(state, radius, shape, contacts);
    }
  }

  void _resolveCircleObstacle(
    CarState state,
    double radius,
    TrackCircle obstacle,
    List<CollisionContact> contacts,
  ) {
    final offsetX = Float32.subtract(state.x, obstacle.center.x);
    final offsetY = Float32.subtract(state.y, obstacle.center.y);
    final combinedRadius = Float32.add(radius, obstacle.radius);
    final distanceSquared = CollisionGeometry.lengthSquared(offsetX, offsetY);
    if (distanceSquared >= Float32.multiply(combinedRadius, combinedRadius)) {
      return;
    }
    final distance = CollisionGeometry.distanceFromSquared(distanceSquared);
    final normal = distance > CollisionGeometry.minimumDistance
        ? CollisionNormal(
            Float32.divide(offsetX, distance),
            Float32.divide(offsetY, distance),
          )
        : const CollisionNormal(1, 0);
    _resolveShapeContact(
      state,
      normal,
      Float32.subtract(combinedRadius, distance),
      contacts,
    );
  }

  void _resolvePolygonObstacle(
    CarState state,
    double radius,
    TrackPolygon obstacle,
    List<CollisionContact> contacts,
  ) {
    final center = TrackPoint(state.x, state.y);
    final closest = CollisionGeometry.closestPolygonEdge(center, obstacle);
    final offsetX = Float32.subtract(state.x, closest.point.x);
    final offsetY = Float32.subtract(state.y, closest.point.y);
    final distance = CollisionGeometry.hypot(offsetX, offsetY);
    final inside = obstacle.contains(center.x, center.y);
    if (!inside && distance >= radius) {
      return;
    }

    final CollisionNormal normal;
    final double penetration;
    if (inside) {
      normal = CollisionGeometry.outwardNormal(
        closest.edgeStart,
        closest.edgeEnd,
        obstacle.vertices,
      );
      penetration = Float32.add(radius, distance);
    } else if (distance <= CollisionGeometry.minimumDistance) {
      normal = CollisionGeometry.outwardNormal(
        closest.edgeStart,
        closest.edgeEnd,
        obstacle.vertices,
      );
      penetration = radius;
    } else {
      normal = CollisionNormal(
        Float32.divide(offsetX, distance),
        Float32.divide(offsetY, distance),
      );
      penetration = Float32.subtract(radius, distance);
    }
    _resolveShapeContact(state, normal, penetration, contacts);
  }

  void _resolveShapeContact(
    CarState state,
    CollisionNormal normal,
    double penetration,
    List<CollisionContact> contacts,
  ) {
    state.x = Float32.add(state.x, Float32.multiply(normal.x, penetration));
    state.y = Float32.add(state.y, Float32.multiply(normal.y, penetration));
    _addWallContact(
      state,
      normal,
      penetration,
      CollisionType.trackObject,
      contacts,
    );
  }

  void _resolveRectangleObstacle(
    CarState state,
    double radius,
    TrackRectangle obstacle,
    List<CollisionContact> contacts,
  ) {
    final nearestX = Float32.clamp(state.x, obstacle.x, obstacle.maxX);
    final nearestY = Float32.clamp(state.y, obstacle.y, obstacle.maxY);
    final offsetX = Float32.subtract(state.x, nearestX);
    final offsetY = Float32.subtract(state.y, nearestY);
    final distanceSquared = CollisionGeometry.lengthSquared(offsetX, offsetY);
    if (distanceSquared >= Float32.multiply(radius, radius)) {
      return;
    }

    final distance = CollisionGeometry.distanceFromSquared(distanceSquared);
    final correction = distance > CollisionGeometry.minimumDistance
        ? CollisionPenetration(
            CollisionNormal(
              Float32.divide(offsetX, distance),
              Float32.divide(offsetY, distance),
            ),
            Float32.subtract(radius, distance),
          )
        : _insideRectangleNormal(state, radius, obstacle);
    _resolveShapeContact(
      state,
      correction.normal,
      correction.penetration,
      contacts,
    );
  }

  void _resolveOuterBoundary(
    CarState state,
    double radius,
    TrackRectangle boundary,
    List<CollisionContact> contacts,
  ) {
    final minimumX = Float32.add(boundary.x, radius);
    final maximumX = Float32.subtract(boundary.maxX, radius);
    final minimumY = Float32.add(boundary.y, radius);
    final maximumY = Float32.subtract(boundary.maxY, radius);
    if (state.x < minimumX) {
      final penetration = Float32.subtract(minimumX, state.x);
      state.x = minimumX;
      _addWallContact(
        state,
        const CollisionNormal(1, 0),
        penetration,
        CollisionType.worldBoundary,
        contacts,
      );
    } else if (state.x > maximumX) {
      final penetration = Float32.subtract(state.x, maximumX);
      state.x = maximumX;
      _addWallContact(
        state,
        const CollisionNormal(-1, 0),
        penetration,
        CollisionType.worldBoundary,
        contacts,
      );
    }
    if (state.y < minimumY) {
      final penetration = Float32.subtract(minimumY, state.y);
      state.y = minimumY;
      _addWallContact(
        state,
        const CollisionNormal(0, 1),
        penetration,
        CollisionType.worldBoundary,
        contacts,
      );
    } else if (state.y > maximumY) {
      final penetration = Float32.subtract(state.y, maximumY);
      state.y = maximumY;
      _addWallContact(
        state,
        const CollisionNormal(0, -1),
        penetration,
        CollisionType.worldBoundary,
        contacts,
      );
    }
  }

  void _addWallContact(
    CarState state,
    CollisionNormal normal,
    double penetration,
    CollisionType type,
    List<CollisionContact> contacts,
  ) {
    final velocityIntoAllowedArea = CollisionGeometry.dot(
      state.velocityX,
      state.velocityY,
      normal.x,
      normal.y,
    );
    final impactSpeed = _nonNegative(Float32.narrow(-velocityIntoAllowedArea));
    if (velocityIntoAllowedArea < 0) {
      _applyWallResponse(state, normal, velocityIntoAllowedArea);
    }
    contacts.add(
      CollisionContact(
        type: type,
        normalX: normal.x,
        normalY: normal.y,
        penetration: penetration,
        impactSpeed: impactSpeed,
      ),
    );
  }

  CollisionPenetration _insideRectangleNormal(
    CarState state,
    double radius,
    TrackRectangle obstacle,
  ) {
    final distances = <({CollisionNormal normal, double distance})>[
      (
        normal: const CollisionNormal(-1, 0),
        distance: Float32.subtract(state.x, obstacle.x),
      ),
      (
        normal: const CollisionNormal(1, 0),
        distance: Float32.subtract(obstacle.maxX, state.x),
      ),
      (
        normal: const CollisionNormal(0, -1),
        distance: Float32.subtract(state.y, obstacle.y),
      ),
      (
        normal: const CollisionNormal(0, 1),
        distance: Float32.subtract(obstacle.maxY, state.y),
      ),
    ];
    var nearest = distances.first;
    for (final side in distances.skip(1)) {
      if (side.distance < nearest.distance) {
        nearest = side;
      }
    }
    return CollisionPenetration(
      nearest.normal,
      Float32.add(radius, nearest.distance),
    );
  }

  void _applyWallResponse(
    CarState state,
    CollisionNormal normal,
    double velocityIntoAllowedArea,
  ) {
    state.velocityX = Float32.subtract(
      state.velocityX,
      Float32.multiply(normal.x, velocityIntoAllowedArea),
    );
    state.velocityY = Float32.subtract(
      state.velocityY,
      Float32.multiply(normal.y, velocityIntoAllowedArea),
    );
    state.velocityX = Float32.multiply(
      state.velocityX,
      _config.wallSpeedRetention,
    );
    state.velocityY = Float32.multiply(
      state.velocityY,
      _config.wallSpeedRetention,
    );
  }

  void _validateRadiusFitsTrack(double radius, TrackRectangle worldBounds) {
    _validatePositiveRadius(radius, 'Collision radius must be positive');
    if (worldBounds.width < Float32.multiply(radius, 2)) {
      throw ArgumentError(
        'Collision radius does not fit inside world bounds width',
      );
    }
    if (worldBounds.height < Float32.multiply(radius, 2)) {
      throw ArgumentError(
        'Collision radius does not fit inside world bounds height',
      );
    }
  }

  static void _translateState(
    CarState state,
    CarState circleState,
    CollisionCircle circle,
  ) {
    state.x = Float32.add(state.x, Float32.subtract(circleState.x, circle.x));
    state.y = Float32.add(state.y, Float32.subtract(circleState.y, circle.y));
  }

  static void _copyMotion(CarState target, CarState source) {
    target.longitudinalSpeed = source.longitudinalSpeed;
    target.velocityX = source.velocityX;
    target.velocityY = source.velocityY;
    target.lateralSpeed = source.lateralSpeed;
  }

  static void _validatePositiveRadius(double radius, String message) {
    if (radius <= 0) {
      throw ArgumentError(message);
    }
  }

  static CollisionResult _resultFor(List<CollisionContact> contacts) =>
      contacts.isEmpty
          ? CollisionResult.none
          : CollisionResult(contacts: contacts);

  static double _minimum(double left, double right) =>
      left < right ? left : right;

  static double _nonNegative(double value) => value < 0 ? 0 : value;
}
