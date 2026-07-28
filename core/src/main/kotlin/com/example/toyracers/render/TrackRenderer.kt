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
    private val batch: SpriteBatch = SpriteBatch(),
) : Disposable {
    fun render(
        viewport: Viewport,
        camera: Camera,
        track: Track,
    ) {
        ScreenUtils.clear(0f, 0f, 0f, 1f)
        viewport.apply()
        camera.update()
        batch.projectionMatrix = camera.combined
        batch.begin()
        batch.draw(
            texture,
            track.worldBounds.x,
            track.worldBounds.y,
            track.worldBounds.width,
            track.worldBounds.height,
        )
        batch.end()
    }

    override fun dispose() {
        batch.dispose()
    }

}
