import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  test('ReferenceAiDriver reset restores the deterministic decision state', () {
    final initialPosition = TrackPoint(0, 0);
    final config = AiConfig(
      mistakeCheckIntervalSeconds: 0.25,
      mistakeProbability: 0.5,
      mistakeDurationSeconds: 0.25,
    );
    final racingLine = <TrackPoint>[
      initialPosition,
      TrackPoint(10, 0),
      TrackPoint(20, 0),
    ];
    final context = AiRaceContext();
    final driver = _driver(racingLine, initialPosition, config);
    final carState = CarState(x: 0, y: 0);

    for (var tick = 0; tick < 12; tick++) {
      driver.update(carState: carState, deltaSeconds: 0.25, context: context);
    }
    driver.resetForRace(initialPosition);

    final resetInputs = _decisions(driver, carState, context, count: 12);
    final freshInputs = _decisions(
      _driver(racingLine, initialPosition, config),
      CarState(x: 0, y: 0),
      context,
      count: 12,
    );

    expect(resetInputs, freshInputs);
  });
}

ReferenceAiDriver _driver(
  List<TrackPoint> racingLine,
  TrackPoint initialPosition,
  AiConfig config,
) => ReferenceAiDriver(
  racingLine: racingLine,
  initialPosition: initialPosition,
  config: config,
  randomSeed: 59,
);

List<DriverInput> _decisions(
  ReferenceAiDriver driver,
  CarState carState,
  AiRaceContext context, {
  required int count,
}) => [
  for (var tick = 0; tick < count; tick++)
    driver
        .update(carState: carState, deltaSeconds: 0.25, context: context)
        .input,
];
