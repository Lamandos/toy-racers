import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/simulation.dart';
import 'package:toy_racers/simulation/collision/collision_geometry.dart';

import 'collision_test_support.dart';

void main() {
  final collisionSystem = CollisionSystem();
  final unitCircleConfig = CarConfig(
    collisionRadius: 1,
    collisionLongitudinalOffset: 0,
    width: 2,
    length: 3,
  );

  group('CollisionSystem geometry and impact state', () {
    test(
      'keeps double-precision hypot intermediates at the binary32 boundary',
      () {
        expect(
          CollisionGeometry.hypot(132.68743896484375, -117.60503387451172),
          177.30453491210938,
        );
        expect(CollisionGeometry.minimumDistance, 0.00009999999747378752);

        final state = CarState(velocityX: 0.0001);
        CollisionGeometry.updateLongitudinalSpeed(state);

        expect(state.velocityX, Float32.narrow(0.0001));
        expect(state.longitudinalSpeed, Float32.narrow(0.0001));
      },
    );

    test('retains the legacy max impact speed constructor', () {
      final result = CollisionResult(maxImpactSpeed: 2.5);

      expect(result.contacts, isEmpty);
      expect(result.maxImpactSpeed, Float32.narrow(2.5));
    });

    test(
      'world edge removes outward velocity and retains tangential speed',
      () {
        final state = CarState(x: -1, y: 6, velocityX: -10, velocityY: 4);

        final result = resolveTrackCollisionForTest(
          collisionSystem,
          state,
          unitCircleConfig,
        );

        expect(result.collided, isTrue);
        expect(result.contacts.single.type, CollisionType.worldBoundary);
        expect(state.x, closeTo(unitCircleConfig.collisionRadius, _tolerance));
        expect(state.velocityX, 0);
        expect(state.velocityY, closeTo(2.6, _tolerance));
        expect(result.contacts.single.impactSpeed, 10);
        expect(result.maxImpactSpeed, 10);
      },
    );

    test(
      'separating boundary contact keeps inward velocity and has no impact',
      () {
        final state = CarState(x: 0.2, y: 6, velocityX: 3);

        final result = resolveTrackCollisionForTest(
          collisionSystem,
          state,
          unitCircleConfig,
        );

        expect(result.collided, isTrue);
        expect(state.velocityX, 3);
        expect(result.contacts.single.impactSpeed, 0);
      },
    );

    test('inside rectangle resolves by nearest side in fixed tie order', () {
      final obstacle = TrackRectangle(20, 20, 4, 4);
      final cases =
          <({double x, double y, double expectedX, double expectedY})>[
            (x: 20.5, y: 22, expectedX: 19, expectedY: 22),
            (x: 23.5, y: 22, expectedX: 25, expectedY: 22),
            (x: 22, y: 20.5, expectedX: 22, expectedY: 19),
            (x: 22, y: 23.5, expectedX: 22, expectedY: 25),
          ];

      for (final scenario in cases) {
        final state = CarState(x: scenario.x, y: scenario.y);
        final result = resolveTrackCollisionForTest(
          collisionSystem,
          state,
          unitCircleConfig,
          innerObstacles: <TrackRectangle>[obstacle],
        );
        expect(result.contacts, hasLength(1), reason: '$scenario');
        expect(result.contacts.single.type, CollisionType.trackObject);
        expect(state.x, closeTo(scenario.expectedX, _tolerance));
        expect(state.y, closeTo(scenario.expectedY, _tolerance));
      }
    });

    test('circle contact handles center overlap but not exact tangent', () {
      final circle = TrackCircle(center: TrackPoint(30, 30), radius: 2);
      final centered = CarState(x: 30, y: 30);
      final tangent = CarState(x: 33, y: 30);

      final centeredResult = resolveTrackCollisionForTest(
        collisionSystem,
        centered,
        unitCircleConfig,
        collisionShapes: <TrackCollisionShape>[circle],
      );
      final tangentResult = resolveTrackCollisionForTest(
        collisionSystem,
        tangent,
        unitCircleConfig,
        collisionShapes: <TrackCollisionShape>[circle],
      );

      expect(centeredResult.collided, isTrue);
      expect(centered.x, 33);
      expect(tangentResult.collided, isFalse);
      expect(tangent.x, 33);
    });

    test('polygon collision resolves interior for both winding directions', () {
      final counterClockwise = <TrackPoint>[
        TrackPoint(40, 40),
        TrackPoint(44, 40),
        TrackPoint(44, 44),
        TrackPoint(40, 44),
      ];

      for (final vertices in <List<TrackPoint>>[
        counterClockwise,
        counterClockwise.reversed.toList(),
      ]) {
        final state = CarState(x: 42, y: 41);
        final result = resolveTrackCollisionForTest(
          collisionSystem,
          state,
          unitCircleConfig,
          collisionShapes: <TrackCollisionShape>[TrackPolygon(vertices)],
        );
        expect(result.contacts.single.type, CollisionType.trackObject);
        expect(state.y, closeTo(39, _tolerance));
      }
    });

    test('coincident cars separate along the fixed fallback normal', () {
      final first = CarState(x: 50, y: 50);
      final second = CarState(x: 50, y: 50);

      final result = collisionSystem.resolveCarCollision(
        firstState: first,
        firstConfig: unitCircleConfig,
        secondState: second,
        secondConfig: unitCircleConfig,
      );

      expect(result.collided, isTrue);
      expect(first.x, 49);
      expect(second.x, 51);
      expect(result.contacts.single.normalX, -1);
      expect(result.contacts.single.impactSpeed, 0);
    });

    test('tangent cars do not report a contact', () {
      final first = CarState(x: 60, y: 60);
      final second = CarState(x: 62, y: 60);

      final result = collisionSystem.resolveCarCollision(
        firstState: first,
        firstConfig: unitCircleConfig,
        secondState: second,
        secondConfig: unitCircleConfig,
      );

      expect(result.collided, isFalse);
      expect(first.x, 60);
      expect(second.x, 62);
    });

    test('configuration and resolution reject invalid collision settings', () {
      expect(
        () => CollisionConfig(wallSpeedRetention: -0.1),
        throwsArgumentError,
      );
      expect(() => CollisionConfig(carRestitution: 1.1), throwsArgumentError);
      expect(() => CollisionConfig(maxCarImpulse: -1), throwsArgumentError);
      expect(
        () => CarConfig(collisionRadius: 100, width: 200, length: 202),
        returnsNormally,
      );
      final oversizedConfig = CarConfig(
        collisionRadius: 100,
        width: 200,
        length: 202,
      );
      final state = CarState(x: 4, y: 6, rotationDegrees: 45);

      expect(
        () => resolveTrackCollisionForTest(
          collisionSystem,
          state,
          oversizedConfig,
        ),
        throwsArgumentError,
      );
      expect(state.x, 4);
      expect(state.y, 6);
    });
  });
}

const double _tolerance = 0.001;
