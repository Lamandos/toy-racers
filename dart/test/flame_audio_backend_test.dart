import 'package:flame_audio/flame_audio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toy_racers/audio/audio_assets.dart';
import 'package:toy_racers/audio/flame_audio_backend.dart';

void main() {
  test('disables position polling before starting each game voice', () async {
    final players = <_Player>[];
    final backend = FlameAudioBackend(
      playerFactory: () {
        final player = _Player();
        players.add(player);
        return player;
      },
    );
    await backend.playOneShot(GameAudioAsset.buttonClick, volume: 0.5);
    final loop = await backend.startLoop(
      GameAudioAsset.engineLoop,
      volume: 0.2,
      pitch: 0.96,
    );
    for (final player in players) {
      expect(player.events.take(2), ['disable-position-polling', 'play']);
      expect(player.recordedMode, PlayerMode.lowLatency);
    }
    expect(players.first.recordedRelease, ReleaseMode.release);
    expect(players.last.recordedRelease, ReleaseMode.loop);
    await loop.setVolume(0.8);
    await loop.setPitch(1.02);
    expect(players.last.recordedVolume, 0.8);
    expect(players.last.pitch, 1.02);
    await loop.stop();
    await loop.dispose();
    expect(players.last.events.last, 'dispose');
  });

  test('disposes a player if its startup fails', () async {
    final player = _Player()..failPlay = true;
    final backend = FlameAudioBackend(playerFactory: () => player);
    await expectLater(
      backend.playOneShot(GameAudioAsset.buttonClick, volume: 1),
      throwsStateError,
    );
    expect(player.events.last, 'dispose');
  });
}

final class _Player extends Fake implements AudioPlayer {
  final events = <String>[];
  bool failPlay = false;
  ReleaseMode? recordedRelease;
  PlayerMode? recordedMode;
  double? recordedVolume;
  double? pitch;

  @override
  set audioCache(AudioCache value) {}
  @override
  set positionUpdater(PositionUpdater? value) {
    expect(value, isNull);
    events.add('disable-position-polling');
  }

  @override
  Future<void> setAudioContext(AudioContext context) async {}
  @override
  Future<void> setReleaseMode(ReleaseMode value) async {
    recordedRelease = value;
  }

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    events.add('play');
    if (failPlay) throw StateError('startup failed');
    recordedVolume = volume;
    recordedMode = mode;
  }

  @override
  Future<void> setPlaybackRate(double value) async {
    pitch = value;
  }

  @override
  Future<void> setVolume(double value) async {
    recordedVolume = value;
  }

  @override
  Future<void> stop() async {
    events.add('stop');
  }

  @override
  Future<void> dispose() async {
    events.add('dispose');
  }
}
