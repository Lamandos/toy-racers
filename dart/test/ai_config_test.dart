import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  test('AiConfig rejects a negative overtake speed advantage', () {
    expect(() => AiConfig(overtakeSpeedAdvantage: -0.1), throwsArgumentError);
  });
}
