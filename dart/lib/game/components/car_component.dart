import 'dart:ui';

import 'package:flame/components.dart';
import 'package:toy_racers/simulation.dart';

import '../rendering/car_visual_state.dart';
import '../rendering/race_world_projection.dart';

/// Draws one car from a [RaceParticipant] state owned by [RaceSession].
final class CarComponent extends PositionComponent {
  CarComponent._({
    required this.participantId,
    required this._projection,
    required CarVisualState visualState,
    required CarConfig carConfig,
  }) : _visualState = visualState,
       super(
         position: visualState.position.clone(),
         size: Vector2(carConfig.length, carConfig.width),
         angle: visualState.angle,
         anchor: Anchor.center,
         priority: 20,
       );

  factory CarComponent.fromParticipant({
    required RaceParticipant participant,
    required RaceWorldProjection projection,
  }) {
    final visualState = CarVisualState.interpolate(
      previous: participant.carState,
      current: participant.carState,
      interpolationFactor: 0,
      projection: projection,
    );
    return CarComponent._(
      participantId: participant.id,
      projection: projection,
      visualState: visualState,
      carConfig: participant.carConfig,
    );
  }

  final String participantId;
  final RaceWorldProjection _projection;
  CarVisualState _visualState;

  CarVisualState get visualState => _visualState;

  /// Updates only the visible pose; it never writes to [participant].
  void synchronize(RaceParticipant participant, double interpolationFactor) {
    _visualState = CarVisualState.interpolate(
      previous: participant.previousState,
      current: participant.carState,
      interpolationFactor: interpolationFactor,
      projection: _projection,
    );
    position.setFrom(_visualState.position);
    angle = _visualState.angle;
  }

  @override
  void render(Canvas canvas) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(0.35),
    );
    canvas.drawRRect(body, Paint()..color = _bodyColor(participantId));
    canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0xff181a1f)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.12,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.x * 0.42, 0.15, size.x * 0.18, size.y - 0.3),
      Paint()..color = const Color(0xfff5f2df),
    );
    canvas.drawCircle(
      Offset(size.x * 0.78, size.y * 0.5),
      size.y * 0.16,
      Paint()..color = const Color(0xffd7efff),
    );
  }

  Color _bodyColor(String id) => switch (id) {
    'player' => const Color(0xffdc4d4d),
    'ai-0' => const Color(0xff4b88d5),
    'ai-1' => const Color(0xfff2c94c),
    'ai-2' => const Color(0xff57ae68),
    'ai-3' => const Color(0xffe28b3c),
    _ => const Color(0xffa568c9),
  };
}
