package com.example.toyracers.render

import com.badlogic.gdx.graphics.Camera
import com.badlogic.gdx.graphics.g2d.SpriteBatch
import com.badlogic.gdx.graphics.g2d.TextureRegion
import com.badlogic.gdx.utils.Disposable
import com.example.toyracers.car.CarConfig
import com.example.toyracers.car.CarState

/** Draws a car from simulation state without modifying that state. */
class CarRenderer(
    private val texture: TextureRegion,
    private val batch: SpriteBatch = SpriteBatch(),
) : Disposable {
    fun render(
        camera: Camera,
        state: CarState,
        config: CarConfig,
    ) {
        val bounds = calculateCarRenderBounds(state, config)

        batch.projectionMatrix = camera.combined
        batch.begin()
        batch.draw(
            texture,
            bounds.x,
            bounds.y,
            bounds.width / 2f,
            bounds.length / 2f,
            bounds.width,
            bounds.length,
            1f,
            1f,
            state.rotationDeg - TEXTURE_FORWARD_DEGREES,
        )
        batch.end()
    }

    override fun dispose() {
        batch.dispose()
    }

    private companion object {
        const val TEXTURE_FORWARD_DEGREES = 90f
    }
}

internal data class CarRenderBounds(
    val x: Float,
    val y: Float,
    val width: Float,
    val length: Float,
)

internal fun calculateCarRenderBounds(
    state: CarState,
    config: CarConfig,
): CarRenderBounds = CarRenderBounds(
    x = state.x - config.width / 2f,
    y = state.y - config.length / 2f,
    width = config.width,
    length = config.length,
)
