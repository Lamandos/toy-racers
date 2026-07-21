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
        val width = config.width * DISPLAY_UNITS_PER_PHYSICS_UNIT
        val length = config.length * DISPLAY_UNITS_PER_PHYSICS_UNIT
        val x = state.x - width / 2f
        val y = state.y - length / 2f

        batch.projectionMatrix = camera.combined
        batch.begin()
        batch.draw(
            texture,
            x,
            y,
            width / 2f,
            length / 2f,
            width,
            length,
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
        const val DISPLAY_UNITS_PER_PHYSICS_UNIT = 30f
        const val TEXTURE_FORWARD_DEGREES = 90f
    }
}
