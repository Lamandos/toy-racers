import 'package:toy_racers/simulation.dart';

/// Player-facing labels and bundled visual assets for immutable simulation IDs.
extension CarModelPresentation on CarModel {
  String get displayName => switch (this) {
    CarModel.redStripe => 'RED STRIPE',
    CarModel.blueStripe => 'BLUE STRIPE',
    CarModel.yellowSport => 'YELLOW SPORT',
    CarModel.greenRacer => 'GREEN RACER',
    CarModel.orangeTruck => 'ORANGE TRUCK',
  };

  String get spriteAsset => switch (this) {
    CarModel.redStripe => 'assets/sprites/cars/red-stripe.png',
    CarModel.blueStripe => 'assets/sprites/cars/blue-stripe.png',
    CarModel.yellowSport => 'assets/sprites/cars/yellow-sport.png',
    CarModel.greenRacer => 'assets/sprites/cars/green-racer.png',
    CarModel.orangeTruck => 'assets/sprites/cars/orange-truck.png',
  };
}
