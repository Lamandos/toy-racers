import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:toy_racers/simulation.dart';

import 'race_minimap_state.dart';
import 'race_ui_controller.dart';

/// Screen-space map matching the Kotlin HUD's track outline and car markers.
final class RaceMinimap extends StatefulWidget {
  const RaceMinimap({required this.controller, super.key});

  static const Size preferredSize = Size(190, 142);

  final RaceMinimapController controller;

  @override
  State<RaceMinimap> createState() => _RaceMinimapWidgetState();
}

/// Converts upward-positive simulation coordinates into minimap pixels.
///
/// Keeping this rule explicit makes the Kotlin layout measurable without
/// relying on platform-specific rasterization.
final class RaceMinimapProjection {
  RaceMinimapProjection({
    required RaceMinimapTrack track,
    this.size = RaceMinimap.preferredSize,
    this.padding = _MinimapGeometry.contentPadding,
  }) : _worldBounds = track.worldBounds;

  final TrackRectangle _worldBounds;
  final Size size;
  final double padding;

  late final double scale = math.min(
    (size.width - padding * 2) / _worldBounds.width,
    (size.height - padding * 2) / _worldBounds.height,
  );
  late final double _offsetX = (size.width - _worldBounds.width * scale) / 2;
  late final double _offsetY = (size.height - _worldBounds.height * scale) / 2;

  Offset offsetFor(double worldX, double worldY) {
    final boundedX = worldX.clamp(_worldBounds.x, _worldBounds.maxX).toDouble();
    final boundedY = worldY.clamp(_worldBounds.y, _worldBounds.maxY).toDouble();
    return Offset(
      _offsetX + (boundedX - _worldBounds.x) * scale,
      _offsetY + (_worldBounds.maxY - boundedY) * scale,
    );
  }

  Rect rectangleFor(TrackRectangle rectangle) {
    final topLeft = offsetFor(rectangle.x, rectangle.maxY);
    return Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      rectangle.width * scale,
      rectangle.height * scale,
    );
  }
}

final class _RaceMinimapWidgetState extends State<RaceMinimap> {
  _MinimapGeometry? _geometry;
  late final _MinimapPaints _paints = _MinimapPaints();

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox.fromSize(
      size: RaceMinimap.preferredSize,
      child: AnimatedBuilder(
        animation: widget.controller.minimapFrame,
        builder: (context, child) {
          final state = widget.controller.minimapState;
          return CustomPaint(
            painter: _RaceMinimapPainter(
              state,
              _geometryFor(state.track),
              _paints,
            ),
            child: child,
          );
        },
      ),
    ),
  );

  _MinimapGeometry _geometryFor(RaceMinimapTrack track) {
    final existing = _geometry;
    if (existing != null && identical(existing.track, track)) {
      return existing;
    }
    return _geometry = _MinimapGeometry(track);
  }
}

final class _RaceMinimapPainter extends CustomPainter {
  _RaceMinimapPainter(this.state, this.geometry, this.paints);

  final RaceMinimapState state;
  final _MinimapGeometry geometry;
  final _MinimapPaints paints;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, paints.panel);
    canvas.drawRect(bounds, paints.border);
    _drawTrack(canvas);
    _drawParticipants(canvas);
  }

  void _drawTrack(Canvas canvas) {
    final fallback = geometry.fallbackRoad;
    if (fallback != null) {
      canvas.drawRect(fallback, paints.road);
      return;
    }
    canvas.drawPath(geometry.outerRoad!, paints.road);
    canvas.drawPath(geometry.innerRoad!, paints.road);
  }

  void _drawParticipants(Canvas canvas) {
    for (final participant in state.participants) {
      if (participant.role == RaceMinimapParticipantRole.opponent) {
        canvas.drawCircle(
          geometry.projection.offsetFor(participant.x, participant.y),
          _opponentRadius,
          paints.opponent,
        );
      }
    }
    for (final participant in state.participants) {
      if (participant.role == RaceMinimapParticipantRole.player) {
        _drawPlayer(canvas, participant);
      }
    }
  }

  void _drawPlayer(Canvas canvas, RaceMinimapParticipant participant) {
    final center = geometry.projection.offsetFor(participant.x, participant.y);
    final radians = -participant.rotationDegrees * math.pi / 180;
    final forward = Offset(math.cos(radians), math.sin(radians));
    final side = Offset(-forward.dy, forward.dx);
    final path = Path()
      ..moveTo(
        center.dx + forward.dx * _playerLength,
        center.dy + forward.dy * _playerLength,
      )
      ..lineTo(
        center.dx - forward.dx * _playerLength + side.dx * _playerHalfWidth,
        center.dy - forward.dy * _playerLength + side.dy * _playerHalfWidth,
      )
      ..lineTo(
        center.dx - forward.dx * _playerLength - side.dx * _playerHalfWidth,
        center.dy - forward.dy * _playerLength - side.dy * _playerHalfWidth,
      )
      ..close();
    canvas.drawPath(path, paints.player);
  }

  @override
  bool shouldRepaint(_RaceMinimapPainter oldDelegate) =>
      !identical(state, oldDelegate.state) ||
      !identical(geometry, oldDelegate.geometry);

  static const double _opponentRadius = 3.5;
  static const double _playerLength = 7;
  static const double _playerHalfWidth = 4.5;
}

/// Paints are owned by the minimap widget and reused for every marker frame.
final class _MinimapPaints {
  final Paint panel = Paint()..color = const Color(0xd1010610);
  final Paint border = Paint()
    ..color = const Color(0xf505b8ff)
    ..style = PaintingStyle.stroke;
  final Paint road = Paint()
    ..color = const Color(0xe661d1ff)
    ..style = PaintingStyle.stroke;
  final Paint opponent = Paint()..color = const Color(0xffd1dbe6);
  final Paint player = Paint()..color = const Color(0xffff40ad);
}

/// Preprojects immutable track contours once; render frames only move markers.
final class _MinimapGeometry {
  _MinimapGeometry(this.track)
    : projection = RaceMinimapProjection(track: track),
      outerRoad = _pathFor(track.outerRoad, track.worldBounds),
      innerRoad = _pathFor(track.innerRoad, track.worldBounds),
      fallbackRoad = _fallbackFor(track);

  final RaceMinimapTrack track;
  final RaceMinimapProjection projection;
  final Path? outerRoad;
  final Path? innerRoad;
  final Rect? fallbackRoad;

  static Path? _pathFor(
    List<TrackPoint>? vertices,
    TrackRectangle worldBounds,
  ) {
    if (vertices == null) {
      return null;
    }
    final projection = RaceMinimapProjection(
      track: RaceMinimapTrack(worldBounds: worldBounds),
    );
    final first = projection.offsetFor(vertices.first.x, vertices.first.y);
    final path = Path()..moveTo(first.dx, first.dy);
    for (final vertex in vertices.skip(1)) {
      final mapped = projection.offsetFor(vertex.x, vertex.y);
      path.lineTo(mapped.dx, mapped.dy);
    }
    return path..close();
  }

  static Rect? _fallbackFor(RaceMinimapTrack track) {
    if (track.outerRoad != null && track.innerRoad != null) {
      return null;
    }
    return RaceMinimapProjection(track: track).rectangleFor(track.worldBounds);
  }

  static const double contentPadding = 10;
}
