package com.example.toyracers.assets

import com.badlogic.gdx.assets.AssetManager
import com.badlogic.gdx.audio.Music
import com.badlogic.gdx.audio.Sound
import com.badlogic.gdx.graphics.Texture
import com.badlogic.gdx.graphics.g2d.TextureRegion
import com.badlogic.gdx.utils.Disposable
import com.example.toyracers.car.CarModel
import com.example.toyracers.track.TrackId

/** Owns application-wide assets and their loading lifecycle. */
class GameAssets(
    private val manager: AssetManager = AssetManager(),
) : Disposable {
    private var queued = false
    private var prepared = false

    val progress: Float
        get() = manager.progress

    fun car(model: CarModel): TextureRegion {
        check(prepared) { "Assets must finish loading before they are accessed" }
        return TextureRegion(manager.get(model.assetPath, Texture::class.java))
    }

    fun track(trackId: TrackId): Texture {
        check(prepared) { "Assets must finish loading before they are accessed" }
        val path = when (trackId) {
            TrackId.LIVING_ROOM -> AssetPaths.TRACK_01
            TrackId.BATHROOM -> AssetPaths.TRACK_02
        }
        return manager.get(path, Texture::class.java)
    }

    val engineLoop: Sound get() = sound(AssetPaths.ENGINE_LOOP)
    val tireDriftLoop: Sound get() = sound(AssetPaths.TIRE_DRIFT_LOOP)
    val brakeLoop: Sound get() = sound(AssetPaths.BRAKE_LOOP)
    val collisionLight: List<Sound> get() = AssetPaths.COLLISION_LIGHT.map(::sound)
    val collisionMedium: List<Sound> get() = AssetPaths.COLLISION_MEDIUM.map(::sound)
    val collisionHeavy: List<Sound> get() = AssetPaths.COLLISION_HEAVY.map(::sound)
    val offtrackGravelLoop: Sound get() = sound(AssetPaths.OFFTRACK_GRAVEL_LOOP)
    val offtrackGrassLoop: Sound get() = sound(AssetPaths.OFFTRACK_GRASS_LOOP)
    val gravelHits: List<Sound> get() = AssetPaths.GRAVEL_HITS.map(::sound)
    val startCountdown: Sound get() = sound(AssetPaths.START_COUNTDOWN)
    val go: Sound get() = sound(AssetPaths.GO)
    val checkpoint: Sound get() = sound(AssetPaths.CHECKPOINT)
    val finish: Sound get() = sound(AssetPaths.FINISH)
    val buttonClick: Sound get() = sound(AssetPaths.BUTTON_CLICK)
    val backgroundMusic: Music
        get() {
            check(prepared) { "Assets must finish loading before they are accessed" }
            return manager.get(AssetPaths.BACKGROUND_MUSIC, Music::class.java)
        }

    fun queueLoading() {
        if (queued) return
        manager.load(AssetPaths.TRACK_01, Texture::class.java)
        manager.load(AssetPaths.TRACK_02, Texture::class.java)
        CarModel.entries.forEach { manager.load(it.assetPath, Texture::class.java) }
        (
            listOf(
                AssetPaths.ENGINE_LOOP,
                AssetPaths.TIRE_DRIFT_LOOP,
                AssetPaths.BRAKE_LOOP,
            ) +
                AssetPaths.COLLISION_LIGHT +
                AssetPaths.COLLISION_MEDIUM +
                AssetPaths.COLLISION_HEAVY +
                AssetPaths.OFFTRACK_GRAVEL_LOOP +
                AssetPaths.OFFTRACK_GRASS_LOOP +
                AssetPaths.GRAVEL_HITS +
                AssetPaths.START_COUNTDOWN +
                listOf(
                    AssetPaths.GO,
                    AssetPaths.CHECKPOINT,
                    AssetPaths.FINISH,
                    AssetPaths.BUTTON_CLICK,
                )
            ).forEach { manager.load(it, Sound::class.java) }
        manager.load(AssetPaths.BACKGROUND_MUSIC, Music::class.java)
        queued = true
    }

    fun update(): Boolean {
        check(queued) { "queueLoading must be called before update" }
        val finished = manager.update()
        if (finished && !prepared) {
            prepared = true
        }
        return finished
    }

    override fun dispose() {
        manager.dispose()
    }

    private fun sound(path: String): Sound {
        check(prepared) { "Assets must finish loading before they are accessed" }
        return manager.get(path, Sound::class.java)
    }
}
