import '../math/float32.dart';
import 'car_config.dart';

/// Player-selectable vehicle models with deterministic performance profiles.
enum CarModel {
  redStripe(
    scenarioId: 'red-stripe',
    performance: CarPerformance._fromEnum(
      acceleration: 1.100000023841858,
      maxSpeed: 0.949999988079071,
      handling: 0.800000011920929,
    ),
  ),
  blueStripe(
    scenarioId: 'blue-stripe',
    performance: CarPerformance._fromEnum(
      acceleration: 0.949999988079071,
      maxSpeed: 0.800000011920929,
      handling: 1.100000023841858,
    ),
  ),
  yellowSport(
    scenarioId: 'yellow-sport',
    performance: CarPerformance._fromEnum(
      acceleration: 0.800000011920929,
      maxSpeed: 1.100000023841858,
      handling: 0.949999988079071,
    ),
  ),
  greenRacer(
    scenarioId: 'green-racer',
    performance: CarPerformance._fromEnum(
      acceleration: 0.949999988079071,
      maxSpeed: 1.100000023841858,
      handling: 0.800000011920929,
    ),
  ),
  orangeTruck(
    scenarioId: 'orange-truck',
    performance: CarPerformance._fromEnum(
      acceleration: 0.800000011920929,
      maxSpeed: 0.949999988079071,
      handling: 1.100000023841858,
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

  // These constants are the exact binary64 spellings of binary32 bounds.
  static const double _minimumMultiplier = 0.800000011920929;
  static const double _maximumMultiplier = 1.100000023841858;

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
        'must be in the range [0.80, 1.10]',
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
