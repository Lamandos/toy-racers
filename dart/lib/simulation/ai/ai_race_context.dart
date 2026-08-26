import '../math/float32.dart';

/// A dynamic obstacle visible to an AI driver during one simulation tick.
final class AiObstacle {
  AiObstacle({
    required double x,
    required double y,
    required double radius,
    double speed = 0,
  }) : x = Float32.narrow(x),
       y = Float32.narrow(y),
       radius = Float32.narrow(radius),
       speed = Float32.narrow(speed);

  final double x;
  final double y;
  final double radius;
  final double speed;
}

/// Per-tick race state supplied to an [AiDriver].
final class AiRaceContext {
  AiRaceContext({
    Iterable<AiObstacle> obstacles = const <AiObstacle>[],
    this.finished = false,
    this.isOnTrack = true,
  }) : obstacles = List<AiObstacle>.unmodifiable(obstacles);

  final List<AiObstacle> obstacles;
  final bool finished;
  final bool isOnTrack;
}
