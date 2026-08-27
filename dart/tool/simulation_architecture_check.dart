import 'dart:io';

import 'package:toy_racers/simulation.dart';

import 'simulation_architecture.dart';

/// Verifies that the simulation assembly can start in a plain Dart process.
void main() {
  final violations = findSimulationArchitectureViolations(
    libDirectory: Directory('lib'),
  );
  if (violations.isNotEmpty) {
    stderr.writeln(violations.join('\n'));
    exitCode = 1;
    return;
  }

  final bounds = TrackRectangle(0, 0, 1, 1);
  final track = Track.fromDefinition(
    id: 'architecture-check',
    name: 'ARCHITECTURE CHECK',
    worldBounds: bounds,
    cameraBounds: bounds,
    outerBoundary: bounds,
    backgroundSurface: SurfaceType.asphalt,
    startLine: StartLine(
      bounds: TrackRectangle(0, 0, 0.1, 0.1),
      forwardX: 1,
      forwardY: 0,
    ),
    checkpoints: <Checkpoint>[
      Checkpoint(
        order: 0,
        gate: TrackSegment(TrackPoint(0, 0), TrackPoint(1, 0)),
        forwardX: 0,
        forwardY: 1,
      ),
    ],
    startGrid: <StartGridPosition>[
      StartGridPosition(position: TrackPoint(0, 0), rotationDegrees: 0),
    ],
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
