import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:toy_racers/simulation.dart';

import '../rendering/car_visual_state.dart';
import '../rendering/presentation_catalog.dart';
import '../rendering/race_world_projection.dart';
import '../rendering/raster_asset_loader.dart';

/// Draws one car from a [RaceParticipant] state owned by [RaceSession].
final class CarComponent extends PositionComponent {
  CarComponent._({
    required this.participantId,
    required this.carModel,
    required this._projection,
    required CarVisualState visualState,
    required CarConfig carConfig,
  }) : _visualState = visualState,
       super(
         position: visualState.position.clone(),
         size: Vector2(carConfig.length, carConfig.width),
         angle: visualState.angle,
         anchor: Anchor.center,
         priority: _renderPriority(participantId, carModel),
       );

  factory CarComponent.fromParticipant({
    required RaceParticipant participant,
    required CarModel carModel,
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
      carModel: carModel,
      projection: projection,
      visualState: visualState,
      carConfig: participant.carConfig,
    );
  }

  final String participantId;
  final CarModel carModel;
  final RaceWorldProjection _projection;
  CarVisualState _visualState;
  Image? _sprite;

  CarVisualState get visualState => _visualState;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _sprite = await RasterAssetLoader.load(carModel.spriteAsset);
  }

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
    final sprite = _sprite;
    if (sprite == null) {
      return;
    }
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(math.pi / 2);
    canvas.drawImageRect(
      sprite,
      Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
      Rect.fromCenter(center: Offset.zero, width: size.y, height: size.x),
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
  }

  static int _renderPriority(String id, CarModel model) =>
      id == 'player' ? 30 : 20 + model.index;
}
