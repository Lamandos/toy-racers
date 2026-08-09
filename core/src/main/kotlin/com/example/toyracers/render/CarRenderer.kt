package com.example.toyracers.render

import com.badlogic.gdx.graphics.Camera
import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.g2d.SpriteBatch
import com.badlogic.gdx.graphics.g2d.TextureRegion
import com.badlogic.gdx.utils.Disposable
import com.example.toyracers.car.CarConfig
import com.example.toyracers.car.CarState

/** Draws a car from simulation state without modifying that state. */
class CarRenderer(
    private val texture: TextureRegion,
) : Disposable {
    private var compatibilityBatch: SpriteBatch? = null

    /** Retained for callers that still render a car in its own pass. */
    constructor(
        texture: TextureRegion,
        batch: SpriteBatch,
    ) : this(texture) {
        compatibilityBatch = batch
    }

    /** Draws into an already active shared batch. */
    fun render(
        batch: SpriteBatch,
        state: CarState,
        config: CarConfig,
        tint: Color = Color.WHITE,
    ) {
        val bounds = calculateCarRenderBounds(state, config)
        batch.color = tint
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
        batch.color = Color.WHITE
    }

    /**
     * Compatibility path for presentation code that has not adopted a shared world batch yet.
     * RaceScreen uses the overload above so it does not allocate one SpriteBatch per car model.
     */
    fun render(
        camera: Camera,
        state: CarState,
        config: CarConfig,
        tint: Color = Color.WHITE,
    ) {
        val batch = compatibilityBatch ?: SpriteBatch().also { compatibilityBatch = it }
        batch.projectionMatrix = camera.combined
        batch.begin()
        render(batch, state, config, tint)
        batch.end()
    }

    override fun dispose() {
        compatibilityBatch?.dispose()
        compatibilityBatch = null
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
