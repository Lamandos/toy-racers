package com.example.toyracers.assets

import com.badlogic.gdx.assets.AssetManager
import com.badlogic.gdx.graphics.Texture
import com.badlogic.gdx.graphics.g2d.TextureRegion
import com.badlogic.gdx.utils.Disposable

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
        TextureRegion(manager.get(AssetPaths.PLAYER_CAR, Texture::class.java))
    }

    fun queueLoading() {
        if (queued) return
        manager.load(AssetPaths.PLAYER_CAR, Texture::class.java)
        queued = true
    }

    fun update(): Boolean {
        check(queued) { "queueLoading must be called before update" }
        val finished = manager.update()
        if (finished && !prepared) {
            manager.get(AssetPaths.PLAYER_CAR, Texture::class.java).setFilter(
                Texture.TextureFilter.Linear,
                Texture.TextureFilter.Linear,
            )
            prepared = true
        }
        return finished
    }

    override fun dispose() {
        manager.dispose()
    }
}
