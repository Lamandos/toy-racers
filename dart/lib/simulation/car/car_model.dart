import '../math/float32.dart';
import 'car_config.dart';

/// Player-selectable vehicle models with deterministic performance profiles.
enum CarModel {
  redStripe(
    scenarioId: 'red-stripe',
    performance: CarPerformance._fromEnum(
      acceleration: 1.10,
      maxSpeed: 0.95,
      handling: 0.80,
    ),
  ),
  blueStripe(
    scenarioId: 'blue-stripe',
    performance: CarPerformance._fromEnum(
      acceleration: 0.95,
      maxSpeed: 0.80,
      handling: 1.10,
    ),
  ),
  yellowSport(
    scenarioId: 'yellow-sport',
    performance: CarPerformance._fromEnum(
      acceleration: 0.80,
      maxSpeed: 1.10,
      handling: 0.95,
    ),
  ),
  greenRacer(
    scenarioId: 'green-racer',
    performance: CarPerformance._fromEnum(
      acceleration: 0.95,
      maxSpeed: 1.10,
      handling: 0.80,
    ),
  ),
  orangeTruck(
    scenarioId: 'orange-truck',
    performance: CarPerformance._fromEnum(
      acceleration: 0.80,
      maxSpeed: 0.95,
      handling: 1.10,
    ),
  );

  const CarModel({required this.scenarioId, required this.performance});

  final String scenarioId;
  final CarPerformance performance;

  /// Resolves the stable language-neutral ID used by compatibility scenarios.
  static CarModel fromScenarioId(String scenarioId) {
    for (final model in CarModel.values) {
      if (model.scenarioId == scenarioId) {
        return model;
      }
    }
    throw ArgumentError.value(scenarioId, 'scenarioId', 'Unknown scenario car');
  }
}

/// Relative tuning applied to the common [CarConfig] baseline.
final class CarPerformance {
  factory CarPerformance({
    required double acceleration,
    required double maxSpeed,
    required double handling,
  }) {
    return CarPerformance._fromEnum(
      acceleration: _validatedMultiplier(acceleration, 'acceleration'),
      maxSpeed: _validatedMultiplier(maxSpeed, 'maxSpeed'),
      handling: _validatedMultiplier(handling, 'handling'),
    );
  }

  const CarPerformance._fromEnum({
    required this.acceleration,
    required this.maxSpeed,
    required this.handling,
  });

  static const double _minimumMultiplier = 0.80;
  static const double _maximumMultiplier = 1.10;

  final double acceleration;
  final double maxSpeed;
  final double handling;

  static double _validatedMultiplier(double value, String name) {
    final narrowedValue = Float32.narrow(value);
    if (narrowedValue < _minimumMultiplier ||
        narrowedValue > _maximumMultiplier) {
      throw ArgumentError.value(
        value,
        name,
        'must be in the range [$_minimumMultiplier, $_maximumMultiplier]',
      );
    }
    return narrowedValue;
  }

  double get total =>
      Float32.add(Float32.add(acceleration, maxSpeed), handling);

  /// Applies this model's values without changing the common handling rules.
  CarConfig applyTo([CarConfig? base]) {
    final baseConfig = base ?? CarConfig();
    return CarConfig(
      acceleration: Float32.multiply(baseConfig.acceleration, acceleration),
      brakeForce: baseConfig.brakeForce,
      reverseAcceleration: baseConfig.reverseAcceleration,
      maxForwardSpeed: Float32.multiply(baseConfig.maxForwardSpeed, maxSpeed),
      maxReverseSpeed: baseConfig.maxReverseSpeed,
      steeringSpeed: Float32.multiply(baseConfig.steeringSpeed, handling),
      grip: baseConfig.grip,
      lateralFriction: baseConfig.lateralFriction,
      rollingResistance: baseConfig.rollingResistance,
      driftEntrySpeed: baseConfig.driftEntrySpeed,
      driftSteeringThreshold: baseConfig.driftSteeringThreshold,
      driftGripMultiplier: baseConfig.driftGripMultiplier,
      driftSteeringMultiplier: baseConfig.driftSteeringMultiplier,
      driftEntryResponse: baseConfig.driftEntryResponse,
      driftExitResponse: baseConfig.driftExitResponse,
      driftDrag: baseConfig.driftDrag,
      collisionRadius: baseConfig.collisionRadius,
      collisionLongitudinalOffset: baseConfig.collisionLongitudinalOffset,
      width: baseConfig.width,
      length: baseConfig.length,
    );
  }
}
