package com.example.toyracers.render

import com.badlogic.gdx.graphics.Camera
import com.badlogic.gdx.graphics.Texture
import com.badlogic.gdx.graphics.g2d.SpriteBatch
import com.badlogic.gdx.utils.Disposable
import com.badlogic.gdx.utils.ScreenUtils
import com.badlogic.gdx.utils.viewport.Viewport
import com.example.toyracers.track.Track

/** Draws the authored track image without owning or changing gameplay state. */
class TrackRenderer(
    private val texture: Texture,
    /** Retains the previous public parameter name and default-argument constructor ABI. */
    batch: SpriteBatch? = null,
) : Disposable {
    private var compatibilityBatch: SpriteBatch? = batch

    /** Draws into an already active shared batch. */
    fun render(
        batch: SpriteBatch,
        track: Track,
    ) {
        batch.draw(
            texture,
            track.worldBounds.x,
            track.worldBounds.y,
            track.worldBounds.width,
            track.worldBounds.height,
        )
    }

    /** Compatibility path for presentation code that still uses a dedicated track batch. */
    fun render(
        viewport: Viewport,
        camera: Camera,
        track: Track,
    ) {
        val batch = compatibilityBatch ?: SpriteBatch().also { compatibilityBatch = it }
        ScreenUtils.clear(0f, 0f, 0f, 1f)
        viewport.apply()
        camera.update()
        batch.projectionMatrix = camera.combined
        batch.begin()
        render(batch, track)
        batch.end()
    }

    override fun dispose() {
        compatibilityBatch?.dispose()
        compatibilityBatch = null
    }

}
