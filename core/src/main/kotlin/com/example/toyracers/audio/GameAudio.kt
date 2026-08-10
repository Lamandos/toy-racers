package com.example.toyracers.audio

import com.badlogic.gdx.audio.Music
import com.badlogic.gdx.audio.Sound
import com.badlogic.gdx.utils.Disposable
import com.example.toyracers.assets.GameAssets
import com.example.toyracers.track.SurfaceType
import kotlin.math.abs

internal data class RaceAudioMix(
    val engineVolume: Float,
    val driftVolume: Float,
    val driftPitch: Float,
    val wheelspinVolume: Float,
    val brakingVolume: Float,
)

internal fun calculateRaceAudioMix(
    speed: Float,
    maxSpeed: Float,
    throttle: Float,
    brake: Float,
    driftAmount: Float,
    racing: Boolean,
    offRoad: Boolean,
    paused: Boolean,
    sfxVolume: Float,
): RaceAudioMix {
    val speedRatio = (abs(speed) / maxSpeed).coerceIn(0f, 1f)
    val activeRaceVolume = if (paused || !racing) 0f else sfxVolume
    return RaceAudioMix(
        engineVolume = if (paused) {
            0f
        } else {
            (IDLE_VOLUME + throttle.coerceIn(0f, 1f) * THROTTLE_VOLUME) * sfxVolume
        },
        driftVolume = driftAmount.coerceIn(0f, 1f) * speedRatio * activeRaceVolume,
        driftPitch = 0.9f + speedRatio * 0.25f,
        wheelspinVolume = if (offRoad) {
            throttle.coerceIn(0f, 1f) * activeRaceVolume
        } else {
            0f
        },
        brakingVolume =
            brake.coerceIn(0f, 1f) *
                (speed.coerceAtLeast(0f) / maxSpeed).coerceIn(0f, 1f) *
                activeRaceVolume,
    )
}

/** Owns music, one-shot effects, and long-lived race loop instances. */
class GameAudio(
    assets: GameAssets,
    settings: AudioSettings = AudioSettings(),
) : Disposable {
    private val engine = LoopingSound(assets.engineLoop)
    private val drift = LoopingSound(assets.tireDriftLoop)
    private val braking = LoopingSound(assets.brakeLoop)
    private val collisionLight = assets.collisionLight
    private val collisionMedium = assets.collisionMedium
    private val collisionHeavy = assets.collisionHeavy
    private val offtrackGravel = LoopingSound(assets.offtrackGravelLoop)
    private val offtrackGrass = LoopingSound(assets.offtrackGrassLoop)
    private val gravelHits = assets.gravelHits
    private val countdown = assets.startCountdown
    private val go = assets.go
    private val checkpoint = assets.checkpoint
    private val finish = assets.finish
    private val buttonClick = assets.buttonClick
    private val music: Music = assets.backgroundMusic
    private val raceLoops = listOf(engine, braking, drift, offtrackGravel, offtrackGrass)
    private var wasOffRoad = false
    private var collisionVariant = 0
    private var gravelVariant = 0
    private var paused = false
    private var raceMixGain = 1f
    private var raceFadeActive = false

    var settings: AudioSettings = settings
        set(value) {
            field = value
            music.volume = value.effectiveMusicVolume
        }

    val isRaceFadeComplete: Boolean
        get() = !raceFadeActive || raceMixGain <= 0f

    fun startMusic() {
        music.isLooping = true
        music.volume = settings.effectiveMusicVolume
        if (!music.isPlaying) music.play()
    }

    fun startRaceLoops() {
        raceLoops.forEach(LoopingSound::startMuted)
    }

    fun updateRace(
        speed: Float,
        maxSpeed: Float,
        throttle: Float,
        brake: Float,
        driftAmount: Float,
        racing: Boolean,
        surface: SurfaceType,
    ) {
        val offRoad = !surface.isRoad
        val mix = calculateRaceAudioMix(
            speed = speed,
            maxSpeed = maxSpeed,
            throttle = throttle,
            brake = brake,
            driftAmount = driftAmount,
            racing = racing,
            offRoad = offRoad,
            paused = paused,
            sfxVolume = settings.effectiveSfxVolume * raceMixGain,
        )
        val speedRatio = (abs(speed) / maxSpeed).coerceIn(0f, 1f)
        engine.setVolume(mix.engineVolume)
        engine.setPitch(0.96f + speedRatio * 0.08f)
        drift.setVolume(mix.driftVolume)
        drift.setPitch(mix.driftPitch)
        braking.setVolume(mix.brakingVolume)

        val gravelVolume =
            if (offRoad && surface != SurfaceType.GRASS) mix.wheelspinVolume else 0f
        val grassVolume = if (surface == SurfaceType.GRASS) mix.wheelspinVolume else 0f
        offtrackGravel.setVolume(gravelVolume)
        offtrackGrass.setVolume(grassVolume)

        if (racing && offRoad && !wasOffRoad && surface != SurfaceType.GRASS) {
            playNext(gravelHits, 0.65f, gravelVariant++)
        }
        wasOffRoad = offRoad
    }

    fun countdown() = play(countdown, 0.75f)
    fun go() = play(go, 1f)
    fun checkpoint() = play(checkpoint, 0.75f)
    fun finish() = play(finish, 1f)
    fun collision(impactRatio: Float) {
        val variants = when {
            impactRatio < 0.35f -> collisionLight
            impactRatio < 0.7f -> collisionMedium
            else -> collisionHeavy
        }
        playNext(variants, impactRatio.coerceIn(0.3f, 1f), collisionVariant++)
    }
    fun buttonClick() = play(buttonClick, 0.7f)

    fun beginRaceFadeOut() {
        raceFadeActive = true
    }

    fun advanceRaceFadeOut(deltaSeconds: Float) {
        if (raceFadeActive) {
            raceMixGain = (raceMixGain - deltaSeconds / RACE_FADE_SECONDS).coerceAtLeast(0f)
        }
    }

    fun resetRaceMix() {
        raceMixGain = 1f
        raceFadeActive = false
    }

    fun pauseRace() {
        paused = true
        raceLoops.forEach(LoopingSound::mute)
        music.pause()
    }

    fun resumeRace() {
        paused = false
        startMusic()
    }

    fun stopRaceLoops() {
        raceLoops.forEach(LoopingSound::stop)
        wasOffRoad = false
        resetRaceMix()
    }

    override fun dispose() {
        stopRaceLoops()
        music.stop()
    }

    private fun play(sound: Sound, volume: Float) {
        if (!paused) sound.play(volume * settings.effectiveSfxVolume)
    }

    private fun playNext(sounds: List<Sound>, volume: Float, index: Int) {
        play(sounds[index % sounds.size], volume)
    }

    private companion object {
        const val RACE_FADE_SECONDS = 0.8f
    }

    private class LoopingSound(
        private val sound: Sound,
    ) {
        private var id: Long? = null

        fun startMuted() {
            if (id == null) id = sound.loop(0f)
        }

        fun mute() = setVolume(0f)

        fun setVolume(volume: Float) {
            id?.let { sound.setVolume(it, volume) }
        }

        fun setPitch(pitch: Float) {
            id?.let { sound.setPitch(it, pitch) }
        }

        fun stop() {
            id?.let(sound::stop)
            id = null
        }
    }
}

private const val IDLE_VOLUME = 0.18f
private const val THROTTLE_VOLUME = 0.62f
