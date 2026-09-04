import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:toy_racers/game/toy_racers_game.dart';

/// Profile-mode frame-timing probe for the production six-car race renderer.
///
/// Run this entry point with `flutter run --profile` on each target. The
/// machine-readable result is printed on one line after [reportPrefix].
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  final game = await ToyRacersGame.loadDefault();
  runApp(_PerformanceRace(game: game));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_measureAfterLoad(game));
  });
}

Future<void> _measureAfterLoad(ToyRacersGame game) async {
  try {
    await game.loaded.timeout(_loadTimeout);
    await game.ready().timeout(_loadTimeout);
    game.session.advanceLifecycle(
      elapsedSeconds: game.session.raceState.countdownDurationSeconds,
    );
    await Future<void>.delayed(_warmupDuration);
    final report = kIsWeb
        ? await FrameCadenceProbe(targetFrameCount: _targetFrameCount).run()
        : await RenderingPerformanceProbe(targetFrameCount: _targetFrameCount)
              .run();
    debugPrint('$reportPrefix${jsonEncode(report.toJson())}');
  } on Object catch (error, stackTrace) {
    debugPrint(
      '$reportPrefix${jsonEncode(<String, Object>{'schemaVersion': 1, 'result': 'FAIL', 'error': '$error', 'stackTrace': '$stackTrace'})}',
    );
  } finally {
    if (!kIsWeb) {
      await Future<void>.delayed(const Duration(seconds: 1));
      await SystemNavigator.pop();
    }
  }
}

final class _PerformanceRace extends StatelessWidget {
  const _PerformanceRace({required this.game});

  final ToyRacersGame game;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: const Color(0xff121e2e),
      child: GameWidget<ToyRacersGame>(game: game),
    ),
  );
}

/// Collects engine-reported UI and raster durations after asset warm-up.
final class RenderingPerformanceProbe {
  RenderingPerformanceProbe({
    this.targetFrameCount = _targetFrameCount,
    this.frameBudget = _frameBudget,
  }) {
    if (targetFrameCount <= 0) {
      throw ArgumentError.value(
        targetFrameCount,
        'targetFrameCount',
        'must be positive',
      );
    }
  }

  final int targetFrameCount;
  final Duration frameBudget;

  Future<RenderingPerformanceReport> run() async {
    final timings = <FrameTiming>[];
    final reachedTarget = Completer<void>();
    void collect(List<FrameTiming> batch) {
      final remaining = targetFrameCount - timings.length;
      if (remaining <= 0) {
        return;
      }
      timings.addAll(batch.take(remaining));
      if (timings.length >= targetFrameCount && !reachedTarget.isCompleted) {
        reachedTarget.complete();
      }
    }

    SchedulerBinding.instance.addTimingsCallback(collect);
    try {
      await reachedTarget.future.timeout(_measurementTimeout);
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(collect);
    }
    return RenderingPerformanceReport.fromTimings(
      timings.take(targetFrameCount),
      frameBudget: frameBudget,
    );
  }
}

/// Compact timing summary with an explicit, reusable stability threshold.
final class RenderingPerformanceReport implements RenderingPerformanceResult {
  RenderingPerformanceReport._({
    required this.frameCount,
    required this.frameBudget,
    required this.buildMicrosP90,
    required this.buildMicrosP99,
    required this.rasterMicrosP90,
    required this.rasterMicrosP99,
    required this.slowBuildFrames,
    required this.slowRasterFrames,
  });

  factory RenderingPerformanceReport.fromTimings(
    Iterable<FrameTiming> timings, {
    Duration frameBudget = _frameBudget,
  }) {
    final frames = timings.toList(growable: false);
    if (frames.isEmpty) {
      throw ArgumentError.value(timings, 'timings', 'must not be empty');
    }
    final buildMicros =
        frames.map((frame) => frame.buildDuration.inMicroseconds).toList()
          ..sort();
    final rasterMicros =
        frames.map((frame) => frame.rasterDuration.inMicroseconds).toList()
          ..sort();
    return RenderingPerformanceReport._(
      frameCount: frames.length,
      frameBudget: frameBudget,
      buildMicrosP90: _percentile(buildMicros, 0.90),
      buildMicrosP99: _percentile(buildMicros, 0.99),
      rasterMicrosP90: _percentile(rasterMicros, 0.90),
      rasterMicrosP99: _percentile(rasterMicros, 0.99),
      slowBuildFrames: _overBudget(buildMicros, frameBudget.inMicroseconds),
      slowRasterFrames: _overBudget(rasterMicros, frameBudget.inMicroseconds),
    );
  }

  final int frameCount;
  final Duration frameBudget;
  final int buildMicrosP90;
  final int buildMicrosP99;
  final int rasterMicrosP90;
  final int rasterMicrosP99;
  final int slowBuildFrames;
  final int slowRasterFrames;

  bool get stable =>
      slowBuildFrames / frameCount <= _allowedSlowFrameFraction &&
      slowRasterFrames / frameCount <= _allowedSlowFrameFraction;

  @override
  Map<String, Object> toJson() => <String, Object>{
    'schemaVersion': 1,
    'result': stable ? 'PASS' : 'FAIL',
    'measurement': 'engineFrameTiming',
    'target': kIsWeb ? 'web' : defaultTargetPlatform.name,
    'buildMode': kReleaseMode
        ? 'release'
        : kProfileMode
        ? 'profile'
        : 'debug',
    'frameCount': frameCount,
    'frameBudgetMicros': frameBudget.inMicroseconds,
    'allowedSlowFrameFraction': _allowedSlowFrameFraction,
    'buildMicrosP90': buildMicrosP90,
    'buildMicrosP99': buildMicrosP99,
    'rasterMicrosP90': rasterMicrosP90,
    'rasterMicrosP99': rasterMicrosP99,
    'slowBuildFrames': slowBuildFrames,
    'slowRasterFrames': slowRasterFrames,
  };

  static int _overBudget(List<int> durations, int budgetMicros) =>
      durations.where((duration) => duration > budgetMicros).length;

  static int _percentile(List<int> sorted, double percentile) {
    final index = (sorted.length * percentile).ceil() - 1;
    return sorted[index.clamp(0, sorted.length - 1)];
  }
}

/// Browser fallback because Flutter Web does not report engine frame timings.
final class FrameCadenceProbe {
  FrameCadenceProbe({this.targetFrameCount = _targetFrameCount}) {
    if (targetFrameCount <= 0) {
      throw ArgumentError.value(
        targetFrameCount,
        'targetFrameCount',
        'must be positive',
      );
    }
  }

  final int targetFrameCount;

  Future<FrameCadenceReport> run() async {
    final timestamps = <Duration>[];
    final reachedTarget = Completer<void>();
    var active = true;
    void collect(Duration timestamp) {
      if (!active) {
        return;
      }
      timestamps.add(timestamp);
      if (timestamps.length > targetFrameCount) {
        reachedTarget.complete();
        return;
      }
      SchedulerBinding.instance.addPostFrameCallback(collect);
    }

    SchedulerBinding.instance.addPostFrameCallback(collect);
    try {
      await reachedTarget.future.timeout(_measurementTimeout);
    } finally {
      active = false;
    }
    return FrameCadenceReport.fromTimestamps(timestamps);
  }
}

/// Vsync cadence summary used when per-thread frame timings are unavailable.
final class FrameCadenceReport implements RenderingPerformanceResult {
  FrameCadenceReport._({
    required this.frameCount,
    required this.intervalMicrosP90,
    required this.intervalMicrosP99,
    required this.slowFrames,
  });

  factory FrameCadenceReport.fromTimestamps(List<Duration> timestamps) {
    if (timestamps.length < 2) {
      throw ArgumentError.value(
        timestamps,
        'timestamps',
        'must contain at least two frames',
      );
    }
    final intervals = <int>[
      for (var index = 1; index < timestamps.length; index++)
        (timestamps[index] - timestamps[index - 1]).inMicroseconds,
    ]..sort();
    return FrameCadenceReport._(
      frameCount: intervals.length,
      intervalMicrosP90: _percentile(intervals, 0.90),
      intervalMicrosP99: _percentile(intervals, 0.99),
      slowFrames: intervals
          .where((duration) => duration > _cadenceBudget.inMicroseconds)
          .length,
    );
  }

  final int frameCount;
  final int intervalMicrosP90;
  final int intervalMicrosP99;
  final int slowFrames;

  bool get stable => slowFrames / frameCount <= _allowedSlowFrameFraction;

  @override
  Map<String, Object> toJson() => <String, Object>{
    'schemaVersion': 1,
    'result': stable ? 'PASS' : 'FAIL',
    'measurement': 'frameCadence',
    'target': 'web',
    'buildMode': kReleaseMode
        ? 'release'
        : kProfileMode
        ? 'profile'
        : 'debug',
    'frameCount': frameCount,
    'cadenceBudgetMicros': _cadenceBudget.inMicroseconds,
    'allowedSlowFrameFraction': _allowedSlowFrameFraction,
    'intervalMicrosP90': intervalMicrosP90,
    'intervalMicrosP99': intervalMicrosP99,
    'slowFrames': slowFrames,
  };

  static int _percentile(List<int> sorted, double percentile) {
    final index = (sorted.length * percentile).ceil() - 1;
    return sorted[index.clamp(0, sorted.length - 1)];
  }
}

abstract interface class RenderingPerformanceResult {
  Map<String, Object> toJson();
}

const String reportPrefix = 'TOY_RACERS_RENDER_PERFORMANCE=';
const Duration _cadenceBudget = Duration(milliseconds: 20);
const Duration _frameBudget = Duration(microseconds: 16667);
const Duration _loadTimeout = Duration(seconds: 15);
const Duration _measurementTimeout = Duration(seconds: 45);
const Duration _warmupDuration = Duration(seconds: 3);
const double _allowedSlowFrameFraction = 0.05;
const int _targetFrameCount = int.fromEnvironment(
  'TOY_RACERS_RENDER_FRAMES',
  defaultValue: 300,
);
