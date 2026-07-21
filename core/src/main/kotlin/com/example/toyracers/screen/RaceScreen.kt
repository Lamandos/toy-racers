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
import com.example.toyracers.input.KeyboardInputController
import com.example.toyracers.input.TouchInputController
import com.example.toyracers.render.CarRenderer
import kotlin.math.min

/** First race view: a resolution-independent test track without gameplay physics. */
class RaceScreen(game: ToyRacersGame) : ToyRacersScreen(game) {
    private var manuallyPaused = false
    private var accumulator = 0f
    private val carState = CarState(
        x = START_X,
        y = START_Y,
        rotationDeg = START_ROTATION_DEG,
    )
    private val carConfig = CarConfig()
    private val carPhysics = CarPhysics()
    private val carRenderer = CarRenderer(game.assets.playerCar)
    private val keyboardInput = KeyboardInputController()
    private val touchInput = TouchInputController()

    override fun show() {
        super.show()
        Gdx.input.inputProcessor = touchInput.inputProcessor
    }

    override fun resize(width: Int, height: Int) {
        super.resize(width, height)
        touchInput.resize(width, height)
    }

    override fun render(delta: Float) {
        if (!lifecyclePaused && Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE)) {
            manuallyPaused = !manuallyPaused
            touchInput.reset()
        }
        if (!lifecyclePaused && Gdx.input.isKeyJustPressed(Input.Keys.R)) {
            resetRace()
        }

        if (!lifecyclePaused && !manuallyPaused) {
            val playerInput = keyboardInput.readInput().combinedWith(touchInput.readInput())
            accumulator += min(delta, CarPhysics.MAX_FRAME_DELTA_SECONDS)
            while (accumulator >= CarPhysics.FIXED_DELTA_SECONDS) {
                carPhysics.update(
                    carState,
                    carConfig,
                    playerInput,
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

        touchInput.render(delta)

        if (!lifecyclePaused && !manuallyPaused && finishRequested()) {
            game.showResults()
        }
    }

    private fun finishRequested(): Boolean =
        Gdx.input.isKeyJustPressed(Input.Keys.ENTER) ||
            Gdx.input.isKeyJustPressed(Input.Keys.SPACE)

    private fun resetRace() {
        carState.x = START_X
        carState.y = START_Y
        carState.rotationDeg = START_ROTATION_DEG
        carState.speed = 0f
        carState.velocityX = 0f
        carState.velocityY = 0f
        carState.angularVelocity = 0f
        accumulator = 0f
        manuallyPaused = false
        touchInput.reset()
    }

    override fun pause() {
        touchInput.reset()
        super.pause()
    }

    override fun resume() {
        touchInput.reset()
        super.resume()
    }

    override fun hide() {
        touchInput.reset()
        if (Gdx.input.inputProcessor === touchInput.inputProcessor) {
            Gdx.input.inputProcessor = null
        }
    }

    override fun dispose() {
        touchInput.dispose()
        carRenderer.dispose()
        super.dispose()
    }

    private companion object {
        val GRASS = Color(0.18f, 0.48f, 0.24f, 1f)
        val ASPHALT = Color(0.20f, 0.22f, 0.25f, 1f)
        const val START_X = 605f
        const val START_Y = 190f
        const val START_ROTATION_DEG = 90f
    }
}
