import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  late Track track;
  late RaceRules rules;

  setUp(() {
    track = _track();
    rules = RaceRules(track, requiredLaps: 2);
  });

  test('advances only the next checkpoint and rejects invalid crossings', () {
    final progress = RaceProgress();

    _crossCheckpoint(rules, progress, 1);
    _crossCheckpointBackward(rules, progress, 0);
    expect(progress.currentCheckpointIndex, 0);

    _crossCheckpoint(rules, progress, 0);
    _crossCheckpoint(rules, progress, 0);
    expect(progress.currentCheckpointIndex, 1);

    _crossCheckpoint(rules, progress, 1);
    expect(progress.currentCheckpointIndex, 2);
  });

  test(
    'records lap, race, and best-lap timers before deterministic finish',
    () {
      final progress = RaceProgress();

      _advanceTime(rules, progress, 12);
      _completeLap(rules, progress);
      _advanceTime(rules, progress, 10);
      _completeLap(rules, progress);

      expect(progress.completedLaps, 2);
      expect(progress.totalRaceTime, 22);
      expect(progress.bestLapTime, 10);
      expect(progress.finished, isTrue);
      expect(progress.finishPosition, 1);

      _advanceTime(rules, progress, 5);
      expect(progress.totalRaceTime, 22);
    },
  );

  test(
    'suppressed respawn movement advances time but not checkpoint progress',
    () {
      final progress = RaceProgress();

      rules.update(
        progress: progress,
        previousPosition: TrackPoint(19, 50),
        currentPosition: TrackPoint(21, 50),
        deltaSeconds: 1,
        allowProgress: false,
      );

      expect(progress.currentCheckpointIndex, 0);
      expect(progress.totalRaceTime, 1);
      expect(progress.finished, isFalse);
      expect(progress.finishPosition, isNull);
    },
  );

  test('continues restored finish ordering and rejects invalid ordering', () {
    final restored = RaceProgress(finished: true, finishPosition: 2);
    final next = RaceProgress();

    rules.synchronizeFinishOrdering(<RaceProgress>[restored]);
    _completeLap(rules, next);
    _completeLap(rules, next);

    expect(next.finishPosition, 3);
    expect(
      () => rules.synchronizeFinishOrdering(<RaceProgress>[
        RaceProgress(finished: true),
      ]),
      throwsArgumentError,
    );
    expect(
      () => rules.synchronizeFinishOrdering(<RaceProgress>[
        RaceProgress(finished: true, finishPosition: 4),
        RaceProgress(finished: true, finishPosition: 4),
      ]),
      throwsArgumentError,
    );
  });

  test('resets finish ordering for a fresh race', () {
    final firstRaceProgress = RaceProgress();
    _completeLap(rules, firstRaceProgress);
    _completeLap(rules, firstRaceProgress);
    expect(firstRaceProgress.finishPosition, 1);

    rules.resetFinishOrdering();

    final nextRaceProgress = RaceProgress();
    _completeLap(rules, nextRaceProgress);
    _completeLap(rules, nextRaceProgress);
    expect(nextRaceProgress.finishPosition, 1);
  });

  test('requires positive laps and non-negative simulation time', () {
    expect(() => RaceRules(track, requiredLaps: 0), throwsArgumentError);
    expect(
      () => rules.update(
        progress: RaceProgress(),
        previousPosition: TrackPoint(0, 0),
        currentPosition: TrackPoint(0, 0),
        deltaSeconds: -0.1,
      ),
      throwsArgumentError,
    );
  });
}

void _advanceTime(RaceRules rules, RaceProgress progress, double seconds) {
  rules.update(
    progress: progress,
    previousPosition: TrackPoint(10, 10),
    currentPosition: TrackPoint(10, 10),
    deltaSeconds: seconds,
  );
}

void _completeLap(RaceRules rules, RaceProgress progress) {
  _crossCheckpoint(rules, progress, 0);
  _crossCheckpoint(rules, progress, 1);
  rules.update(
    progress: progress,
    previousPosition: TrackPoint(50, 50),
    currentPosition: TrackPoint(52, 50),
    deltaSeconds: 0,
  );
}

void _crossCheckpoint(RaceRules rules, RaceProgress progress, int index) {
  final y = index == 0 ? 50.0 : 70.0;
  rules.update(
    progress: progress,
    previousPosition: TrackPoint(19, y),
    currentPosition: TrackPoint(21, y),
    deltaSeconds: 0,
  );
}

void _crossCheckpointBackward(
  RaceRules rules,
  RaceProgress progress,
  int index,
) {
  final y = index == 0 ? 50.0 : 70.0;
  rules.update(
    progress: progress,
    previousPosition: TrackPoint(21, y),
    currentPosition: TrackPoint(19, y),
    deltaSeconds: 0,
  );
}

Track _track() {
  final bounds = TrackRectangle(0, 0, 100, 100);
  return Track.fromDefinition(
    id: 'race-rules-test',
    name: 'RACE RULES TEST',
    worldBounds: bounds,
    cameraBounds: bounds,
    outerBoundary: bounds,
    backgroundSurface: SurfaceType.asphalt,
    startLine: StartLine(
      bounds: TrackRectangle(50, 40, 2, 20),
      forwardX: 1,
      forwardY: 0,
    ),
    checkpoints: <Checkpoint>[
      Checkpoint(
        order: 0,
        gate: TrackSegment(TrackPoint(20, 40), TrackPoint(20, 60)),
        forwardX: 1,
        forwardY: 0,
      ),
      Checkpoint(
        order: 1,
        gate: TrackSegment(TrackPoint(20, 60), TrackPoint(20, 80)),
        forwardX: 1,
        forwardY: 0,
      ),
    ],
    startGrid: <StartGridPosition>[
      StartGridPosition(position: TrackPoint(10, 50), rotationDegrees: 0),
    ],
    racingLine: <TrackPoint>[
      TrackPoint(10, 50),
      TrackPoint(20, 50),
      TrackPoint(50, 50),
    ],
  );
}
