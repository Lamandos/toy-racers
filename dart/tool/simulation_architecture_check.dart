import 'package:toy_racers/simulation.dart';

/// Verifies that the simulation assembly can start in a plain Dart process.
void main() {
  final track = Track(
    id: 'architecture-check',
    racingLine: <TrackPoint>[
      TrackPoint(0, 0),
      TrackPoint(1, 0),
      TrackPoint(0, 1),
    ],
  );
  final session = RaceSession(
    track: track,
    participants: <RaceParticipant>[
      RaceParticipant(
        id: 'player',
        carState: CarState(),
        carConfig: CarConfig(),
      ),
    ],
  );

  if (session.snapshot.racePhase != RacePhase.loading) {
    throw StateError('A new headless session must begin in the loading phase.');
  }
  // This command-line check intentionally reports its machine-readable result.
  // ignore: avoid_print
  print('simulation-architecture-ok');
}
