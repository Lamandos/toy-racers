package com.example.toyracers.assets

import com.badlogic.gdx.assets.AssetManager
import com.badlogic.gdx.audio.Music
import com.badlogic.gdx.audio.Sound
import com.badlogic.gdx.graphics.Texture
import com.badlogic.gdx.graphics.g2d.TextureAtlas
import com.badlogic.gdx.graphics.g2d.TextureRegion
import com.badlogic.gdx.utils.Disposable
import com.example.toyracers.track.TrackId

/** Owns application-wide assets and their loading lifecycle. */
class GameAssets(
    private val manager: AssetManager = AssetManager(),
) : Disposable {
    private var queued = false
    private var prepared = false

    val progress: Float
        get() = manager.progress

    val playerCar: TextureRegion by lazy {
        check(prepared) { "Assets must finish loading before they are accessed" }
        manager.get(AssetPaths.GAME_ATLAS, TextureAtlas::class.java).findRegion(PLAYER_CAR_REGION)
    }

    val opponentCar: TextureRegion by lazy {
        check(prepared) { "Assets must finish loading before they are accessed" }
        manager.get(AssetPaths.GAME_ATLAS, TextureAtlas::class.java).findRegion(OPPONENT_CAR_REGION)
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
    val skidLoop: Sound get() = sound(AssetPaths.SKID_LOOP)
    val collision: Sound get() = sound(AssetPaths.COLLISION)
    val countdownBeep: Sound get() = sound(AssetPaths.COUNTDOWN_BEEP)
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
        manager.load(AssetPaths.GAME_ATLAS, TextureAtlas::class.java)
        manager.load(AssetPaths.TRACK_01, Texture::class.java)
        manager.load(AssetPaths.TRACK_02, Texture::class.java)
        listOf(
            AssetPaths.ENGINE_LOOP,
            AssetPaths.SKID_LOOP,
            AssetPaths.COLLISION,
            AssetPaths.COUNTDOWN_BEEP,
            AssetPaths.GO,
            AssetPaths.CHECKPOINT,
            AssetPaths.FINISH,
            AssetPaths.BUTTON_CLICK,
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

    private companion object {
        const val PLAYER_CAR_REGION = "player-car"
        const val OPPONENT_CAR_REGION = "ai-car"
    }
}
