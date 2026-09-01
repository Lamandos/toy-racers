import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/audio/audio_assets.dart';
import 'package:toy_racers/audio/audio_backend.dart';
import 'package:toy_racers/audio/audio_settings.dart';
import 'package:toy_racers/audio/game_audio_controller.dart';
import 'package:toy_racers/game/ui/game_controls.dart';
import 'package:toy_racers/main.dart';
import 'package:toy_racers/simulation.dart';

void main() {
  const nativePolicy = AudioPlaybackPolicy(
    requiresUserGesture: false,
    supportsPreload: true,
  );

  test(
    'native smoke: menu music initializes and preloads bundled audio',
    () async {
      final backend = _RecordingAudioBackend();
      final audio = GameAudioController(backend: backend, policy: nativePolicy);

      await audio.prepare();
      await audio.enterMenu();

      expect(backend.initializeCalls, 1);
      expect(backend.preloaded, GameAudioAsset.values);
      expect(backend.musicAssets, <GameAudioAsset>[
        GameAudioAsset.backgroundMusic,
      ]);
      expect(backend.musicVolumes.single, closeTo(0.55, 0.000001));

      audio.settings = AudioSettings(
        masterVolume: 0.5,
        musicVolume: 0.4,
        sfxVolume: 0.8,
      );
      await _settle();
      expect(backend.updatedMusicVolumes.last, closeTo(0.2, 0.000001));
    },
  );

  test(
    'browser smoke: user gesture defers playback and skips preload',
    () async {
      final backend = _RecordingAudioBackend();
      final audio = GameAudioController(
        backend: backend,
        policy: const AudioPlaybackPolicy(
          requiresUserGesture: true,
          supportsPreload: false,
        ),
      );

      await audio.prepare();
      await audio.enterMenu();
      await audio.startRaceLoops();

      expect(audio.isPlaybackAllowed, isFalse);
      expect(backend.preloaded, isEmpty);
      expect(backend.musicAssets, isEmpty);
      expect(backend.loops, isEmpty);

      await audio.activateFromUserGesture();

      expect(audio.isPlaybackAllowed, isTrue);
      expect(backend.musicAssets.single, GameAudioAsset.backgroundMusic);
      expect(
        backend.loops.keys,
        containsAll(<GameAudioAsset>[
          GameAudioAsset.engineLoop,
          GameAudioAsset.tireDriftLoop,
          GameAudioAsset.brakeLoop,
          GameAudioAsset.offtrackGravelLoop,
          GameAudioAsset.offtrackGrassLoop,
        ]),
      );
    },
  );

  test(
    'race smoke: loops, collisions, pause, and results fade are mixed',
    () async {
      final backend = _RecordingAudioBackend();
      final audio = GameAudioController(backend: backend, policy: nativePolicy);
      await audio.enterMenu();
      await audio.startRaceLoops();

      await audio.updateRace(
        speed: 8,
        maxSpeed: 16,
        input: PlayerInput(throttle: 0.8, brake: 0.25),
        driftAmount: 0.5,
        racing: true,
        surface: SurfaceType.parquet,
      );
      await audio.collision(0.2);
      await audio.collision(0.5);
      await audio.collision(0.9);

      expect(
        backend.loopFor(GameAudioAsset.engineLoop).volumes.last,
        closeTo(0.5408, 0.000001),
      );
      expect(
        backend.loopFor(GameAudioAsset.engineLoop).pitches.last,
        closeTo(1, 0.000001),
      );
      expect(
        backend.loopFor(GameAudioAsset.tireDriftLoop).volumes.last,
        closeTo(0.2, 0.000001),
      );
      expect(
        backend.loopFor(GameAudioAsset.brakeLoop).volumes.last,
        closeTo(0.1, 0.000001),
      );
      expect(
        backend.loopFor(GameAudioAsset.offtrackGravelLoop).volumes.last,
        closeTo(0.64, 0.000001),
      );
      expect(backend.oneShots.map((event) => event.asset), <GameAudioAsset>[
        GameAudioAsset.gravelHitOne,
        GameAudioAsset.collisionLightOne,
        GameAudioAsset.collisionMediumTwo,
        GameAudioAsset.collisionHeavyOne,
      ]);

      await audio.pauseRace();
      expect(backend.pauseMusicCalls, 1);
      for (final loop in backend.loops.values) {
        expect(loop.volumes.last, 0);
      }

      await audio.resumeRace();
      expect(backend.resumeMusicCalls, 1);
      await audio.finishRace();
      audio.advanceRaceFadeOut(0.4);
      expect(audio.isRaceFadeComplete, isFalse);
      audio.advanceRaceFadeOut(0.4);
      expect(audio.isRaceFadeComplete, isTrue);
      expect(backend.oneShots.last.asset, GameAudioAsset.finish);

      await audio.stopRaceLoops();
      expect(
        backend.loops.values.every((loop) => loop.disposeCalls == 1),
        isTrue,
      );
    },
  );

  test('retries menu music after a failed backend start', () async {
    final backend = _RecordingAudioBackend()..failNextMusicPlay = true;
    final audio = GameAudioController(backend: backend, policy: nativePolicy);

    await audio.enterMenu();
    expect(backend.musicAssets, isEmpty);

    await audio.enterMenu();
    expect(backend.musicAssets, <GameAudioAsset>[
      GameAudioAsset.backgroundMusic,
    ]);
  });

  test('lifecycle mute waits for the current race mix write', () async {
    final backend = _RecordingAudioBackend();
    final audio = GameAudioController(backend: backend, policy: nativePolicy);
    await audio.startRaceLoops();
    backend.blockLoopVolumeWrites = true;
    backend.volumeWriteGate = Completer<void>();

    final update = audio.updateRace(
      speed: 8,
      maxSpeed: 16,
      input: PlayerInput(throttle: 0.8),
      driftAmount: 0.2,
      racing: true,
      surface: SurfaceType.parquet,
    );
    await _settle();
    final pause = audio.pauseForLifecycle();
    await _settle();

    expect(backend.pauseMusicCalls, 0);
    backend.volumeWriteGate!.complete();
    await Future.wait(<Future<void>>[update, pause]);
    expect(backend.pauseMusicCalls, 1);
    expect(
      backend.loops.values.every((loop) => loop.volumes.last == 0),
      isTrue,
    );
  });

  test(
    'stopping during loop startup disposes players and allows a retry',
    () async {
      final backend = _RecordingAudioBackend();
      final audio = GameAudioController(backend: backend, policy: nativePolicy);
      backend.loopStartGate = Completer<void>();

      final starting = audio.startRaceLoops();
      await _settle();
      final stopping = audio.stopRaceLoops();
      await _settle();
      expect(backend.startLoopCalls, 5);

      backend.loopStartGate!.complete();
      await Future.wait(<Future<void>>[starting, stopping]);
      expect(
        backend.createdLoops.every((loop) => loop.disposeCalls == 1),
        isTrue,
      );

      await audio.startRaceLoops();
      expect(backend.startLoopCalls, 10);
      expect(backend.loops.length, 5);
    },
  );

  test('audio settings reject invalid normalized values', () {
    expect(() => AudioSettings(masterVolume: 1.01), throwsArgumentError);
    expect(() => AudioSettings(musicVolume: double.nan), throwsArgumentError);
  });

  testWidgets('menu action unlocks browser audio and plays a UI sound', (
    tester,
  ) async {
    final backend = _RecordingAudioBackend();
    final audio = GameAudioController(
      backend: backend,
      policy: const AudioPlaybackPolicy(
        requiresUserGesture: true,
        supportsPreload: false,
      ),
    );
    await audio.enterMenu();

    await tester.pumpWidget(
      GameAudioScope(
        audio: audio,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: GameActionTarget(
            key: const ValueKey<String>('audio-menu-action'),
            semanticLabel: 'Play',
            onPressed: () {},
            child: const ColoredBox(
              color: Color(0xff000000),
              child: SizedBox(width: 80, height: 40),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>('audio-menu-action')));
    await tester.pump();

    expect(backend.musicAssets.single, GameAudioAsset.backgroundMusic);
    expect(backend.oneShots.single.asset, GameAudioAsset.buttonClick);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('settings applies master volume for the active app session', (
    tester,
  ) async {
    final audio = GameAudioController(
      backend: _RecordingAudioBackend(),
      policy: nativePolicy,
    );
    await tester.pumpWidget(ToyRacersApplication(audio: audio));

    await tester.tap(find.byKey(const ValueKey<String>('main-menu-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('MASTER-volume-down')));
    await tester.pump();

    expect(audio.settings.masterVolume, closeTo(0.9, 0.000001));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('application mutes shared audio outside a race', (tester) async {
    final backend = _RecordingAudioBackend();
    final audio = GameAudioController(backend: backend, policy: nativePolicy);
    await audio.enterMenu();

    await tester.pumpWidget(ToyRacersApplication(audio: audio));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(backend.pauseMusicCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(backend.resumeMusicCalls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

final class _RecordingAudioBackend implements GameAudioBackend {
  int initializeCalls = 0;
  bool failNextMusicPlay = false;
  Completer<void>? loopStartGate;
  bool blockLoopVolumeWrites = false;
  Completer<void>? volumeWriteGate;
  int startLoopCalls = 0;
  final List<GameAudioAsset> preloaded = <GameAudioAsset>[];
  final List<GameAudioAsset> musicAssets = <GameAudioAsset>[];
  final List<double> musicVolumes = <double>[];
  final List<double> updatedMusicVolumes = <double>[];
  int pauseMusicCalls = 0;
  int resumeMusicCalls = 0;
  final List<_OneShot> oneShots = <_OneShot>[];
  final Map<GameAudioAsset, _RecordingAudioLoop> loops =
      <GameAudioAsset, _RecordingAudioLoop>{};
  final List<_RecordingAudioLoop> createdLoops = <_RecordingAudioLoop>[];

  _RecordingAudioLoop loopFor(GameAudioAsset asset) => loops[asset]!;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> initialize() async {
    initializeCalls++;
  }

  @override
  Future<void> pauseMusic() async {
    pauseMusicCalls++;
  }

  @override
  Future<void> playMusic(GameAudioAsset asset, {required double volume}) async {
    if (failNextMusicPlay) {
      failNextMusicPlay = false;
      throw StateError('simulated playback failure');
    }
    musicAssets.add(asset);
    musicVolumes.add(volume);
  }

  @override
  Future<void> playOneShot(
    GameAudioAsset asset, {
    required double volume,
  }) async {
    oneShots.add((asset: asset, volume: volume));
  }

  @override
  Future<void> preload(Iterable<GameAudioAsset> assets) async {
    preloaded.addAll(assets);
  }

  @override
  Future<void> resumeMusic() async {
    resumeMusicCalls++;
  }

  @override
  Future<void> setMusicVolume(double volume) async {
    updatedMusicVolumes.add(volume);
  }

  @override
  Future<GameAudioLoop> startLoop(
    GameAudioAsset asset, {
    required double volume,
    required double pitch,
  }) async {
    startLoopCalls++;
    await loopStartGate?.future;
    final loop = _RecordingAudioLoop(
      waitForVolume: () =>
          blockLoopVolumeWrites ? volumeWriteGate?.future : null,
    );
    createdLoops.add(loop);
    loops[asset] = loop;
    await loop.setVolume(volume);
    await loop.setPitch(pitch);
    return loop;
  }

  @override
  Future<void> stopMusic() async {}
}

typedef _OneShot = ({GameAudioAsset asset, double volume});

final class _RecordingAudioLoop implements GameAudioLoop {
  _RecordingAudioLoop({this.waitForVolume});

  final Future<void>? Function()? waitForVolume;
  final List<double> volumes = <double>[];
  final List<double> pitches = <double>[];
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Future<void> setPitch(double pitch) async {
    pitches.add(pitch);
  }

  @override
  Future<void> setVolume(double volume) async {
    await waitForVolume?.call();
    volumes.add(volume);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}
