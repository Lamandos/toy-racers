import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  group('Float32', () {
    test(
      'round-trips positive zero and preserves negative zero until normalized',
      () {
        final positiveZero = Float32.narrow(0);
        final negativeZero = Float32.narrow(-0.0);

        expect(positiveZero, 0);
        expect(Float32.isNegativeZero(positiveZero), isFalse);
        expect(Float32.isNegativeZero(negativeZero), isTrue);
        expect(Float32.canonicalZero(negativeZero), 0);
        expect(
          Float32.isNegativeZero(Float32.canonicalZero(negativeZero)),
          isFalse,
        );
      },
    );

    test('rounds binary32 halfway values to even', () {
      const halfUlpAtOne = 0.000000059604644775390625;

      expect(Float32.narrow(1 + halfUlpAtOne), 1);
      expect(Float32.narrow(1 + 3 * halfUlpAtOne), 1.000000238418579);
    });

    test('matches Kotlin Float scalar arithmetic', () {
      expect(Float32.add(0.1, 0.2), 0.30000001192092896);
      expect(Float32.subtract(1, 1 / 3), 0.6666666269302368);
      expect(Float32.multiply(0.1, 0.2), 0.020000001415610313);
      expect(Float32.divide(1, 60), 0.01666666753590107);
      expect(Float32.remainder(-720.25, 360), -0.25);
    });

    test('clamps after binary32 narrowing', () {
      expect(Float32.clamp(-0.5, 0, 1), 0);
      expect(Float32.clamp(1.00000001, 0, 1), 1);
      expect(Float32.clamp(1.5, 0, 1), 1);
      expect(() => Float32.clamp(0, 1, 0), throwsArgumentError);
    });

    test('accumulates the fixed delta as repeated Kotlin Float addition', () {
      var elapsed = Float32.narrow(0);
      for (var tick = 0; tick < 60; tick++) {
        elapsed = Float32.add(elapsed, Float32.fixedDeltaSeconds);
      }

      expect(Float32.fixedDeltaSeconds, 0.01666666753590107);
      expect(elapsed, 0.9999997019767761);
      expect(Float32.elapsedSimulationTime(60), 1);
      expect(() => Float32.elapsedSimulationTime(-1), throwsArgumentError);
    });

    test('keeps binary32 values on opposite sides of comparator tolerance', () {
      const comparatorTolerance = 0.0001;
      final insideTolerance = Float32.narrow(0.00009999);
      final outsideTolerance = Float32.narrow(0.00010001);

      expect(insideTolerance, lessThanOrEqualTo(comparatorTolerance));
      expect(outsideTolerance, greaterThan(comparatorTolerance));
    });

    test(
      'narrows seeded state and AI inputs at Kotlin Float storage boundaries',
      () {
        final state = CarState(x: 0.1, y: -0.2, velocityX: 0.3);
        final obstacle = AiObstacle(x: 0.1, y: -0.2, radius: 0.3, speed: 0.4);

        expect(state.x, Float32.narrow(0.1));
        expect(state.y, Float32.narrow(-0.2));
        expect(state.velocityX, Float32.narrow(0.3));
        expect(obstacle.radius, Float32.narrow(0.3));
        expect(obstacle.speed, Float32.narrow(0.4));
      },
    );

    test('normalizes trace rotations and signed AI heading angles', () {
      expect(Float32.wrapDegrees(-720.25), 359.75);
      expect(Float32.isNegativeZero(Float32.wrapDegrees(-0.0)), isTrue);
      expect(Float32.normalizeRotationDegrees(-720.25), 359.75);
      expect(Float32.normalizeRotationDegrees(360), 0);
      expect(
        Float32.isNegativeZero(Float32.normalizeRotationDegrees(-0.0)),
        isFalse,
      );
      expect(Float32.normalizeSignedDegrees(180), -180);
      expect(Float32.normalizeSignedDegrees(540), -180);
    });

    test('normalizes input after binary32 tweak addition', () {
      final input = DriverInput(throttle: 0.7, brake: 1.1, steering: 0.7);
      final tweak = DriverInput(throttle: 0.2, brake: -0.2, steering: 0.2);

      final combined = input.combinedWith(tweak);

      expect(combined.throttle, 0.8999999761581421);
      expect(combined.brake, 0.9000000357627869);
      expect(combined.steering, 0.8999999761581421);
    });
  });
}
