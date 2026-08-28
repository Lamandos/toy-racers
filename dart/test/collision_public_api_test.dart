import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/simulation/collision/collision_system.dart';

void main() {
  test('collision system URI exports CollisionResult', () {
    final result = CollisionResult(maxImpactSpeed: 2.5);

    expect(result.maxImpactSpeed, 2.5);
  });
}
