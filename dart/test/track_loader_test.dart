import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  final loader = TrackLoader(_readCanonicalTmx);

  test('loads both canonical TMX tracks with Kotlin world dimensions', () {
    final livingRoom = loader.load(TrackId.livingRoom);
    final bathroom = loader.load(TrackId.bathroom);

    expect(livingRoom.id, 'track-01');
    expect(livingRoom.name, 'LIVING ROOM');
    expect(livingRoom.worldBounds, TrackRectangle(0, 0, 108, 72));
    expect(livingRoom.cameraBounds, livingRoom.worldBounds);
    expect(livingRoom.outerBoundary, livingRoom.worldBounds);
    expect(
      livingRoom.startLine.bounds,
      TrackRectangle(_world(18.1), _world(3.8), _world(0.6), _world(3.2)),
    );
    expect(livingRoom.checkpoints, hasLength(3));
    expect(livingRoom.collisionShapes, hasLength(28));
    expect(livingRoom.startGrid, hasLength(6));
    expect(livingRoom.racingLine, hasLength(32));
    expect(livingRoom.racingLineWaypointRadius, 10);

    expect(bathroom.id, 'track-02');
    expect(bathroom.name, 'BATHROOM');
    expect(bathroom.worldBounds, TrackRectangle(0, 0, 108, 108));
    expect(bathroom.cameraBounds, bathroom.worldBounds);
    expect(bathroom.outerBoundary, bathroom.worldBounds);
    expect(
      bathroom.startLine.bounds,
      TrackRectangle(_world(16.6), _world(4.2), _world(0.8), _world(2.6)),
    );
    expect(bathroom.checkpoints, hasLength(5));
    expect(bathroom.collisionShapes, hasLength(25));
    expect(bathroom.startGrid, hasLength(6));
    expect(bathroom.racingLine, hasLength(39));
    expect(bathroom.racingLineWaypointRadius, 7);
  });

  test('preserves Kotlin spawn, checkpoint, and racing-path metadata', () {
    final livingRoom = loader.loadById('track-01');
    final bathroom = loader.loadById('track-02');

    expect(livingRoom.startGrid, <StartGridPosition>[
      _spawn(16.5, 5.2),
      _spawn(14, 5.7),
      _spawn(11.5, 5.2),
      _spawn(9, 5.7),
      _spawn(9, 6.9),
      _spawn(9, 7.5),
    ]);
    expect(bathroom.startGrid, <StartGridPosition>[
      _spawn(15.5, 5.3),
      _spawn(13.5, 5.7),
      _spawn(11.5, 5.3),
      _spawn(10.5, 5.7),
      _spawn(10.5, 6.9),
      _spawn(10.5, 7.5),
    ]);
    expect(livingRoom.checkpoints, <Checkpoint>[
      _checkpoint(0, 23.8, 12, 35, 12, 0, 1),
      _checkpoint(1, 20.5, 16.5, 20.5, 20.5, -1, 0),
      _checkpoint(2, 1.1, 12, 12.3, 12, 0, -1),
    ]);
    expect(bathroom.checkpoints, <Checkpoint>[
      _checkpoint(0, 24, 12.5, 30.5, 12.5, 0, 1),
      _checkpoint(1, 19.2, 27.2, 19.2, 32.3, -1, 0),
      _checkpoint(2, 5.1, 20.2, 10.2, 20.2, 0, -1),
      _checkpoint(3, 13, 12, 17.4, 12, 0, -1),
      _checkpoint(4, 8, 6.5, 8, 10.3, 1, 0),
    ]);
    expect(livingRoom.racingLine.first, _point(12, 5.5));
    expect(livingRoom.racingLine.last, _point(10.7, 5.96));
    expect(bathroom.racingLine.first, _point(17.2, 5.3));
    expect(bathroom.racingLine.last, _point(14, 5.3));
  });

  test('converts Tiled pixels and layer offsets into world coordinates', () {
    final objects = TiledTrackAdapter(
      imageWidthPixels: 100,
      imageHeightPixels: 50,
      authoredWidth: 10,
      worldScale: 2,
    ).parse(_offsetTmx);

    final polygon = objects.collisionShapes.first as TrackPolygon;
    expect(polygon.vertices[0], TrackPoint(2.2, 5.4));
    expect(polygon.vertices[2], TrackPoint(6.2, 3.4));
    final circle = objects.collisionShapes[1] as TrackCircle;
    expect(circle.center, TrackPoint(9.2, 6.399999856948852));
    expect(circle.radius, 1);
  });

  test('uses canonical road contours for surfaces and collision geometry', () {
    final livingRoom = loader.load(TrackId.livingRoom);
    final bathroom = loader.load(TrackId.bathroom);

    expect(livingRoom.surfaceAtCoordinates(54, 18), SurfaceType.asphalt);
    expect(livingRoom.surfaceAtCoordinates(54, 36), SurfaceType.parquet);
    expect(livingRoom.surfaceAtCoordinates(54, 6), SurfaceType.parquet);
    expect(bathroom.surfaceAtCoordinates(40, 83), SurfaceType.tile);
    expect(
      (livingRoom.collisionShapes[3] as TrackPolygon).vertices,
      hasLength(24),
    );
    expect(
      (livingRoom.collisionShapes[3] as TrackPolygon).contains(100.85, 30.87),
      isTrue,
    );
    expect(
      (bathroom.collisionShapes.first as TrackPolygon).contains(40, 83),
      isTrue,
    );
    for (final track in <Track>[livingRoom, bathroom]) {
      expect(
        track.startGrid
            .map((spawn) => track.surfaceAt(spawn.position))
            .toList(),
        everyElement(SurfaceType.asphalt),
      );
      expect(
        track.racingLine.map(track.surfaceAt).toList(),
        everyElement(SurfaceType.asphalt),
      );
    }
  });

  test('keeps track collections immutable and rejects an unknown track ID', () {
    final track = loader.load(TrackId.livingRoom);

    expect(() => track.startGrid.add(_spawn(1, 1)), throwsUnsupportedError);
    expect(() => loader.loadById('missing-track'), throwsArgumentError);
  });
}

String _readCanonicalTmx(String assetPath) =>
    File('../$assetPath').readAsStringSync();

Checkpoint _checkpoint(
  int order,
  double startX,
  double startY,
  double endX,
  double endY,
  double forwardX,
  double forwardY,
) => Checkpoint(
  order: order,
  gate: TrackSegment(_point(startX, startY), _point(endX, endY)),
  forwardX: forwardX,
  forwardY: forwardY,
);

TrackPoint _point(double x, double y) => TrackPoint(_world(x), _world(y));

StartGridPosition _spawn(double x, double y) =>
    StartGridPosition(position: _point(x, y), rotationDegrees: 0);

double _world(double value) => Float32.multiply(value, TrackLoader.mapScale);

const String _offsetTmx = '''
<map>
  <imagelayer name="track" offsetx="5" offsety="4"/>
  <objectgroup name="road" offsetx="5" offsety="4">
    <object name="road_outer" x="0" y="50">
      <polygon points="0,-50 100,-50 100,0 0,0"/>
    </object>
    <object name="road_inner" x="25" y="35">
      <polygon points="0,-20 50,-20 50,0 0,0"/>
    </object>
  </objectgroup>
  <objectgroup name="collisions" offsetx="6" offsety="7">
    <object name="box" x="10" y="20">
      <polygon points="0,0 20,0 20,10 0,10"/>
    </object>
    <object name="cup" x="40" y="10" width="10" height="10"><ellipse/></object>
  </objectgroup>
</map>
''';
