/// Canonical Flame Audio paths, relative to the `assets/audio` prefix.
///
/// Keeping these names in the presentation layer prevents audio resources from
/// becoming an input to the portable simulation contract.
enum GameAudioAsset {
  backgroundMusic('background-music.wav'),
  buttonClick('button-click.wav'),
  checkpoint('checkpoint.wav'),
  finish('finish.wav'),
  go('go.wav'),
  engineLoop('engine/engine_mid_loop.wav'),
  tireDriftLoop('tires/tire_drift_loop.wav'),
  brakeLoop('tires/brake_hard.wav'),
  collisionLightOne('collision/collision_light_01.wav'),
  collisionLightTwo('collision/collision_light_02.wav'),
  collisionMediumOne('collision/collision_medium_01.wav'),
  collisionMediumTwo('collision/collision_medium_02.wav'),
  collisionMediumThree('collision/collision_medium_03.wav'),
  collisionHeavyOne('collision/collision_heavy_01.wav'),
  collisionHeavyTwo('collision/collision_heavy_02.wav'),
  offtrackGravelLoop('surface/offtrack_gravel_loop.wav'),
  offtrackGrassLoop('surface/offtrack_grass_loop.wav'),
  gravelHitOne('surface/gravel_hit_01.wav'),
  gravelHitTwo('surface/gravel_hit_02.wav'),
  gravelHitThree('surface/gravel_hit_03.wav'),
  startCountdown('ui/start_countdown_3.wav');

  const GameAudioAsset(this.path);

  final String path;
}

const List<GameAudioAsset> collisionLightAssets = <GameAudioAsset>[
  GameAudioAsset.collisionLightOne,
  GameAudioAsset.collisionLightTwo,
];

const List<GameAudioAsset> collisionMediumAssets = <GameAudioAsset>[
  GameAudioAsset.collisionMediumOne,
  GameAudioAsset.collisionMediumTwo,
  GameAudioAsset.collisionMediumThree,
];

const List<GameAudioAsset> collisionHeavyAssets = <GameAudioAsset>[
  GameAudioAsset.collisionHeavyOne,
  GameAudioAsset.collisionHeavyTwo,
];

const List<GameAudioAsset> gravelHitAssets = <GameAudioAsset>[
  GameAudioAsset.gravelHitOne,
  GameAudioAsset.gravelHitTwo,
  GameAudioAsset.gravelHitThree,
];
