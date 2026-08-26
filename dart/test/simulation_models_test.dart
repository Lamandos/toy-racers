import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  test('Float32 preserves the reference fixed delta representation', () {
    expect(Float32.narrow(1 / 60), 0.01666666753590107);
  });

  test('Float32 rejects finite values that overflow binary32', () {
    expect(() => Float32.narrow(1e100), throwsArgumentError);
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

  test('DriverInput adds a tweak before one normalization pass', () {
    final command = DriverInput(throttle: 0.8, brake: -0.2, steering: 0.9);
    final tweak = DriverInput(throttle: 0.4, brake: 0.4, steering: 0.3);

    expect(
      command.combinedWith(tweak),
      DriverInput(throttle: 1, brake: 0.2, steering: 1),
    );
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
}
