import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:toy_racers/simulation.dart';

import 'audio_assets.dart';
import 'audio_backend.dart';
import 'audio_settings.dart';
import 'flame_audio_backend.dart';
import 'race_audio_mix.dart';

/// Browser and device constraints applied before asking a backend to play.
final class AudioPlaybackPolicy {
  const AudioPlaybackPolicy({
    required this.requiresUserGesture,
    required this.supportsPreload,
  });

  factory AudioPlaybackPolicy.current() => AudioPlaybackPolicy(
    requiresUserGesture: kIsWeb,
    supportsPreload: !kIsWeb,
  );

  final bool requiresUserGesture;
  final bool supportsPreload;
}

/// Presentation-only owner of menu music, race loops, and one-shot effects.
///
/// Audio observes simulation state supplied by the Flame adapter. It must not
/// mutate a [RaceSession] or contribute to compatibility traces.
final class GameAudioController {
  factory GameAudioController({
    required GameAudioBackend backend,
    AudioPlaybackPolicy? policy,
    AudioSettings? settings,
  }) => GameAudioController._(
    backend: backend,
    policy: policy,
    settings: settings,
  );

  GameAudioController._({
    required this._backend,
    AudioPlaybackPolicy? policy,
    AudioSettings? settings,
  }) : _policy = policy ?? AudioPlaybackPolicy.current(),
       _settings = settings ?? AudioSettings(),
       _playbackAllowed =
           !(policy ?? AudioPlaybackPolicy.current()).requiresUserGesture;

  factory GameAudioController.production() =>
      GameAudioController(backend: FlameAudioBackend());

  factory GameAudioController.silent() => GameAudioController(
    backend: _SilentAudioBackend(),
    policy: const AudioPlaybackPolicy(
      requiresUserGesture: false,
      supportsPreload: false,
    ),
  );

  final GameAudioBackend _backend;
  final AudioPlaybackPolicy _policy;
  final _LoopVoice _engine = _LoopVoice(GameAudioAsset.engineLoop);
  final _LoopVoice _drift = _LoopVoice(GameAudioAsset.tireDriftLoop);
  final _LoopVoice _braking = _LoopVoice(GameAudioAsset.brakeLoop);
  final _LoopVoice _offtrackGravel = _LoopVoice(
    GameAudioAsset.offtrackGravelLoop,
  );
  final _LoopVoice _offtrackGrass = _LoopVoice(
    GameAudioAsset.offtrackGrassLoop,
  );

  AudioSettings _settings;
  bool _playbackAllowed;
  bool _menuMusicRequested = false;
  bool _raceLoopsRequested = false;
  bool _musicStarted = false;
  bool _musicPaused = false;
  bool _racePaused = false;
  bool _wasOffRoad = false;
  bool _raceFadeActive = false;
  double _raceMixGain = 1;
  int _collisionVariant = 0;
  int _gravelVariant = 0;
  bool _disposed = false;

  AudioSettings get settings => _settings;
  bool get isRaceFadeComplete => !_raceFadeActive || _raceMixGain <= 0;
  bool get isPlaybackAllowed => _playbackAllowed;

  set settings(AudioSettings value) {
    _settings = value;
    if (_musicStarted && !_disposed) {
      _ignoreFailure(() => _backend.setMusicVolume(value.effectiveMusicVolume));
    }
  }

  /// Initializes lifecycle-aware background music and preloads native assets.
  ///
  /// Browser playback is deliberately not preloaded: audioplayers cannot cache
  /// these assets there, and attempting playback before a gesture is rejected.
  Future<void> prepare() async {
    if (_disposed) {
      return;
    }
    await _ignoreFailure(_backend.initialize);
    if (_policy.supportsPreload) {
      await _ignoreFailure(() => _backend.preload(GameAudioAsset.values));
    }
  }

  /// Records a browser-permitted UI gesture and starts deferred menu music.
  Future<void> activateFromUserGesture() {
    _playbackAllowed = true;
    return Future.wait(<Future<void>>[
      _startRequestedMenuMusic(),
      _startRequestedRaceLoops(),
    ]);
  }

  /// Starts the shared background loop used by the menu, race, and results.
  Future<void> enterMenu() {
    _menuMusicRequested = true;
    return _startRequestedMenuMusic();
  }

  /// Starts muted long-lived loops before countdown, matching the reference.
  Future<void> startRaceLoops() {
    _raceLoopsRequested = true;
    return _startRequestedRaceLoops();
  }

  Future<void> _startRequestedRaceLoops() async {
    if (!_canPlay || !_raceLoopsRequested) {
      return;
    }
    await Future.wait(
      _raceLoops.map((loop) => _ignoreFailure(() => loop.start(_backend))),
    );
  }

  /// Updates race-loop targets from the current physical player state.
  Future<void> updateRace({
    required double speed,
    required double maxSpeed,
    required PlayerInput input,
    required double driftAmount,
    required bool racing,
    required SurfaceType surface,
  }) async {
    final offRoad = !surface.isRoad;
    if (!_canPlay) {
      _wasOffRoad = offRoad;
      return;
    }
    final mix = calculateRaceAudioMix(
      speed: speed,
      maxSpeed: maxSpeed,
      throttle: input.throttle,
      brake: input.brake,
      driftAmount: driftAmount,
      racing: racing,
      offRoad: offRoad,
      grass: surface == SurfaceType.grass,
      paused: _racePaused,
      sfxVolume: _settings.effectiveSfxVolume * _raceMixGain,
    );
    await Future.wait(<Future<void>>[
      _ignoreFailure(() => _engine.setVolume(mix.engineVolume)),
      _ignoreFailure(() => _engine.setPitch(mix.enginePitch)),
      _ignoreFailure(() => _drift.setVolume(mix.driftVolume)),
      _ignoreFailure(() => _drift.setPitch(mix.driftPitch)),
      _ignoreFailure(() => _braking.setVolume(mix.brakingVolume)),
      _ignoreFailure(() => _offtrackGravel.setVolume(mix.gravelVolume)),
      _ignoreFailure(() => _offtrackGrass.setVolume(mix.grassVolume)),
    ]);
    if (racing && offRoad && !_wasOffRoad && surface != SurfaceType.grass) {
      await _playNext(gravelHitAssets, 0.65, _gravelVariant++);
    }
    _wasOffRoad = offRoad;
  }

  Future<void> countdown() => _play(GameAudioAsset.startCountdown, 0.75);
  Future<void> go() => _play(GameAudioAsset.go, 1);
  Future<void> checkpoint() => _play(GameAudioAsset.checkpoint, 0.75);
  Future<void> buttonClick() => _play(GameAudioAsset.buttonClick, 0.7);

  Future<void> collision(double impactRatio) {
    final assets = switch (impactRatio) {
      < 0.35 => collisionLightAssets,
      < 0.7 => collisionMediumAssets,
      _ => collisionHeavyAssets,
    };
    return _playNext(
      assets,
      impactRatio.clamp(0.3, 1).toDouble(),
      _collisionVariant++,
    );
  }

  /// Plays the finish cue and begins the reference 0.8-second loop fade.
  Future<void> finishRace() {
    _raceFadeActive = true;
    return _play(GameAudioAsset.finish, 1);
  }

  void advanceRaceFadeOut(double deltaSeconds) {
    if (!_raceFadeActive || !deltaSeconds.isFinite || deltaSeconds <= 0) {
      return;
    }
    _raceMixGain = (_raceMixGain - deltaSeconds / _raceFadeSeconds)
        .clamp(0, 1)
        .toDouble();
  }

  Future<void> pauseRace() {
    _racePaused = true;
    return Future.wait(<Future<void>>[
      _ignoreFailure(() => _setRaceLoopsVolume(0)),
      _ignoreFailure(_backend.pauseMusic),
    ]);
  }

  Future<void> resumeRace() {
    _racePaused = false;
    _musicPaused = false;
    if (!_canPlay) {
      return Future.value();
    }
    if (_musicStarted) {
      return _ignoreFailure(_backend.resumeMusic);
    }
    return _startRequestedMenuMusic();
  }

  /// Mutes all runtime audio while Flame pauses its engine for app lifecycle.
  Future<void> pauseForLifecycle() {
    _musicPaused = true;
    return Future.wait(<Future<void>>[
      _ignoreFailure(() => _setRaceLoopsVolume(0)),
      _ignoreFailure(_backend.pauseMusic),
    ]);
  }

  /// Restores background music after a lifecycle pause when race is not paused.
  Future<void> resumeForLifecycle() {
    if (_racePaused || !_musicStarted || !_canPlay) {
      return Future.value();
    }
    _musicPaused = false;
    return _ignoreFailure(_backend.resumeMusic);
  }

  /// Resets a retry to the initial mix without creating duplicate loop players.
  Future<void> resetRaceMix() {
    _raceMixGain = 1;
    _raceFadeActive = false;
    return Future.value();
  }

  Future<void> stopRaceLoops() async {
    await Future.wait(_raceLoops.map((loop) => _ignoreFailure(loop.stop)));
    _raceLoopsRequested = false;
    _wasOffRoad = false;
    _racePaused = false;
    _raceMixGain = 1;
    _raceFadeActive = false;
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await stopRaceLoops();
    await _ignoreFailure(_backend.stopMusic);
    await _ignoreFailure(_backend.dispose);
  }

  bool get _canPlay => _playbackAllowed && !_disposed;

  Iterable<_LoopVoice> get _raceLoops => <_LoopVoice>[
    _engine,
    _braking,
    _drift,
    _offtrackGravel,
    _offtrackGrass,
  ];

  Future<void> _startRequestedMenuMusic() {
    if (!_canPlay || !_menuMusicRequested) {
      return Future.value();
    }
    if (_musicStarted && !_musicPaused) {
      return Future.value();
    }
    _musicStarted = true;
    _musicPaused = false;
    return _ignoreFailure(
      () => _backend.playMusic(
        GameAudioAsset.backgroundMusic,
        volume: _settings.effectiveMusicVolume,
      ),
    );
  }

  Future<void> _setRaceLoopsVolume(double volume) =>
      Future.wait(_raceLoops.map((loop) => loop.setVolume(volume)));

  Future<void> _play(GameAudioAsset asset, double volume) {
    if (!_canPlay || _racePaused) {
      return Future.value();
    }
    return _ignoreFailure(
      () => _backend.playOneShot(
        asset,
        volume: volume * _settings.effectiveSfxVolume,
      ),
    );
  }

  Future<void> _playNext(
    List<GameAudioAsset> assets,
    double volume,
    int index,
  ) => _play(assets[index % assets.length], volume);

  Future<void> _ignoreFailure(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      // Audio output is optional on CI, headless devices, and blocked browsers.
    }
  }

  static const double _raceFadeSeconds = 0.8;
}

final class _LoopVoice {
  _LoopVoice(this.asset);

  final GameAudioAsset asset;
  GameAudioLoop? _loop;
  Future<void>? _starting;
  double _volume = 0;
  double _pitch = 1;
  bool _stopped = false;

  Future<void> start(GameAudioBackend backend) {
    final starting = _starting;
    if (_loop != null || starting != null) {
      return starting ?? Future.value();
    }
    _stopped = false;
    final future = _start(backend);
    _starting = future;
    return future.whenComplete(() => _starting = null);
  }

  Future<void> setVolume(double volume) async {
    _volume = volume;
    final loop = _loop;
    if (loop != null) {
      await loop.setVolume(volume);
    }
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch;
    final loop = _loop;
    if (loop != null) {
      await loop.setPitch(pitch);
    }
  }

  Future<void> stop() async {
    _stopped = true;
    final loop = _loop;
    _loop = null;
    if (loop != null) {
      await loop.stop();
    }
  }

  Future<void> _start(GameAudioBackend backend) async {
    final loop = await backend.startLoop(asset, volume: 0, pitch: _pitch);
    if (_stopped) {
      await loop.stop();
      return;
    }
    _loop = loop;
    await Future.wait(<Future<void>>[
      loop.setVolume(_volume),
      loop.setPitch(_pitch),
    ]);
  }
}

final class _SilentAudioBackend implements GameAudioBackend {
  @override
  Future<void> dispose() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> pauseMusic() async {}

  @override
  Future<void> playMusic(
    GameAudioAsset asset, {
    required double volume,
  }) async {}

  @override
  Future<void> playOneShot(
    GameAudioAsset asset, {
    required double volume,
  }) async {}

  @override
  Future<void> preload(Iterable<GameAudioAsset> assets) async {}

  @override
  Future<void> resumeMusic() async {}

  @override
  Future<void> setMusicVolume(double volume) async {}

  @override
  Future<GameAudioLoop> startLoop(
    GameAudioAsset asset, {
    required double volume,
    required double pitch,
  }) async => _SilentAudioLoop();

  @override
  Future<void> stopMusic() async {}
}

final class _SilentAudioLoop implements GameAudioLoop {
  @override
  Future<void> setPitch(double pitch) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> stop() async {}
}
