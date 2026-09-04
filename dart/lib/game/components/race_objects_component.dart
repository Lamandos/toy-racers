import 'dart:ui';

import 'package:flame/components.dart';
import 'package:toy_racers/simulation.dart';

import '../rendering/race_world_projection.dart';

/// Renders start and checkpoint gates already defined by the simulation track.
final class RaceObjectsComponent extends Component {
  RaceObjectsComponent({required this.track, required this.projection})
    : _startLineRectangle = projection.rectangleFor(track.startLine.bounds),
      _checkpointLines = List<(Offset, Offset)>.unmodifiable(
        track.checkpoints.map((checkpoint) {
          final start = projection.positionFor(
            checkpoint.gate.start.x,
            checkpoint.gate.start.y,
          );
          final end = projection.positionFor(
            checkpoint.gate.end.x,
            checkpoint.gate.end.y,
          );
          return (Offset(start.x, start.y), Offset(end.x, end.y));
        }),
      ),
      super(priority: 10);

  final Track track;
  final RaceWorldProjection projection;
  final Rect _startLineRectangle;
  final List<(Offset, Offset)> _checkpointLines;
  final Paint _startLinePaint = Paint()..color = const Color(0xfff5f2df);
  final Paint _checkpointPaint = Paint()
    ..color = const Color(0xff2463a2).withValues(alpha: 0.55)
    ..strokeWidth = 0.35
    ..strokeCap = StrokeCap.round;

  @override
  void render(Canvas canvas) {
    canvas.drawRect(_startLineRectangle, _startLinePaint);
    for (final line in _checkpointLines) {
      canvas.drawLine(line.$1, line.$2, _checkpointPaint);
    }
  }
}
