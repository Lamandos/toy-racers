import 'audio_assets.dart';

/// A running loop whose mix may change without restarting the sample.
abstract interface class GameAudioLoop {
  Future<void> setVolume(double volume);
  Future<void> setPitch(double pitch);
  Future<void> stop();
  Future<void> dispose();
}

/// Platform-specific playback boundary used by [GameAudioController].
///
/// The controller owns gameplay-adjacent timing and selection decisions. A
/// backend only starts, mixes, and disposes platform audio resources, keeping
/// audio smoke tests independent from an output device.
abstract interface class GameAudioBackend {
  Future<void> initialize();
  Future<void> preload(Iterable<GameAudioAsset> assets);
  Future<void> playOneShot(GameAudioAsset asset, {required double volume});
  Future<GameAudioLoop> startLoop(
    GameAudioAsset asset, {
    required double volume,
    required double pitch,
  });
  Future<void> playMusic(GameAudioAsset asset, {required double volume});
  Future<void> setMusicVolume(double volume);
  Future<void> pauseMusic();
  Future<void> resumeMusic();
  Future<void> stopMusic();
  Future<void> dispose();
}
