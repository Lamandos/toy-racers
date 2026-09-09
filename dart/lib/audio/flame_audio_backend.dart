import 'package:flame_audio/flame_audio.dart';

import 'audio_assets.dart';
import 'audio_backend.dart';

/// Flame Audio implementation used by the Flutter and Flame presentation.
final class FlameAudioBackend implements GameAudioBackend {
  FlameAudioBackend({AudioPlayer Function()? playerFactory})
    : _playerFactory = playerFactory ?? AudioPlayer.new;

  final AudioPlayer Function() _playerFactory;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    await FlameAudio.bgm.initialize();
    // The game never consumes playback-position streams. The default updater
    // otherwise polls the platform once per rendered frame for every voice.
    FlameAudio.bgm.audioPlayer.positionUpdater = null;
    _initialized = true;
  }

  @override
  Future<void> preload(Iterable<GameAudioAsset> assets) =>
      FlameAudio.audioCache.loadAll(assets.map((asset) => asset.path).toList());

  @override
  Future<void> playOneShot(
    GameAudioAsset asset, {
    required double volume,
  }) async {
    await _playAsset(asset, volume, ReleaseMode.release);
  }

  @override
  Future<GameAudioLoop> startLoop(
    GameAudioAsset asset, {
    required double volume,
    required double pitch,
  }) async {
    final player = await _playAsset(asset, volume, ReleaseMode.loop);
    await player.setPlaybackRate(pitch);
    return _FlameAudioLoop(player);
  }

  Future<AudioPlayer> _playAsset(
    GameAudioAsset asset,
    double volume,
    ReleaseMode releaseMode,
  ) async {
    final player = _playerFactory()
      ..audioCache = FlameAudio.audioCache
      // Disable before play: replacing an already running updater races its
      // in-flight position query against disposal of its event stream.
      ..positionUpdater = null;
    try {
      await player.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
            .build(),
      );
      await player.setReleaseMode(releaseMode);
      await player.play(
        AssetSource(asset.path),
        volume: volume,
        mode: PlayerMode.lowLatency,
      );
      return player;
    } on Object {
      await player.dispose();
      rethrow;
    }
  }

  @override
  Future<void> playMusic(GameAudioAsset asset, {required double volume}) =>
      FlameAudio.bgm.play(asset.path, volume: volume);

  @override
  Future<void> setMusicVolume(double volume) =>
      FlameAudio.bgm.audioPlayer.setVolume(volume);

  @override
  Future<void> pauseMusic() => FlameAudio.bgm.pause();

  @override
  Future<void> resumeMusic() => FlameAudio.bgm.resume();

  @override
  Future<void> stopMusic() => FlameAudio.bgm.stop();

  @override
  Future<void> dispose() async {
    await FlameAudio.bgm.stop();
    FlameAudio.bgm.dispose();
  }
}

final class _FlameAudioLoop implements GameAudioLoop {
  _FlameAudioLoop(this._player);

  final AudioPlayer _player;

  @override
  Future<void> setPitch(double pitch) => _player.setPlaybackRate(pitch);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
