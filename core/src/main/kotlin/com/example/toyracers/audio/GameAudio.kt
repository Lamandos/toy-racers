package com.example.toyracers.audio

import com.badlogic.gdx.audio.Music
import com.badlogic.gdx.audio.Sound
import com.badlogic.gdx.utils.Disposable
import com.example.toyracers.assets.GameAssets
import kotlin.math.abs

/** Owns music, one-shot effects, and the long-lived engine/skid loop instances. */
class GameAudio(
    assets: GameAssets,
    settings: AudioSettings = AudioSettings(),
) : Disposable {
    private val engine = assets.engineLoop
    private val skid = assets.skidLoop
    private val collision = assets.collision
    private val countdownBeep = assets.countdownBeep
    private val go = assets.go
    private val checkpoint = assets.checkpoint
    private val finish = assets.finish
    private val buttonClick = assets.buttonClick
    private val music: Music = assets.backgroundMusic
    private var engineId = NO_LOOP
    private var skidId = NO_LOOP
    private var paused = false

    var settings: AudioSettings = settings
        set(value) {
            field = value
            music.volume = value.effectiveMusicVolume
        }

    fun startMusic() {
        music.isLooping = true
        music.volume = settings.effectiveMusicVolume
        if (!music.isPlaying) music.play()
    }

    fun startRaceLoops() {
        if (engineId == NO_LOOP) engineId = engine.loop(0f)
        if (skidId == NO_LOOP) skidId = skid.loop(0f)
    }

    fun updateRace(
        speed: Float,
        maxSpeed: Float,
        throttle: Float,
        steering: Float,
        racing: Boolean,
    ) {
        startRaceLoops()
        val sfx = settings.effectiveSfxVolume
        val speedRatio = (abs(speed) / maxSpeed).coerceIn(0f, 1f)
        val engineVolume = if (paused) 0f else {
            (IDLE_VOLUME + throttle.coerceIn(0f, 1f) * THROTTLE_VOLUME) * sfx
        }
        engine.setVolume(engineId, engineVolume)
        engine.setPitch(engineId, BASE_PITCH + speedRatio * PITCH_RANGE)

        val skidAmount = ((abs(steering) - SKID_STEERING_THRESHOLD) /
            (1f - SKID_STEERING_THRESHOLD)).coerceIn(0f, 1f) * speedRatio
        skid.setVolume(skidId, if (paused || !racing) 0f else skidAmount * sfx)
        skid.setPitch(skidId, 0.9f + speedRatio * 0.25f)
    }

    fun countdown() = play(countdownBeep, 0.75f)
    fun go() = play(go, 1f)
    fun checkpoint() = play(checkpoint, 0.75f)
    fun finish() = play(finish, 1f)
    fun collision(impactRatio: Float) = play(collision, impactRatio.coerceIn(0.2f, 1f))
    fun buttonClick() = play(buttonClick, 0.7f)

    fun pauseRace() {
        paused = true
        if (engineId != NO_LOOP) engine.setVolume(engineId, 0f)
        if (skidId != NO_LOOP) skid.setVolume(skidId, 0f)
        music.pause()
    }

    fun resumeRace() {
        paused = false
        startMusic()
    }

    fun stopRaceLoops() {
        if (engineId != NO_LOOP) engine.stop(engineId)
        if (skidId != NO_LOOP) skid.stop(skidId)
        engineId = NO_LOOP
        skidId = NO_LOOP
    }

    override fun dispose() {
        stopRaceLoops()
        music.stop()
    }

    private fun play(sound: Sound, volume: Float) {
        if (!paused) sound.play(volume * settings.effectiveSfxVolume)
    }

    private companion object {
        const val NO_LOOP = -1L
        const val BASE_PITCH = 0.7f
        const val PITCH_RANGE = 0.75f
        const val IDLE_VOLUME = 0.18f
        const val THROTTLE_VOLUME = 0.62f
        const val SKID_STEERING_THRESHOLD = 0.52f
    }
}
