package com.example.toyracers.assets

/** Central list of runtime asset paths. */
object AssetPaths {
    const val GAME_ATLAS = "game.atlas"
    const val TRACK_01 = "tracks/track_01.png"
    const val TRACK_02 = "tracks/track_02.png"
    const val ENGINE_LOOP = "audio/engine/engine_mid_loop.wav"
    const val ENGINE_ACCELERATION = "audio/engine/engine_acceleration.wav"
    const val TIRE_DRIFT_LOOP = "audio/tires/tire_drift_loop.wav"
    const val BRAKE_LOOP = "audio/tires/brake_hard.wav"
    val COLLISION_LIGHT = listOf(
        "audio/collision/collision_light_01.wav",
        "audio/collision/collision_light_02.wav",
    )
    val COLLISION_MEDIUM = listOf(
        "audio/collision/collision_medium_01.wav",
        "audio/collision/collision_medium_02.wav",
        "audio/collision/collision_medium_03.wav",
    )
    val COLLISION_HEAVY = listOf(
        "audio/collision/collision_heavy_01.wav",
        "audio/collision/collision_heavy_02.wav",
    )
    const val OFFTRACK_GRAVEL_LOOP = "audio/surface/offtrack_gravel_loop.wav"
    const val OFFTRACK_GRASS_LOOP = "audio/surface/offtrack_grass_loop.wav"
    val GRAVEL_HITS = listOf(
        "audio/surface/gravel_hit_01.wav",
        "audio/surface/gravel_hit_02.wav",
        "audio/surface/gravel_hit_03.wav",
    )
    const val START_COUNTDOWN = "audio/ui/start_countdown_3.wav"
    const val GO = "audio/go.wav"
    const val CHECKPOINT = "audio/checkpoint.wav"
    const val FINISH = "audio/finish.wav"
    const val BUTTON_CLICK = "audio/button-click.wav"
    const val BACKGROUND_MUSIC = "audio/background-music.wav"
}
