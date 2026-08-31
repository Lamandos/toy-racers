import 'package:toy_racers/simulation.dart';

/// Maps render-only sprite choices to the stable participant identifiers.
final class RaceCarModels {
  const RaceCarModels._();

  static Map<String, CarModel> forSession({
    required RaceSession session,
    required CarModel playerCarModel,
    required List<CarModel> opponentCarModels,
  }) {
    final models = <String, CarModel>{session.player.id: playerCarModel};
    final availableModels = opponentCarModels.isEmpty
        ? CarModel.values
        : opponentCarModels;
    for (var index = 0; index < session.opponents.length; index++) {
      models[session.opponents[index].id] =
          availableModels[index % availableModels.length];
    }
    return Map<String, CarModel>.unmodifiable(models);
  }

  static List<CarModel> opponentsFor(CarModel player) {
    final opponents = CarModel.values
        .where((model) => model != player)
        .toList(growable: false);
    return List<CarModel>.unmodifiable(<CarModel>[
      ...opponents,
      opponents.first,
    ]);
  }
}
