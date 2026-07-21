package com.example.toyracers.screen

import com.badlogic.gdx.Gdx
import com.badlogic.gdx.Input
import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.glutils.ShapeRenderer
import com.badlogic.gdx.utils.ScreenUtils
import com.example.toyracers.ToyRacersGame
import com.example.toyracers.car.CarConfig
import com.example.toyracers.car.CarPhysics
import com.example.toyracers.car.CarState
import com.example.toyracers.input.PlayerInput
import com.example.toyracers.render.CarRenderer
import kotlin.math.min

/** First race view: a resolution-independent test track without gameplay physics. */
class RaceScreen(game: ToyRacersGame) : ToyRacersScreen(game) {
    private var manuallyPaused = false
    private var accumulator = 0f
    private val carState = CarState(x = 605f, y = 190f, rotationDeg = 90f)
    private val carConfig = CarConfig()
    private val carPhysics = CarPhysics()
    private val carRenderer = CarRenderer(game.assets.playerCar)

    override fun render(delta: Float) {
        if (!lifecyclePaused && Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE)) {
            manuallyPaused = !manuallyPaused
        }

        if (!lifecyclePaused && !manuallyPaused) {
            accumulator += min(delta, CarPhysics.MAX_FRAME_DELTA_SECONDS)
            while (accumulator >= CarPhysics.FIXED_DELTA_SECONDS) {
                carPhysics.update(
                    carState,
                    carConfig,
                    PlayerInput.NONE,
                    CarPhysics.FIXED_DELTA_SECONDS,
                )
                accumulator -= CarPhysics.FIXED_DELTA_SECONDS
            }
        }

        ScreenUtils.clear(GRASS)
        beginShapes(ShapeRenderer.ShapeType.Filled)

        // A simple rectangular circuit: asphalt outside, grass in the infield.
        shapes.color = ASPHALT
        shapes.rect(120f, 90f, 1040f, 540f)
        shapes.color = GRASS
        shapes.rect(330f, 260f, 620f, 200f)

        // Start/finish stripe.
        shapes.color = Color.WHITE
        shapes.rect(610f, 90f, 16f, 170f)
        shapes.end()

        carRenderer.render(camera, carState, carConfig)

        if (manuallyPaused || lifecyclePaused) {
            beginShapes(ShapeRenderer.ShapeType.Filled)
            shapes.color = Color(0f, 0f, 0f, 0.55f)
            shapes.rect(0f, 0f, ToyRacersGame.VIRTUAL_WIDTH, ToyRacersGame.VIRTUAL_HEIGHT)
            shapes.color = Color(0.98f, 0.76f, 0.22f, 1f)
            shapes.rect(465f, 300f, 350f, 120f)
            shapes.end()
        }

        if (!lifecyclePaused && !manuallyPaused && finishRequested()) {
            game.showResults()
        }
    }

    private fun finishRequested(): Boolean =
        Gdx.input.isKeyJustPressed(Input.Keys.ENTER) ||
            Gdx.input.isKeyJustPressed(Input.Keys.SPACE)

    override fun dispose() {
        carRenderer.dispose()
        super.dispose()
    }

    private companion object {
        val GRASS = Color(0.18f, 0.48f, 0.24f, 1f)
        val ASPHALT = Color(0.20f, 0.22f, 0.25f, 1f)
    }
}
