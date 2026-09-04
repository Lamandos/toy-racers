import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/game/race_world.dart';
import 'package:toy_racers/simulation.dart';

import '../tool/performance_sanity.dart';
import '../tool/render_performance_sanity.dart';

void main() {
  test('car snapshots reuse storage without changing binary32 values', () {
    final source = CarState(
      x: -0.0,
      y: 12.5,
      rotationDegrees: 359.75,
      longitudinalSpeed: -4.25,
      velocityX: 2.5,
      velocityY: -3.5,
      angularVelocity: 0.125,
      lateralSpeed: -0.75,
      driftAmount: 0.625,
    );
    final target = CarState();

    target.copyFrom(source);

    expect(target, source);
    expect(Float32.bits(target.x), Float32.bits(source.x));
    source.x = 9;
    expect(target.x, -0.0);
  });

  test('long-race runner keeps production collection bounds fixed', () {
    final rss = <int>[
      100 * _bytesPerMiB,
      104 * _bytesPerMiB,
      106 * _bytesPerMiB,
      107 * _bytesPerMiB,
      108 * _bytesPerMiB,
    ];
    var rssIndex = 0;
    final report = PerformanceSanityRunner(rssReader: () => rss[rssIndex++])
        .run(
          const PerformanceSanityOptions(
            warmupTicks: 5,
            measuredTicks: 20,
            sampleEveryTicks: 5,
            allowedGrowthMiB: 4,
          ),
        );

    expect(report.memoryStable, isTrue);
    expect(report.laterHalfPeakGrowthBytes, 2 * _bytesPerMiB);
    expect(report.collectionBounds, <String, int>{
      'participants': 6,
      'opponents': 5,
      'trackInnerObstacles': 0,
      'trackCollisionShapes': 28,
      'trackSurfaceRegions': 0,
      'trackCheckpoints': 3,
      'trackStartGridPositions': 6,
      'trackRacingLinePoints': 32,
      'maximumAiObstaclesPerDriver': 5,
      'maximumSensorRaysPerDriver': 3,
      'maximumSensorSamplesPerRay': 20,
      'maximumCollisionCirclesPerCar': 3,
      'maximumCollisionResolutionPasses': 4,
      'maximumTrackContactsPerCar': 360,
      'maximumCarCollisionPairs': 15,
      'maximumFinishResults': 6,
      'renderCarComponents': 6,
      'renderWorldChildren': 8,
      'pendingAudioMixes': 1,
      'retainedCarStateCopiesPerParticipant': 3,
      'retainedTickHistoryEntries': 0,
    });
    expect(report.state['simulationTick'], 25);
  });

  test('fixed-input state is identical across independent long-race runs', () {
    const options = PerformanceSanityOptions(
      warmupTicks: 10,
      measuredTicks: 40,
      sampleEveryTicks: 10,
      stateOnly: true,
    );

    final first = PerformanceSanityRunner().run(options);
    final second = PerformanceSanityRunner().run(options);

    expect(second.state, first.state);
    expect(first.state['fingerprint'], hasLength(16));
    expect(first.rssSamplesBytes, isEmpty);
  });

  test(
    'released RSS is reported as zero growth rather than negative growth',
    () {
      final report = PerformanceSanityReport(
        options: const PerformanceSanityOptions(measuredTicks: 1),
        elapsed: const Duration(seconds: 1),
        rssSamplesBytes: const <int>[120, 130, 100, 110],
        collectionBounds: const <String, int>{},
        state: const <String, Object>{'fingerprint': 'test'},
      );

      expect(report.laterHalfPeakGrowthBytes, 0);
      expect(report.memoryStable, isTrue);
    },
  );

  test('render topology stays fixed while visual state is synchronized', () {
    final session = _singleCarSession();
    final world = RaceWorld(session: session);
    final cars = world.cars;
    final children = world.children.toList(growable: false);

    for (var frame = 0; frame < 1000; frame++) {
      world.synchronizeVisualState((frame % 60) / 60);
    }

    expect(world.cars, same(cars));
    expect(world.cars, hasLength(1));
    expect(world.children.toList(growable: false), orderedEquals(children));
    expect(world.children, hasLength(3));
  });

  test('performance options reject invalid collection intervals', () {
    expect(
      () =>
          PerformanceSanityOptions.parse(<String>['--sample-every-ticks', '0']),
      throwsArgumentError,
    );
  });

  test('render timing report rejects more than five percent slow frames', () {
    final stable = RenderingPerformanceReport.fromTimings(<FrameTiming>[
      ...List<FrameTiming>.filled(19, _timing(buildMicros: 1000)),
      _timing(buildMicros: 20000),
    ]);
    final unstable = RenderingPerformanceReport.fromTimings(<FrameTiming>[
      ...List<FrameTiming>.filled(18, _timing(buildMicros: 1000)),
      _timing(buildMicros: 20000),
      _timing(buildMicros: 20000, rasterMicros: 20000),
    ]);

    expect(stable.stable, isTrue);
    expect(stable.slowBuildFrames, 1);
    expect(unstable.stable, isFalse);
    expect(unstable.toJson()['result'], 'FAIL');
  });

  test('web cadence report applies the same slow-frame fraction', () {
    final stable = FrameCadenceReport.fromTimestamps(
      _timestamps(<int>[...List<int>.filled(19, 16000), 25000]),
    );
    final unstable = FrameCadenceReport.fromTimestamps(
      _timestamps(<int>[...List<int>.filled(18, 16000), 25000, 25000]),
    );

    expect(stable.stable, isTrue);
    expect(stable.slowFrames, 1);
    expect(unstable.stable, isFalse);
    expect(unstable.toJson()['measurement'], 'frameCadence');
  });
}

FrameTiming _timing({int buildMicros = 1000, int rasterMicros = 1000}) =>
    FrameTiming(
      vsyncStart: 0,
      buildStart: 0,
      buildFinish: buildMicros,
      rasterStart: buildMicros,
      rasterFinish: buildMicros + rasterMicros,
      rasterFinishWallTime: buildMicros + rasterMicros,
    );

List<Duration> _timestamps(List<int> intervalMicros) {
  var elapsed = Duration.zero;
  return <Duration>[
    elapsed,
    for (final interval in intervalMicros)
      elapsed += Duration(microseconds: interval),
  ];
}

RaceSession _singleCarSession() {
  final track = _track();
  return RaceSession(
    track: track,
    participants: <RaceParticipant>[
      RaceParticipant(
        id: 'player',
        carState: CarState(x: 10, y: 50),
        carConfig: CarConfig(),
      ),
    ],
  );
}

Track _track() {
  final bounds = TrackRectangle(0, 0, 100, 100);
  return Track.fromDefinition(
    id: 'performance-render-test',
    name: 'PERFORMANCE RENDER TEST',
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

const int _bytesPerMiB = 1024 * 1024;
