import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/simulation.dart';

import 'collision_test_support.dart';

void main() {
  final collisionSystem = CollisionSystem();
  final carConfig = CarConfig();

  group('collision compatibility scenarios', () {
    test('head-on car collision reports contact and transfers momentum', () {
      final first = _car(x: 0, rotation: 0, velocityX: 12);
      final second = _car(x: 2.5, rotation: 180, velocityX: -12);

      final result = _collide(collisionSystem, first, second, carConfig);

      _expectCarContact(result);
      expect(result.maxImpactSpeed, closeTo(24, _tolerance));
      _expectSeparated(first, second, carConfig);
      expect(first.velocityX, lessThan(12));
      expect(second.velocityX, greaterThan(-12));
    });

    test('side collision reports contact and redirects lateral movement', () {
      final first = _car(y: 0, rotation: 0, velocityY: 8);
      final second = _car(y: 2, rotation: 90);

      final result = _collide(collisionSystem, first, second, carConfig);

      _expectCarContact(result);
      _expectSeparated(first, second, carConfig);
      expect(first.velocityY, lessThan(8));
      expect(second.velocityY, greaterThan(0));
    });

    test('rear collision reports contact and accelerates leading car', () {
      final first = _car(x: 0, rotation: 0, velocityX: 8);
      final second = _car(x: 2.5, rotation: 0, velocityX: 2);

      final result = _collide(collisionSystem, first, second, carConfig);

      _expectCarContact(result);
      _expectSeparated(first, second, carConfig);
      expect(first.velocityX, lessThan(8));
      expect(second.velocityX, greaterThan(2));
    });

    test('glancing collision imparts diagonal velocity', () {
      final first = _car(x: 0, y: 0, rotation: 20, velocityX: 10);
      final second = _car(x: 2.5, y: 0.8, rotation: 200);

      final result = _collide(collisionSystem, first, second, carConfig);

      _expectCarContact(result);
      _expectSeparated(first, second, carConfig);
      expect(second.velocityX, greaterThan(0));
      expect(second.velocityY, greaterThan(0));
    });

    test('low speed collision preserves the low impact result', () {
      final first = _car(x: 0, rotation: 0, velocityX: 1);
      final second = _car(x: 2.5, rotation: 180);

      final result = _collide(collisionSystem, first, second, carConfig);

      _expectCarContact(result);
      expect(result.maxImpactSpeed, closeTo(1, _tolerance));
      _expectSeparated(first, second, carConfig);
      expect(second.velocityX, inInclusiveRange(0, 1));
    });

    test('high speed collision caps impulse while reporting full impact', () {
      final first = _car(x: 0, rotation: 0, velocityX: 100);
      final second = _car(x: 2.5, rotation: 180);

      final result = _collide(collisionSystem, first, second, carConfig);

      _expectCarContact(result);
      expect(result.maxImpactSpeed, closeTo(100, _tolerance));
      _expectSeparated(first, second, carConfig);
      expect(second.velocityX, closeTo(8, _tolerance));
    });

    test('car track collision removes outward velocity', () {
      final state = _car(x: 0.2, y: 6, velocityX: -10);

      final result = resolveTrackCollisionForTest(
        collisionSystem,
        state,
        carConfig,
      );

      expect(result.contacts, hasLength(1));
      expect(result.contacts.single.type, CollisionType.worldBoundary);
      expect(state.x, closeTo(1.62, _tolerance));
      expect(state.velocityX, 0);
    });

    test('repeated contact reports every tick and stays inside', () {
      final state = _car(x: 0.5, y: 6, velocityX: -4);

      for (var tick = 0; tick < 3; tick++) {
        state.x = 0.5;
        state.velocityX = -4;
        final result = resolveTrackCollisionForTest(
          collisionSystem,
          state,
          carConfig,
        );
        expect(result.collided, isTrue);
        expect(result.contacts.single.type, CollisionType.worldBoundary);
        expect(state.x, closeTo(1.62, _tolerance));
        expect(state.velocityX, 0);
      }
    });

    test('collision near track corner preserves x-then-y contact ordering', () {
      final state = _car(x: 0.5, y: 0.5, velocityX: -8, velocityY: -8);

      final result = resolveTrackCollisionForTest(
        collisionSystem,
        state,
        carConfig,
      );

      expect(result.contacts.map((contact) => contact.type), <CollisionType>[
        CollisionType.worldBoundary,
        CollisionType.worldBoundary,
      ]);
      expect(result.contacts[0].normalX, 1);
      expect(result.contacts[0].normalY, 0);
      expect(result.contacts[1].normalX, 0);
      expect(result.contacts[1].normalY, 1);
      expect(state.x, closeTo(1.62, _tolerance));
      expect(state.y, closeTo(carConfig.collisionRadius, _tolerance));
      expect(state.velocityX, 0);
      expect(state.velocityY, 0);
    });

    test('cars separating after collision keep increasing their distance', () {
      final first = _car(x: 0, rotation: 0, velocityX: 8);
      final second = _car(x: 2.5, rotation: 180);

      _expectCarContact(_collide(collisionSystem, first, second, carConfig));
      final distanceAfterCollision = _distance(first, second);
      first.x += first.velocityX;
      second.x += second.velocityX;

      expect(_distance(first, second), greaterThan(distanceAfterCollision));
    });

    test('near cars do not create a false-positive contact', () {
      final first = _car(x: 0, rotation: 0);
      final second = _car(x: 3.25, rotation: 180);

      final result = _collide(collisionSystem, first, second, carConfig);

      expect(result.collided, isFalse);
      expect(first.x, 0);
      expect(second.x, Float32.narrow(3.25));
      expect(first.velocityX, 0);
      expect(second.velocityX, 0);
    });
  });
}

CarState _car({
  double x = 0,
  double y = 0,
  double rotation = 0,
  double velocityX = 0,
  double velocityY = 0,
}) => CarState(
  x: x,
  y: y,
  rotationDegrees: rotation,
  velocityX: velocityX,
  velocityY: velocityY,
);

CollisionResult _collide(
  CollisionSystem system,
  CarState first,
  CarState second,
  CarConfig config,
) => system.resolveCarCollision(
  firstState: first,
  firstConfig: config,
  secondState: second,
  secondConfig: config,
);

void _expectCarContact(CollisionResult result) {
  expect(result.collided, isTrue);
  expect(result.contacts, hasLength(1));
  expect(result.contacts.single.type, CollisionType.car);
}

void _expectSeparated(CarState first, CarState second, CarConfig config) {
  for (final firstCircle in _circles(first, config)) {
    for (final secondCircle in _circles(second, config)) {
      expect(
        _distanceCoordinates(
          secondCircle.$1 - firstCircle.$1,
          secondCircle.$2 - firstCircle.$2,
        ),
        greaterThanOrEqualTo(firstCircle.$3 + secondCircle.$3 - _tolerance),
      );
    }
  }
}

List<(double, double, double)> _circles(CarState state, CarConfig config) {
  final radians = state.rotationDegrees * math.pi / 180;
  final offsets = config.collisionLongitudinalOffset == 0
      ? const <double>[0]
      : const <double>[-1, 0, 1];
  return <(double, double, double)>[
    for (final multiplier in offsets)
      (
        state.x +
            math.cos(radians) * config.collisionLongitudinalOffset * multiplier,
        state.y +
            math.sin(radians) * config.collisionLongitudinalOffset * multiplier,
        config.collisionRadius,
      ),
  ];
}

double _distance(CarState first, CarState second) =>
    _distanceCoordinates(second.x - first.x, second.y - first.y);

double _distanceCoordinates(double x, double y) => math.sqrt(x * x + y * y);

const double _tolerance = 0.001;
