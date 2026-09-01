import 'package:flame_audio/flame_audio.dart';

import 'audio_assets.dart';
import 'audio_backend.dart';

/// Flame Audio implementation used by the Flutter and Flame presentation.
final class FlameAudioBackend implements GameAudioBackend {
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    await FlameAudio.bgm.initialize();
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
    await FlameAudio.play(asset.path, volume: volume);
  }

  @override
  Future<GameAudioLoop> startLoop(
    GameAudioAsset asset, {
    required double volume,
    required double pitch,
  }) async {
    final player = await FlameAudio.loop(asset.path, volume: volume);
    await player.setPlaybackRate(pitch);
    return _FlameAudioLoop(player);
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
}
