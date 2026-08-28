import 'package:toy_racers/simulation.dart';

CollisionResult resolveTrackCollisionForTest(
  CollisionSystem system,
  CarState state,
  CarConfig config, {
  List<TrackRectangle> innerObstacles = const <TrackRectangle>[],
  List<TrackCollisionShape> collisionShapes = const <TrackCollisionShape>[],
}) => system.resolveTrackCollision(
  state: state,
  config: config,
  track: _track(
    innerObstacles: innerObstacles,
    collisionShapes: collisionShapes,
  ),
);

Track _track({
  List<TrackRectangle> innerObstacles = const <TrackRectangle>[],
  List<TrackCollisionShape> collisionShapes = const <TrackCollisionShape>[],
}) {
  final bounds = TrackRectangle(0, 0, 100, 100);
  return Track.fromDefinition(
    id: 'collision-test',
    name: 'COLLISION TEST',
    worldBounds: bounds,
    cameraBounds: bounds,
    outerBoundary: bounds,
    innerObstacles: innerObstacles,
    collisionShapes: collisionShapes,
    backgroundSurface: SurfaceType.asphalt,
    startLine: StartLine(
      bounds: TrackRectangle(1, 1, 1, 1),
      forwardX: 1,
      forwardY: 0,
    ),
    checkpoints: <Checkpoint>[
      Checkpoint(
        order: 0,
        gate: TrackSegment(TrackPoint(2, 2), TrackPoint(3, 2)),
        forwardX: 1,
        forwardY: 0,
      ),
    ],
    startGrid: <StartGridPosition>[
      StartGridPosition(position: TrackPoint(5, 5), rotationDegrees: 0),
    ],
    racingLine: <TrackPoint>[
      TrackPoint(5, 5),
      TrackPoint(6, 5),
      TrackPoint(7, 5),
    ],
  );
}
