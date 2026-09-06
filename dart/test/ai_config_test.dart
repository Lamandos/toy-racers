import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  test('AiConfig rejects a negative overtake speed advantage', () {
    expect(() => AiConfig(overtakeSpeedAdvantage: -0.1), throwsArgumentError);
  });

  test(
    'difficulty profiles derive independent reference-compatible tuning',
    () {
      final base = AiConfig(
        straightSpeed: 20,
        cornerSpeed: 10,
        steeringResponse: 40,
        obstacleDetectionDistance: 8,
        staticObstacleReactionDistance: 6,
        avoidanceSteering: 0.8,
        overtakeSpeedAdvantage: 2,
        overtakeMinimumClearance: 4,
        mistakeProbability: 0.1,
        mistakeDurationSeconds: 0.2,
        mistakeSteering: 0.1,
      );

      final easy = base.forDifficulty(AiDifficulty.easy);
      final hard = base.forDifficulty(AiDifficulty.hard);

      expect(base.forDifficulty(AiDifficulty.normal), same(base));
      expect(easy.straightSpeed, lessThan(base.straightSpeed));
      expect(easy.cornerSpeed, lessThanOrEqualTo(easy.straightSpeed));
      expect(easy.steeringResponse, lessThan(base.steeringResponse));
      expect(
        easy.staticObstacleReactionDistance,
        inInclusiveRange(easy.sensorRayStep, easy.obstacleDetectionDistance),
      );
      expect(easy.mistakeProbability, Float32.narrow(0.18));
      expect(easy.mistakeDurationSeconds, Float32.narrow(0.4));
      expect(easy.mistakeSteering, Float32.narrow(0.28));
      expect(hard.straightSpeed, greaterThan(base.straightSpeed));
      expect(hard.cornerSpeed, lessThanOrEqualTo(hard.straightSpeed));
      expect(hard.steeringResponse, greaterThan(base.steeringResponse));
      expect(
        hard.obstacleDetectionDistance,
        greaterThan(base.obstacleDetectionDistance),
      );
      expect(
        hard.overtakeSpeedAdvantage,
        lessThan(base.overtakeSpeedAdvantage),
      );
      expect(hard.mistakeProbability, Float32.narrow(0.02));
      expect(hard.mistakeDurationSeconds, Float32.narrow(0.12));
      expect(hard.mistakeSteering, Float32.narrow(0.08));
    },
  );

  test('AiConfig rejects invalid geometry and normalized tuning values', () {
    expect(() => AiConfig(waypointRadius: 0), throwsArgumentError);
    expect(
      () => AiConfig(straightSpeed: 5, cornerSpeed: 6),
      throwsArgumentError,
    );
    expect(() => AiConfig(lookAheadPoints: 0), throwsArgumentError);
    expect(
      () => AiConfig(staticObstacleReactionDistance: 0.1),
      throwsArgumentError,
    );
    expect(() => AiConfig(avoidanceSteering: 1.1), throwsArgumentError);
  });
}
