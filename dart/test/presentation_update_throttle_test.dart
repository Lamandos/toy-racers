import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/game/presentation_update_throttle.dart';

void main() {
  test(
    'limits presentation updates while preserving elapsed-time remainder',
    () {
      final throttle = PresentationUpdateThrottle(intervalSeconds: 0.1);

      expect(throttle.isDue(0.04), isFalse);
      expect(throttle.isDue(0.04), isFalse);
      expect(throttle.isDue(0.04), isTrue);
      expect(throttle.isDue(0.07), isFalse);
      expect(throttle.isDue(0.02), isTrue);
    },
  );

  test('rejects invalid intervals and ignores invalid elapsed time', () {
    expect(
      () => PresentationUpdateThrottle(intervalSeconds: 0),
      throwsArgumentError,
    );
    final throttle = PresentationUpdateThrottle(intervalSeconds: 0.1);

    expect(throttle.isDue(0), isFalse);
    expect(throttle.isDue(double.nan), isFalse);
    expect(throttle.isDue(double.infinity), isFalse);
    expect(throttle.isDue(0.1), isTrue);
  });

  test('reset discards retained presentation time', () {
    final throttle = PresentationUpdateThrottle(intervalSeconds: 0.1);

    expect(throttle.isDue(0.08), isFalse);
    throttle.reset();
    expect(throttle.isDue(0.08), isFalse);
    expect(throttle.isDue(0.02), isTrue);
  });
}
