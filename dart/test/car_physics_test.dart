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
