import '../math/float32.dart';
import '../surface/surface_type.dart';
import 'checkpoint.dart';
import 'start_grid_position.dart';
import 'tiled_track_adapter.dart';
import 'track.dart';
import 'track_geometry.dart';
import 'track_id.dart';
import 'track_point.dart';

/// Reads canonical TMX text for the supplied repository-relative asset path.
///
/// Keeping this boundary synchronous and source-injected lets the simulation
/// run in a plain Dart process while presentation code can later supply bytes
/// from a Flutter asset bundle without making Flame a simulation dependency.
typedef TmxSource = String Function(String assetPath);

/// Supplies the immutable simulation data for the two built-in tracks.
///
/// Collision and asphalt contours always come from their committed TMX files.
/// Race metadata not represented by Tiled (bounds, gates, grid, and path) is
/// the direct deterministic port of Kotlin's `TrackLoader` constants.
final class TrackLoader {
  TrackLoader(this._tmxSource);

  static const double mapScale = 3;
  static const String track01TmxPath = 'assets/tracks/track_01.tmx';
  static const String track02TmxPath = 'assets/tracks/track_02.tmx';

  final TmxSource _tmxSource;

  /// Loads one built-in [trackId] from its canonical TMX source.
  Track load(TrackId trackId) {
    final objects = _adapterFor(trackId).parse(_tmxSource(tmxPath(trackId)));
    return switch (trackId) {
      TrackId.livingRoom => _createTrack01(objects),
      TrackId.bathroom => _createTrack02(objects),
    };
  }

  /// Loads a persisted compatibility track identifier.
  Track loadById(String trackId) => load(TrackId.fromId(trackId));

  /// Returns the repository-relative TMX source path for [trackId].
  static String tmxPath(TrackId trackId) => switch (trackId) {
    TrackId.livingRoom => track01TmxPath,
    TrackId.bathroom => track02TmxPath,
  };

  Track _createTrack01(TiledTrackObjects objects) => Track(
    id: TrackId.livingRoom.id,
    name: TrackId.livingRoom.displayName,
    worldBounds: _rectangle(0, 0, 36, 24),
    cameraBounds: _rectangle(0, 0, 36, 24),
    outerBoundary: _rectangle(0, 0, 36, 24),
    collisionShapes: objects.collisionShapes,
    backgroundSurface: SurfaceType.parquet,
    roadOuter: objects.roadOuter,
    roadInner: objects.roadInner,
    startLine: StartLine(
      bounds: _rectangle(18.1, 3.8, 0.6, 3.2),
      forwardX: 1,
      forwardY: 0,
    ),
    checkpoints: <Checkpoint>[
      _checkpoint(0, 23.8, 12, 35, 12, 0, 1),
      _checkpoint(1, 20.5, 16.5, 20.5, 20.5, -1, 0),
      _checkpoint(2, 1.1, 12, 12.3, 12, 0, -1),
    ],
    startGrid: <StartGridPosition>[
      _startPosition(16.5, 5.2),
      _startPosition(14, 5.7),
      _startPosition(11.5, 5.2),
      _startPosition(9, 5.7),
      _startPosition(9, 6.9),
      _startPosition(9, 7.5),
    ],
    racingLine: _track01RacingLine.map((point) => _point(point.x, point.y)),
    racingLineWaypointRadius: 10,
  );

  Track _createTrack02(TiledTrackObjects objects) => Track(
    id: TrackId.bathroom.id,
    name: TrackId.bathroom.displayName,
    worldBounds: _rectangle(0, 0, 36, 36),
    cameraBounds: _rectangle(0, 0, 36, 36),
    outerBoundary: _rectangle(0, 0, 36, 36),
    collisionShapes: objects.collisionShapes,
    backgroundSurface: SurfaceType.tile,
    roadOuter: objects.roadOuter,
    roadInner: objects.roadInner,
    startLine: StartLine(
      bounds: _rectangle(16.6, 4.2, 0.8, 2.6),
      forwardX: 1,
      forwardY: 0,
    ),
    checkpoints: <Checkpoint>[
      _checkpoint(0, 24, 12.5, 30.5, 12.5, 0, 1),
      _checkpoint(1, 19.2, 27.2, 19.2, 32.3, -1, 0),
      _checkpoint(2, 5.1, 20.2, 10.2, 20.2, 0, -1),
      _checkpoint(3, 13, 12, 17.4, 12, 0, -1),
      _checkpoint(4, 8, 6.5, 8, 10.3, 1, 0),
    ],
    startGrid: <StartGridPosition>[
      _startPosition(15.5, 5.3),
      _startPosition(13.5, 5.7),
      _startPosition(11.5, 5.3),
      _startPosition(10.5, 5.7),
      _startPosition(10.5, 6.9),
      _startPosition(10.5, 7.5),
    ],
    racingLine: _track02RacingLine.map((point) => _point(point.x, point.y)),
    racingLineWaypointRadius: 7,
  );

  TiledTrackAdapter _adapterFor(TrackId trackId) => switch (trackId) {
    TrackId.livingRoom => TiledTrackAdapter(
      imageWidthPixels: 1536,
      imageHeightPixels: 1024,
      authoredWidth: 36,
      worldScale: mapScale,
    ),
    TrackId.bathroom => TiledTrackAdapter(
      imageWidthPixels: 1254,
      imageHeightPixels: 1254,
      authoredWidth: 36,
      worldScale: mapScale,
    ),
  };

  static TrackRectangle _rectangle(
    double x,
    double y,
    double width,
    double height,
  ) => TrackRectangle(_scale(x), _scale(y), _scale(width), _scale(height));

  static Checkpoint _checkpoint(
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

  static TrackPoint _point(double x, double y) =>
      TrackPoint(_scale(x), _scale(y));

  static double _scale(double value) => Float32.multiply(value, mapScale);

  static StartGridPosition _startPosition(double x, double y) =>
      StartGridPosition(position: _point(x, y), rotationDegrees: 0);

  static const List<({double x, double y})> _track01RacingLine =
      <({double x, double y})>[
        (x: 12, y: 5.5),
        (x: 15, y: 5.75),
        (x: 18, y: 5.75),
        (x: 21, y: 5.75),
        (x: 23.8, y: 5.75),
        (x: 25.4, y: 5.96),
        (x: 26.9, y: 6.59),
        (x: 28.2, y: 7.58),
        (x: 29.2, y: 8.88),
        (x: 29.8, y: 10.38),
        (x: 30.05, y: 12),
        (x: 29.8, y: 13.62),
        (x: 29.2, y: 15.12),
        (x: 28.2, y: 16.42),
        (x: 26.9, y: 17.41),
        (x: 25.4, y: 18.04),
        (x: 23.8, y: 18.25),
        (x: 21, y: 18.25),
        (x: 18, y: 18.25),
        (x: 15, y: 18.25),
        (x: 12.3, y: 18.25),
        (x: 10.7, y: 18.04),
        (x: 9.2, y: 17.41),
        (x: 7.9, y: 16.42),
        (x: 6.9, y: 15.12),
        (x: 6.3, y: 13.62),
        (x: 6.05, y: 12),
        (x: 6.3, y: 10.38),
        (x: 6.9, y: 8.88),
        (x: 7.9, y: 7.58),
        (x: 9.2, y: 6.59),
        (x: 10.7, y: 5.96),
      ];

  static const List<({double x, double y})> _track02RacingLine =
      <({double x, double y})>[
        (x: 17.2, y: 5.3),
        (x: 21.5, y: 5.3),
        (x: 24.5, y: 6.4),
        (x: 26, y: 9.3),
        (x: 26, y: 12.5),
        (x: 28, y: 14.5),
        (x: 29, y: 17.5),
        (x: 27.5, y: 21.5),
        (x: 27, y: 25.5),
        (x: 24, y: 28.5),
        (x: 20.5, y: 29.2),
        (x: 18.5, y: 31),
        (x: 15, y: 31.5),
        (x: 11.5, y: 30),
        (x: 10, y: 26.8),
        (x: 9.5, y: 25.7),
        (x: 6, y: 22),
        (x: 5.2, y: 21.1),
        (x: 6.3, y: 19.6),
        (x: 10.5, y: 16),
        (x: 11.5, y: 19.9),
        (x: 13.8, y: 21.7),
        (x: 19, y: 24),
        (x: 21.2, y: 23),
        (x: 22, y: 20),
        (x: 20.5, y: 16.8),
        (x: 17, y: 13),
        (x: 17.2, y: 9),
        (x: 16.4, y: 8.4),
        (x: 14.9, y: 8.2),
        (x: 13.5, y: 9),
        (x: 13.2, y: 12),
        (x: 11.5, y: 15),
        (x: 8.5, y: 16),
        (x: 6.2, y: 14),
        (x: 6, y: 10.5),
        (x: 8, y: 7.5),
        (x: 11, y: 5.8),
        (x: 14, y: 5.3),
      ];
}
