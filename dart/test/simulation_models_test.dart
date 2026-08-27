import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  test('Float32 preserves the reference fixed delta representation', () {
    expect(Float32.narrow(1 / 60), 0.01666666753590107);
  });

  test('Float32 rejects finite values that overflow binary32', () {
    expect(() => Float32.narrow(1e100), throwsArgumentError);
  });

  test('Float32 preserves arithmetic overflow as IEEE infinity', () {
    const maximumFiniteFloat32 = 3.4028234663852886e38;

    expect(
      Float32.add(maximumFiniteFloat32, maximumFiniteFloat32),
      double.infinity,
    );
    expect(
      Float32.subtract(-maximumFiniteFloat32, maximumFiniteFloat32),
      double.negativeInfinity,
    );
    expect(Float32.multiply(maximumFiniteFloat32, 2), double.infinity);
    expect(Float32.divide(maximumFiniteFloat32, 0.5), double.infinity);
    expect(Float32.divide(1, 0), double.infinity);
  });

  test('PlayerInput clamps binary32 input tweaks that overflow', () {
    const maximumFiniteFloat32 = 3.4028234663852886e38;

    expect(
      PlayerInput(throttle: maximumFiniteFloat32)
          .withTweak(PlayerInput(throttle: maximumFiniteFloat32)),
      PlayerInput(throttle: 1),
    );
  });

  test('CarConfig validates collision geometry using binary32 arithmetic', () {
    expect(
      () => CarConfig(
        collisionRadius: 5.960464477539063e-8,
        collisionLongitudinalOffset: 1,
        length: 2,
      ),
      returnsNormally,
    );
  });

  test('SimulationScenario preserves signed 64-bit seeds as decimal text', () {
    final scenario = SimulationScenario(
      id: 'maximum-seed',
      seed: '9223372036854775807',
      trackId: 'track-01',
      playerCarId: 'red-stripe',
      ticks: 1,
      snapshotIntervalTicks: 1,
    );

    expect(scenario.seed, '9223372036854775807');
    expect(scenario.seedValue, BigInt.parse('9223372036854775807'));
  });

  test('SimulationScenario rejects seeds outside signed 64-bit range', () {
    expect(
      () => SimulationScenario(
        id: 'overflowing-seed',
        seed: '9223372036854775808',
        trackId: 'track-01',
        playerCarId: 'red-stripe',
        ticks: 1,
        snapshotIntervalTicks: 1,
      ),
      throwsArgumentError,
    );
  });

  test('PlayerInput adds a tweak before one normalization pass', () {
    final command = PlayerInput(throttle: 0.8, brake: -0.2, steering: 0.9);
    final tweak = PlayerInput(throttle: 0.4, brake: 0.4, steering: 0.3);

    expect(
      command.withTweak(tweak),
      PlayerInput(throttle: 1, brake: 0.2, steering: 1),
    );
  });

  test('PlayerInput merges signed-zero pedals as positive zero', () {
    final merged = PlayerInput(
      throttle: 0,
      brake: 0,
    ).combinedWith(PlayerInput(throttle: -0.0, brake: -0.0));

    expect(Float32.isNegativeZero(merged.throttle), isFalse);
    expect(Float32.isNegativeZero(merged.brake), isFalse);
  });

  test('RaceSession begins with a deterministic headless snapshot', () {
    final racingLine = <TrackPoint>[
      TrackPoint(0, 0),
      TrackPoint(1, 0),
      TrackPoint(0, 1),
    ];
    final session = RaceSession(
      track: Track(id: 'test-track', racingLine: racingLine),
      participants: <RaceParticipant>[
        RaceParticipant(
          id: 'player',
          carState: CarState(),
          carConfig: CarConfig(),
        ),
      ],
    );
    racingLine.add(TrackPoint(1, 1));

    expect(session.snapshot.simulationTick, 0);
    expect(session.snapshot.racePhase, RacePhase.loading);
    expect(session.track.racingLine, hasLength(3));
  });

  test('RaceState advances countdown before allowing racing time', () {
    final raceState = RaceState();
    raceState.markReady();
    raceState.startCountdown();

    expect(raceState.advance(1), 0);
    expect(raceState.phase, RacePhase.countdown);
    expect(raceState.countdownRemainingSeconds, 2);

    expect(raceState.advance(2), 0);
    expect(raceState.phase, RacePhase.racing);
    expect(raceState.countdownRemainingSeconds, 0);
    expect(raceState.advance(1 / 60), Float32.narrow(1 / 60));
  });

  test('RaceState restart starts a fresh countdown from every phase', () {
    void expectRestartFrom(void Function(RaceState) prepare) {
      final raceState = RaceState();
      prepare(raceState);

      raceState.restart();

      expect(raceState.phase, RacePhase.countdown);
      expect(raceState.countdownRemainingSeconds, 3);
    }

    expectRestartFrom((_) {});
    expectRestartFrom((state) => state.markReady());
    expectRestartFrom((state) {
      state.markReady();
      state.startCountdown();
      state.advance(1);
    });
    expectRestartFrom((state) {
      state.markReady();
      state.startCountdown();
      state.advance(3);
    });
    expectRestartFrom((state) {
      state.markReady();
      state.startCountdown();
      state.advance(3);
      state.pause();
    });
    expectRestartFrom((state) {
      state.markReady();
      state.startCountdown();
      state.advance(3);
      state.finish();
    });
  });

  test('AiDriver receives the current race context on every update', () {
    final driver = _RecordingAiDriver();
    final firstContext = AiRaceContext(
      obstacles: <AiObstacle>[AiObstacle(x: 4, y: 1, radius: 0.5, speed: 2)],
      finished: false,
      isOnTrack: true,
    );
    final secondContext = AiRaceContext(finished: true, isOnTrack: false);

    driver.update(
      carState: CarState(),
      deltaSeconds: Float32.narrow(1 / 60),
      context: firstContext,
    );
    driver.update(
      carState: CarState(),
      deltaSeconds: Float32.narrow(1 / 60),
      context: secondContext,
    );

    expect(driver.contexts, hasLength(2));
    expect(driver.contexts[0], same(firstContext));
    expect(driver.contexts[1], same(secondContext));
    expect(driver.contexts[0].obstacles.single.speed, 2);
    expect(driver.contexts[1].finished, isTrue);
    expect(driver.contexts[1].isOnTrack, isFalse);
  });

  test('AiDriver can return a deterministic respawn request', () {
    final driver = _RecordingAiDriver(requestRespawn: true);

    final decision = driver.update(
      carState: CarState(),
      deltaSeconds: Float32.narrow(1 / 60),
      context: AiRaceContext(isOnTrack: false),
    );

    expect(decision.input, PlayerInput.none);
    expect(decision.requestRespawn, isTrue);
  });

  test('AI driver decisions preserve the deprecated input result type', () {
    final DriverInput command = AiDriverDecision(
      input: PlayerInput(throttle: 0.5),
    ).input;

    expect(command, DriverInput(throttle: 0.5));
  });
}

final class _RecordingAiDriver implements AiDriver {
  _RecordingAiDriver({this.requestRespawn = false});

  final bool requestRespawn;
  final List<AiRaceContext> contexts = <AiRaceContext>[];

  @override
  AiDriverDecision update({
    required CarState carState,
    required double deltaSeconds,
    required AiRaceContext context,
  }) {
    contexts.add(context);
    return AiDriverDecision(
      input: PlayerInput.none,
      requestRespawn: requestRespawn,
    );
  }
}
