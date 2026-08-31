import 'package:flame/components.dart';
import 'package:toy_racers/simulation.dart';

import 'components/car_component.dart';
import 'components/race_objects_component.dart';
import 'components/track_component.dart';
import 'rendering/race_world_projection.dart';

/// Flame world that displays one [RaceSession] without owning gameplay state.
final class RaceWorld extends World {
  RaceWorld._({
    required this.session,
    required this.projection,
    required Map<String, CarComponent> cars,
    required List<Component> children,
  }) : _cars = Map<String, CarComponent>.unmodifiable(cars),
       super(children: children);

  factory RaceWorld({
    required RaceSession session,
    Map<String, CarModel>? carModels,
  }) {
    final projection = RaceWorldProjection(session.track.worldBounds);
    final cars = <String, CarComponent>{
      for (final participant in session.participants)
        participant.id: CarComponent.fromParticipant(
          participant: participant,
          carModel: carModels?[participant.id] ?? CarModel.redStripe,
          projection: projection,
        ),
    };
    return RaceWorld._(
      session: session,
      projection: projection,
      cars: cars,
      children: <Component>[
        TrackComponent(track: session.track, projection: projection),
        RaceObjectsComponent(track: session.track, projection: projection),
        ..._carsInRenderOrder(session, cars),
      ],
    );
  }

  final RaceSession session;
  final RaceWorldProjection projection;
  final Map<String, CarComponent> _cars;

  Map<String, CarComponent> get cars => _cars;
  CarComponent get playerCar => _cars[session.player.id]!;

  /// Copies simulation observations into render components without mutation.
  void synchronizeVisualState(double interpolationFactor) {
    for (final participant in session.participants) {
      _cars[participant.id]!.synchronize(participant, interpolationFactor);
    }
  }

  static List<CarComponent> _carsInRenderOrder(
    RaceSession session,
    Map<String, CarComponent> cars,
  ) =>
      session.opponents.map((participant) => cars[participant.id]!).toList()
        ..add(cars[session.player.id]!);
}
