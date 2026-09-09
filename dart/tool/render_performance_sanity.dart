import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:toy_racers/game/toy_racers_game.dart';
import 'package:toy_racers/audio/game_audio_controller.dart';
import 'package:toy_racers/game/race_game_view.dart';
import 'package:toy_racers/game/ui/game_controls.dart';
import 'package:toy_racers/simulation.dart';
import 'package:toy_racers/presentation/virtual_presentation_viewport.dart';

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
  const trackName = String.fromEnvironment(
    'TOY_RACERS_TRACK',
    defaultValue: 'livingRoom',
  );
  final game = await ToyRacersGame.loadRace(
    trackId: TrackId.values.byName(trackName),
    playerCarModel: CarModel.redStripe,
  );
  const enableAudio = bool.fromEnvironment(
    'TOY_RACERS_AUDIO',
    defaultValue: true,
  );
  final audio = GameAudioController.production();
  await audio.prepare();
  game.attachAudio(enableAudio ? audio : GameAudioController.silent());
  runApp(
    GameAudioScope(
      audio: audio,
      child: _PerformanceRace(game: game),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_measureAfterLoad(game).whenComplete(audio.dispose));
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
    final reports = await Future.wait<RenderingPerformanceResult>([
      FrameCadenceProbe(targetFrameCount: _targetFrameCount).run(),
      if (!kIsWeb)
        RenderingPerformanceProbe(targetFrameCount: _targetFrameCount).run(),
    ]);
    final measurements = reports.map((report) => report.toJson()).toList();
    final payload = <String, Object>{
      'schemaVersion': 2,
      'result': measurements.every((report) => report['result'] == 'PASS')
          ? 'PASS'
          : 'FAIL',
      'track': game.session.track.id,
      'audioEnabled': const bool.fromEnvironment(
        'TOY_RACERS_AUDIO',
        defaultValue: true,
      ),
      'presentation': 'production HUD, minimap and platform controls',
      'measurements': measurements,
    };
    debugPrint('$reportPrefix${jsonEncode(payload)}');
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
    child: VirtualPresentationViewport(
      child: RaceGameView(
        game: game,
        showTouchControls:
            defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS,
        onExitRace: () {},
      ),
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

/// Measures actual frame cadence on every target, including platform stalls
/// that may not be included in engine build and raster durations.
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

/// Vsync cadence summary, reported alongside native per-thread frame timings.
final class FrameCadenceReport implements RenderingPerformanceResult {
  FrameCadenceReport._({
    required this.frameCount,
    required this.intervalMicrosP90,
    required this.intervalMicrosP99,
    required this.slowFrames,
    required this.averageFps,
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
      averageFps:
          intervals.length *
          Duration.microsecondsPerSecond /
          (timestamps.last - timestamps.first).inMicroseconds,
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
  final double averageFps;

  bool get stable => slowFrames / frameCount <= _allowedSlowFrameFraction;

  @override
  Map<String, Object> toJson() => <String, Object>{
    'schemaVersion': 1,
    'result': stable ? 'PASS' : 'FAIL',
    'measurement': 'frameCadence',
    'target': kIsWeb ? 'web' : defaultTargetPlatform.name,
    'averageFps': averageFps,
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
