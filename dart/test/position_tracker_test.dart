import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/simulation.dart';

import '../tool/behavior_runner.dart';

void main() {
  final tracker = PositionTracker(_track());

  test('orders active participants by completed lap progress', () {
    final ranking = _ranking(tracker, <RaceCompetitor>[
      _competitor('one-lap', laps: 1, checkpoint: 2, x: 19),
      _competitor('three-laps', laps: 3, checkpoint: 0, x: 10),
      _competitor('two-laps', laps: 2, checkpoint: 2, x: 19),
    ]);

    expect(ranking, <String>['three-laps', 'two-laps', 'one-lap']);
  });

  test('orders active participants by checkpoint progress', () {
    final ranking = _ranking(tracker, <RaceCompetitor>[
      _competitor('first-gate', checkpoint: 1, x: 34),
      _competitor('second-gate', checkpoint: 2, x: 49),
      _competitor('start', checkpoint: 0, x: 19),
    ]);

    expect(ranking, <String>['second-gate', 'first-gate', 'start']);
  });

  test('orders active participants by path progress to the next gate', () {
    final ranking = _ranking(tracker, <RaceCompetitor>[
      _competitor('far', x: 5),
      _competitor('near', x: 19),
      _competitor('middle', x: 15),
    ]);

    expect(ranking, <String>['near', 'middle', 'far']);
  });

  test('uses stable IDs to break equal active-progress ties', () {
    final ranking = _ranking(tracker, <RaceCompetitor>[
      _competitor('bravo', x: 19),
      _competitor('alpha', x: 19),
    ]);

    expect(ranking, <String>['alpha', 'bravo']);
  });

  test('uses assigned finish position ahead of completed race progress', () {
    final ranking = _ranking(tracker, <RaceCompetitor>[
      _competitor(
        'second',
        finished: true,
        finishPosition: 2,
        laps: 20,
        checkpoint: 2,
      ),
      _competitor(
        'first',
        finished: true,
        finishPosition: 1,
        laps: 1,
        checkpoint: 0,
      ),
    ]);

    expect(ranking, <String>['first', 'second']);
  });

  test(
    'places finished participants before active participants in finish order',
    () {
      final ranking = _ranking(tracker, <RaceCompetitor>[
        _competitor('running', laps: 99, checkpoint: 2, x: 49),
        _competitor('second', finished: true, finishPosition: 2),
        _competitor('first', finished: true, finishPosition: 1),
      ]);

      expect(ranking, <String>['first', 'second', 'running']);
    },
  );

  test('rejects duplicate stable participant IDs', () {
    expect(
      () => tracker.positions(<RaceCompetitor>[
        _competitor('duplicate', x: 10),
        _competitor('duplicate', x: 19),
      ]),
      throwsArgumentError,
    );
  });

  group('race golden ranking', () {
    for (final scenario in _raceScenarios) {
      test('$scenario matches the Kotlin golden ranking and positions', () {
        final actual = _trace('../compatibility/scenarios/race/$scenario.json');
        final golden = _trace('../compatibility/golden/race/$scenario.json');
        final actualSamples = actual['samples'] as List<dynamic>;
        final goldenSamples = golden['samples'] as List<dynamic>;

        expect(actualSamples, hasLength(goldenSamples.length));
        for (var index = 0; index < goldenSamples.length; index++) {
          final actualSnapshot = _snapshotAt(actualSamples, index);
          final goldenSnapshot = _snapshotAt(goldenSamples, index);

          expect(actualSnapshot['ranking'], goldenSnapshot['ranking']);
          expect(
            _racePositions(actualSnapshot),
            _racePositions(goldenSnapshot),
          );
        }
      });
    }
  });
}

RaceCompetitor _competitor(
  String id, {
  int laps = 0,
  int checkpoint = 0,
  double x = 10,
  double y = 50,
  bool finished = false,
  int? finishPosition,
}) => RaceCompetitor(
  id: id,
  progress: RaceProgress(
    completedLaps: laps,
    currentCheckpointIndex: checkpoint,
    finished: finished,
    finishPosition: finishPosition,
  ),
  position: TrackPoint(x, y),
);

List<String> _ranking(
  PositionTracker tracker,
  Iterable<RaceCompetitor> competitors,
) => tracker.positions(competitors).keys.toList(growable: false);

Map<String, dynamic> _trace(String path) => jsonDecode(
  path.contains('/golden/')
      ? File(path).readAsStringSync()
      : CompatibilityTraceJson.encode(BehaviorRunner().run(File(path))),
) as Map<String, dynamic>;

Map<String, dynamic> _snapshotAt(List<dynamic> samples, int index) =>
    (samples[index] as Map<String, dynamic>)['snapshot']
        as Map<String, dynamic>;

Map<String, int> _racePositions(Map<String, dynamic> snapshot) => <String, int>{
  for (final participant
      in (snapshot['participants'] as List<dynamic>)
          .cast<Map<String, dynamic>>())
    participant['id'] as String: participant['racePosition'] as int,
};

Track _track() {
  final bounds = TrackRectangle(0, 0, 100, 100);
  return Track.fromDefinition(
    id: 'position-tracker-test',
    name: 'POSITION TRACKER TEST',
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
        gate: TrackSegment(TrackPoint(35, 40), TrackPoint(35, 60)),
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

const List<String> _raceScenarios = <String>[
  'checkpoint_progression',
  'final_lap_progression',
  'near_simultaneous_finish',
  'state_machine_lifecycle',
];
