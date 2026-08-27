import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  final physics = CarPhysics();
  final config = CarConfig();

  test('normalizes each PlayerInput control to its reference range', () {
    expect(
      PlayerInput(throttle: 2, brake: -1, steering: -3).normalized(),
      PlayerInput(throttle: 1, brake: 0, steering: -1),
    );
  });

  test('keyboard and touch commands merge into one normalized PlayerInput', () {
    final keyboard = PlayerInput(throttle: 1, steering: -1);
    final touch = PlayerInput(brake: 1, steering: 1);

    expect(
      keyboard.combinedWith(touch),
      PlayerInput(throttle: 1, brake: 1, steering: 0),
    );
  });

  test('deprecated DriverInput retains its additive merge semantics', () {
    final first = DriverInput(throttle: 0.4, brake: 0.2, steering: 0.6);
    final second = DriverInput(throttle: 0.4, brake: 0.4, steering: -0.4);

    expect(
      first.combinedWith(second),
      DriverInput(throttle: 0.8, brake: 0.6, steering: Float32.add(0.6, -0.4)),
    );
  });

  test('PlayerControlConfig scales steering without changing pedals', () {
    final input = PlayerInput(throttle: 0.7, brake: 0.2, steering: -1);

    final adjusted = PlayerControlConfig().applyTo(input);

    expect(adjusted.throttle, input.throttle);
    expect(adjusted.brake, input.brake);
    expect(adjusted.steering, Float32.narrow(-0.85));
  });

  test(
    'CarModel resolves scenario IDs and applies its performance profile',
    () {
      final redStripe = CarModel.fromScenarioId('red-stripe');
      final applied = redStripe.performance.applyTo();

      expect(redStripe, CarModel.redStripe);
      expect(applied.acceleration, Float32.narrow(28.6));
      expect(applied.maxForwardSpeed, Float32.narrow(32.3));
      expect(applied.steeringSpeed, 116);
      expect(() => CarModel.fromScenarioId('unknown-car'), throwsArgumentError);
    },
  );

  test('CarPerformance validates multiplier bounds at runtime', () {
    final upperBound = CarPerformance(
      acceleration: 1.10,
      maxSpeed: 1,
      handling: 1,
    );

    expect(upperBound.acceleration, Float32.narrow(1.10));
    expect(
      CarModel.redStripe.performance.acceleration,
      upperBound.acceleration,
    );
    expect(
      () => CarPerformance(acceleration: 0.79, maxSpeed: 1, handling: 1),
      throwsArgumentError,
    );
    expect(
      () => CarPerformance(acceleration: 1, maxSpeed: 1.11, handling: 1),
      throwsArgumentError,
    );
  });

  test('CarState equality distinguishes positive and negative zero', () {
    final positiveZero = CarState();
    final negativeZero = CarState(x: -0.0);

    expect(positiveZero == negativeZero, isFalse);
    expect(negativeZero, negativeZero.copy());
  });

  test('uses the reference radians conversion for large headings', () {
    final state = CarState(rotationDegrees: 3.8907556e24);

    _update(physics, state, config, PlayerInput(throttle: 1));

    expect(state.rotationDegrees, 120);
    expect(state.velocityX, Float32.narrow(-0.33304566));
    expect(state.velocityY, Float32.narrow(-0.0012035221));
  });

  test('throttle accelerates forward and respects the forward speed limit', () {
    final state = CarState();

    _simulate(
      physics: physics,
      state: state,
      config: config,
      input: PlayerInput(throttle: 1),
      seconds: 10,
    );

    expect(state.longitudinalSpeed, config.maxForwardSpeed);
    expect(state.x, greaterThan(0));
    expect(state.y, 0);
  });

  test('brake reduces forward speed before engaging reverse', () {
    final state = CarState(longitudinalSpeed: 20, velocityX: 20);

    _simulate(
      physics: physics,
      state: state,
      config: config,
      input: PlayerInput(brake: 1),
      seconds: 0.25,
    );

    expect(state.longitudinalSpeed, inInclusiveRange(0, 20));
    expect(state.longitudinalSpeed, lessThan(20));
  });

  test('holding brake from rest reaches the reference reverse speed limit', () {
    final state = CarState();

    _simulate(
      physics: physics,
      state: state,
      config: config,
      input: PlayerInput(brake: 1),
      seconds: 5,
    );

    expect(state.longitudinalSpeed, -config.maxReverseSpeed);
    expect(state.x, lessThan(0));
  });

  test('steering changes heading only while moving', () {
    final stationary = CarState();
    final moving = CarState(longitudinalSpeed: 12, velocityX: 12);

    _update(physics, stationary, config, PlayerInput(steering: 1));
    _update(physics, moving, config, PlayerInput(steering: 1));

    expect(stationary.rotationDegrees, 0);
    expect(moving.rotationDegrees.abs(), greaterThan(0));
  });

  test('matches Kotlin velocity reconstruction after steering', () {
    // The scenario golden has another velocity reconstruction in
    // SurfaceSpeedSystem after this one. These are the raw CarPhysics states
    // observed from Kotlin immediately before that later pipeline stage.
    final state = CarState(longitudinalSpeed: 12, velocityX: 12);
    final handlingConfig = CarModel.redStripe.performance.applyTo();
    final expectedStates = <int, _ReferenceCarState>{
      1: const _ReferenceCarState(
        rotationDegrees: 1.6342038,
        velocityX: 11.932201,
        velocityY: 0.039687753,
        angularVelocity: 98.05222,
        longitudinalSpeed: 11.928479,
        lateralSpeed: -0.3006153,
      ),
      10: const _ReferenceCarState(
        rotationDegrees: 15.793542,
        velocityX: 11.067972,
        velocityY: 1.3840306,
        angularVelocity: 90.98581,
        longitudinalSpeed: 11.026835,
        lateralSpeed: -1.6806082,
      ),
      20: const _ReferenceCarState(
        rotationDegrees: 30.09106,
        velocityX: 9.473427,
        velocityY: 3.345108,
        angularVelocity: 81.51651,
        longitudinalSpeed: 9.873846,
        lateralSpeed: -1.8554597,
      ),
    };

    for (var tick = 1; tick <= 20; tick++) {
      _update(physics, state, handlingConfig, PlayerInput(steering: -0.85));
      final expected = expectedStates[tick];
      if (expected != null) {
        _expectReferenceState(state, expected);
      }
    }
  });

  test('grip removes lateral velocity after reconstructing velocity', () {
    final state = CarState(velocityY: 10);

    _update(physics, state, config, PlayerInput.none);

    expect(state.velocityY.abs(), lessThan(10));
    expect(state.lateralSpeed, state.velocityY);
  });

  test('drift retains more lateral velocity than normal grip', () {
    final drifting = CarState(longitudinalSpeed: 24, velocityX: 24);
    final normalGrip = drifting.copy();
    final driftConfig = CarConfig(rollingResistance: 0, driftDrag: 0);
    final noDriftConfig = CarConfig(
      rollingResistance: 0,
      driftDrag: 0,
      driftEntrySpeed: 100,
    );

    _update(physics, drifting, driftConfig, PlayerInput(steering: 1));
    _update(physics, normalGrip, noDriftConfig, PlayerInput(steering: 1));

    expect(drifting.driftAmount, greaterThan(0));
    expect(
      drifting.lateralSpeed.abs(),
      greaterThan(normalGrip.lateralSpeed.abs()),
    );
  });

  test('rolling resistance brings coasting forward velocity toward rest', () {
    final state = CarState(longitudinalSpeed: 20, velocityX: 20);

    _update(physics, state, config, PlayerInput.none);

    expect(state.longitudinalSpeed, lessThan(20));
    expect(state.longitudinalSpeed, greaterThan(0));
  });

  test(
    'steering reverses direction while backing up without entering drift',
    () {
      final state = CarState(longitudinalSpeed: -12, velocityX: -12);

      _update(physics, state, config, PlayerInput(steering: 1));

      expect(state.angularVelocity, greaterThan(0));
      expect(state.driftAmount, 0);
    },
  );

  test('physics normalizes raw input once at the simulation boundary', () {
    final rawState = CarState();
    final normalizedState = CarState();

    _update(
      physics,
      rawState,
      config,
      PlayerInput(throttle: 2, brake: -1, steering: -3),
    );
    _update(
      physics,
      normalizedState,
      config,
      PlayerInput(throttle: 1, brake: 0, steering: -1),
    );

    expect(rawState, normalizedState);
  });

  test('fixed-step updates remain deterministic', () {
    final first = CarState(longitudinalSpeed: 24, velocityX: 24);
    final second = first.copy();
    final inputs = <PlayerInput>[
      ...List<PlayerInput>.filled(60, PlayerInput(throttle: 0.8, steering: 1)),
      ...List<PlayerInput>.filled(
        60,
        PlayerInput(throttle: 0.6, steering: -0.8),
      ),
    ];

    for (final input in inputs) {
      _update(physics, first, config, input);
      _update(physics, second, config, input);
    }

    expect(first, second);
  });

  test('negative physics delta is rejected and zero delta preserves state', () {
    final state = CarState(x: 4, y: -3, rotationDegrees: 45);
    final before = state.copy();

    expect(
      () => physics.update(
        state: state,
        config: config,
        input: PlayerInput.none,
        deltaSeconds: -CarPhysics.fixedDeltaSeconds,
      ),
      throwsArgumentError,
    );
    physics.update(
      state: state,
      config: config,
      input: PlayerInput.none,
      deltaSeconds: 0,
    );

    expect(state, before);
  });
}

void _simulate({
  required CarPhysics physics,
  required CarState state,
  required CarConfig config,
  required PlayerInput input,
  required double seconds,
}) {
  final steps = (seconds / CarPhysics.fixedDeltaSeconds).floor();
  for (var step = 0; step < steps; step++) {
    _update(physics, state, config, input);
  }
}

void _update(
  CarPhysics physics,
  CarState state,
  CarConfig config,
  PlayerInput input,
) => physics.update(
  state: state,
  config: config,
  input: input,
  deltaSeconds: CarPhysics.fixedDeltaSeconds,
);

final class _ReferenceCarState {
  const _ReferenceCarState({
    required this.rotationDegrees,
    required this.velocityX,
    required this.velocityY,
    required this.angularVelocity,
    required this.longitudinalSpeed,
    required this.lateralSpeed,
  });

  final double rotationDegrees;
  final double velocityX;
  final double velocityY;
  final double angularVelocity;
  final double longitudinalSpeed;
  final double lateralSpeed;
}

void _expectReferenceState(CarState actual, _ReferenceCarState expected) {
  expect(actual.rotationDegrees, Float32.narrow(expected.rotationDegrees));
  expect(actual.velocityX, Float32.narrow(expected.velocityX));
  expect(actual.velocityY, Float32.narrow(expected.velocityY));
  expect(actual.angularVelocity, Float32.narrow(expected.angularVelocity));
  expect(actual.longitudinalSpeed, Float32.narrow(expected.longitudinalSpeed));
  expect(actual.lateralSpeed, Float32.narrow(expected.lateralSpeed));
}
