import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  final system = SurfaceSpeedSystem();
  final baseConfig = CarConfig();

  group('SurfaceSpeedSystem', () {
    test('slows down gradually and recovers at the reference rate', () {
      final car = _fullSpeedCar(baseConfig);
      final surfaceState = SurfaceSpeedState();

      _advance(
        system: system,
        car: car,
        config: baseConfig,
        surfaceState: surfaceState,
        surface: SurfaceType.grass,
        seconds: 1.5,
      );

      expect(surfaceState.speedMultiplier, closeTo(0.65, _tolerance));
      expect(
        car.longitudinalSpeed,
        closeTo(baseConfig.maxForwardSpeed * 0.65, _speedTolerance),
      );

      _advance(
        system: system,
        car: car,
        config: baseConfig,
        surfaceState: surfaceState,
        surface: SurfaceType.asphalt,
        seconds: 1.5,
      );

      expect(surfaceState.speedMultiplier, closeTo(1, _tolerance));
    });

    test('uses a shared multiplier for reverse and lateral speed limits', () {
      final reverseCar = CarState(
        velocityX: -baseConfig.maxReverseSpeed,
        longitudinalSpeed: -baseConfig.maxReverseSpeed,
      );
      final driftingCar = CarState(velocityY: baseConfig.maxForwardSpeed);
      final surfaceState = SurfaceSpeedState(speedMultiplier: 0.3);

      system.update(
        carState: reverseCar,
        carConfig: baseConfig,
        surfaceState: surfaceState,
        surface: SurfaceType.grass,
        deltaSeconds: Float32.fixedDeltaSeconds,
      );
      _advance(
        system: system,
        car: driftingCar,
        config: baseConfig,
        surfaceState: SurfaceSpeedState(),
        surface: SurfaceType.grass,
        seconds: 3,
      );

      expect(
        reverseCar.longitudinalSpeed,
        closeTo(-baseConfig.maxReverseSpeed * 0.3, _tolerance),
      );
      expect(
        driftingCar.lateralSpeed,
        closeTo(baseConfig.maxForwardSpeed * 0.3, _tolerance),
      );
      expect(driftingCar.velocityY, driftingCar.lateralSpeed);
    });

    test('reprojects limited speeds into the car heading', () {
      final car = CarState(
        rotationDegrees: 90,
        velocityX: -baseConfig.maxForwardSpeed,
        velocityY: baseConfig.maxForwardSpeed,
      );

      system.update(
        carState: car,
        carConfig: baseConfig,
        surfaceState: SurfaceSpeedState(),
        surface: SurfaceType.grass,
        deltaSeconds: 3,
      );

      expect(car.longitudinalSpeed, 10.200000762939453);
      expect(car.lateralSpeed, 10.200000762939453);
      expect(car.velocityX, -10.200000762939453);
      expect(car.velocityY, 10.200000762939453);
    });

    test('rejects invalid settings and negative steps', () {
      expect(
        () => SurfaceSpeedConfig(offRoadSpeedMultiplier: -0.1),
        throwsArgumentError,
      );
      expect(
        () => SurfaceSpeedConfig(offRoadSpeedMultiplier: 1.1),
        throwsArgumentError,
      );
      expect(
        () => SurfaceSpeedConfig(transitionSeconds: 0),
        throwsArgumentError,
      );
      expect(
        () => SurfaceSpeedState(speedMultiplier: -0.1),
        throwsArgumentError,
      );
      expect(
        () => SurfaceSpeedState(speedMultiplier: 1.1),
        throwsArgumentError,
      );
      expect(
        () => system.update(
          carState: CarState(),
          carConfig: baseConfig,
          surfaceState: SurfaceSpeedState(),
          surface: SurfaceType.asphalt,
          deltaSeconds: -Float32.fixedDeltaSeconds,
        ),
        throwsArgumentError,
      );
    });

    test('does not change state for a zero-duration update', () {
      final car = CarState(velocityX: baseConfig.maxForwardSpeed * 2);
      final surfaceState = SurfaceSpeedState(speedMultiplier: 0.3);

      system.update(
        carState: car,
        carConfig: baseConfig,
        surfaceState: surfaceState,
        surface: SurfaceType.grass,
        deltaSeconds: 0,
      );

      expect(surfaceState.speedMultiplier, Float32.narrow(0.3));
      expect(car.velocityX, baseConfig.maxForwardSpeed * 2);
    });
  });

  group('surface compatibility scenarios', () {
    test('asphalt behavior keeps the red stripe road allowance', () {
      final config = CarModel.redStripe.performance.applyTo();
      final car = _fullSpeedCar(config, speed: 34);

      system.update(
        carState: car,
        carConfig: config,
        surfaceState: SurfaceSpeedState(),
        surface: SurfaceType.asphalt,
        deltaSeconds: Float32.fixedDeltaSeconds,
      );

      expect(car.longitudinalSpeed, config.maxForwardSpeed);
    });

    test('parquet behavior applies blue stripe off-road allowance', () {
      final config = CarModel.blueStripe.performance.applyTo();
      final car = _fullSpeedCar(config, speed: 34);

      system.update(
        carState: car,
        carConfig: config,
        surfaceState: SurfaceSpeedState(speedMultiplier: 0.3),
        surface: SurfaceType.parquet,
        deltaSeconds: Float32.fixedDeltaSeconds,
      );

      expect(car.longitudinalSpeed, 8.160000801086426);
    });

    test('tile behavior applies yellow sport off-road allowance', () {
      final config = CarModel.yellowSport.performance.applyTo();
      final car = _fullSpeedCar(config, speed: 34);

      system.update(
        carState: car,
        carConfig: config,
        surfaceState: SurfaceSpeedState(speedMultiplier: 0.3),
        surface: SurfaceType.tile,
        deltaSeconds: Float32.fixedDeltaSeconds,
      );

      expect(car.longitudinalSpeed, 11.220001220703125);
    });

    test('asphalt to parquet transitions through the gradual allowance', () {
      final config = CarModel.greenRacer.performance.applyTo();
      final car = _fullSpeedCar(config);
      final surfaceState = SurfaceSpeedState();

      system.update(
        carState: car,
        carConfig: config,
        surfaceState: surfaceState,
        surface: SurfaceType.parquet,
        deltaSeconds: 1.5,
      );

      expect(surfaceState.speedMultiplier, closeTo(0.65, _tolerance));
      expect(
        car.longitudinalSpeed,
        closeTo(config.maxForwardSpeed * 0.65, _speedTolerance),
      );
    });

    test('parquet to asphalt transitions through the gradual recovery', () {
      final config = CarModel.orangeTruck.performance.applyTo();
      final car = _fullSpeedCar(config);
      final surfaceState = SurfaceSpeedState(speedMultiplier: 0.3);

      system.update(
        carState: car,
        carConfig: config,
        surfaceState: surfaceState,
        surface: SurfaceType.asphalt,
        deltaSeconds: 1.5,
      );

      expect(surfaceState.speedMultiplier, closeTo(0.65, _tolerance));
      expect(
        car.longitudinalSpeed,
        closeTo(config.maxForwardSpeed * 0.65, _speedTolerance),
      );
    });
  });

  test('uses the compatibility road mapping for every declared surface', () {
    final expectedMultipliers = <SurfaceType, double>{
      SurfaceType.asphalt: 1,
      SurfaceType.parquet: 0.3,
      SurfaceType.tile: 0.3,
      SurfaceType.grass: 0.3,
      SurfaceType.boost: 1,
      SurfaceType.oil: 1,
    };

    for (final entry in expectedMultipliers.entries) {
      final car = _fullSpeedCar(baseConfig);
      final surfaceState = SurfaceSpeedState();

      system.update(
        carState: car,
        carConfig: baseConfig,
        surfaceState: surfaceState,
        surface: entry.key,
        deltaSeconds: 3,
      );

      expect(
        entry.key.isRoad,
        entry.value == 1,
        reason: '${entry.key} road status',
      );
      expect(
        surfaceState.speedMultiplier,
        Float32.narrow(entry.value),
        reason: '${entry.key} multiplier',
      );
      expect(
        car.longitudinalSpeed,
        Float32.multiply(baseConfig.maxForwardSpeed, entry.value),
        reason: '${entry.key} speed limit',
      );
    }
  });
}

CarState _fullSpeedCar(CarConfig config, {double? speed}) {
  final longitudinalSpeed = speed ?? config.maxForwardSpeed;
  return CarState(
    velocityX: longitudinalSpeed,
    longitudinalSpeed: longitudinalSpeed,
  );
}

void _advance({
  required SurfaceSpeedSystem system,
  required CarState car,
  required CarConfig config,
  required SurfaceSpeedState surfaceState,
  required SurfaceType surface,
  required double seconds,
}) {
  final steps = (seconds / Float32.fixedDeltaSeconds).round();
  for (var step = 0; step < steps; step++) {
    system.update(
      carState: car,
      carConfig: config,
      surfaceState: surfaceState,
      surface: surface,
      deltaSeconds: Float32.fixedDeltaSeconds,
    );
  }
}

const double _tolerance = 0.001;
const double _speedTolerance = 0.01;
