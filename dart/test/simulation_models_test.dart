import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  test('Float32 preserves the reference fixed delta representation', () {
    expect(Float32.narrow(1 / 60), 0.01666666753590107);
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
