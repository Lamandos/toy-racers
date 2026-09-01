/// User-controlled normalized levels for presentation audio.
///
/// Settings intentionally live outside the deterministic simulation: changing
/// a device volume must not affect a compatibility trace.
final class AudioSettings {
  AudioSettings({
    double masterVolume = 1,
    double musicVolume = 0.55,
    double sfxVolume = 0.8,
  }) : masterVolume = _normalized(masterVolume, 'masterVolume'),
       musicVolume = _normalized(musicVolume, 'musicVolume'),
       sfxVolume = _normalized(sfxVolume, 'sfxVolume');

  final double masterVolume;
  final double musicVolume;
  final double sfxVolume;

  double get effectiveMusicVolume => masterVolume * musicVolume;
  double get effectiveSfxVolume => masterVolume * sfxVolume;

  AudioSettings copyWith({
    double? masterVolume,
    double? musicVolume,
    double? sfxVolume,
  }) => AudioSettings(
    masterVolume: masterVolume ?? this.masterVolume,
    musicVolume: musicVolume ?? this.musicVolume,
    sfxVolume: sfxVolume ?? this.sfxVolume,
  );

  static double _normalized(double value, String name) {
    if (!value.isFinite || value < 0 || value > 1) {
      throw ArgumentError.value(
        value,
        name,
        'must be a finite value from 0 to 1',
      );
    }
    return value;
  }
}
