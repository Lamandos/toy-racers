import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  test('compatibility reports the player command applied by the session', () {
    final simulation = createCompatibilitySimulation(
      _scenario(),
      track: _track(),
    );
    simulation.start();
    simulation.finishCountdown();

    simulation.advance(
      input: PlayerInput(throttle: 2, brake: -1, steering: 1),
      deltaSeconds: CarPhysics.fixedDeltaSeconds,
    );

    expect(
      simulation.lastAppliedPlayerInput,
      PlayerInput(throttle: 1, brake: 0, steering: 0.85),
    );
  });
}

CompatibilityScenario _scenario() => CompatibilityScenario(
  schemaVersion: 1,
  id: 'applied-player-input',
  seed: '0',
  trackId: 'test-track',
  playerCar: 'red-stripe',
  inputOrigin: 'keyboard',
  tags: const <String>[],
  ticks: 1,
  snapshotIntervalTicks: 1,
  inputSegments: const <CompatibilityInputSegment>[],
  inputTweaks: const <CompatibilityInputTweak>[],
  initialStates: const <CompatibilityInitialState>[],
  fullRace: false,
);

Track _track() {
  final bounds = TrackRectangle(0, 0, 100, 100);
  return Track.fromDefinition(
    id: 'test-track',
    name: 'TEST TRACK',
    worldBounds: bounds,
    cameraBounds: bounds,
    outerBoundary: bounds,
    backgroundSurface: SurfaceType.asphalt,
    startLine: StartLine(
      bounds: TrackRectangle(50, 40, 2, 20),
      forwardX: 1,
      forwardY: 0,
    ),
    checkpoints: <Checkpoint>[
      Checkpoint(
        order: 0,
        gate: TrackSegment(TrackPoint(20, 40), TrackPoint(20, 60)),
        forwardX: 1,
        forwardY: 0,
      ),
    ],
    startGrid: List<StartGridPosition>.generate(
      6,
      (index) => StartGridPosition(
        position: TrackPoint(10, 10 + index * 10),
        rotationDegrees: 0,
      ),
    ),
    racingLine: <TrackPoint>[
      TrackPoint(10, 10),
      TrackPoint(20, 10),
      TrackPoint(50, 10),
    ],
  );
}
