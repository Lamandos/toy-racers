import 'dart:ui';

import 'package:flame/components.dart';
import 'package:toy_racers/simulation.dart';

import '../rendering/race_world_projection.dart';

/// Renders start and checkpoint gates already defined by the simulation track.
final class RaceObjectsComponent extends Component {
  RaceObjectsComponent({required this.track, required this.projection})
    : super(priority: 10);

  final Track track;
  final RaceWorldProjection projection;

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      projection.rectangleFor(track.startLine.bounds),
      Paint()..color = const Color(0xfff5f2df),
    );
    final checkpointPaint = Paint()
      ..color = const Color(0xff2463a2).withValues(alpha: 0.55)
      ..strokeWidth = 0.35
      ..strokeCap = StrokeCap.round;
    for (final checkpoint in track.checkpoints) {
      final start = projection.positionFor(
        checkpoint.gate.start.x,
        checkpoint.gate.start.y,
      );
      final end = projection.positionFor(
        checkpoint.gate.end.x,
        checkpoint.gate.end.y,
      );
      canvas.drawLine(
        Offset(start.x, start.y),
        Offset(end.x, end.y),
        checkpointPaint,
      );
    }
  }
}
