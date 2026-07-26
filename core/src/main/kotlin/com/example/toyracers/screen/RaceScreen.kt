package com.example.toyracers.screen

import com.badlogic.gdx.Gdx
import com.badlogic.gdx.Input
import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.OrthographicCamera
import com.badlogic.gdx.graphics.glutils.ShapeRenderer
import com.badlogic.gdx.utils.viewport.FitViewport
import com.example.toyracers.ToyRacersGame
import com.example.toyracers.camera.CameraBounds
import com.example.toyracers.camera.RaceCameraController
import com.example.toyracers.car.CarConfig
import com.example.toyracers.car.CarPhysics
import com.example.toyracers.car.CarState
import com.example.toyracers.input.KeyboardInputController
import com.example.toyracers.input.TouchInputController
import com.example.toyracers.render.CarRenderer
import com.example.toyracers.render.TrackRenderer
import com.example.toyracers.track.TrackLoader
import kotlin.math.min

/** First race view with a world-unit simulation and an independent screen-space UI. */
class RaceScreen(game: ToyRacersGame) : ToyRacersScreen(game) {
    private val worldCamera = OrthographicCamera()
    private val worldViewport = FitViewport(CAMERA_VIEW_WIDTH, CAMERA_VIEW_HEIGHT, worldCamera)
    private var manuallyPaused = false
    private var accumulator = 0f
    private val track = TrackLoader().load()
    private val playerStart = track.startGrid.first()
    private val carState = CarState(
        x = playerStart.position.x,
        y = playerStart.position.y,
        rotationDeg = playerStart.rotationDeg,
    )
    private val carConfig = CarConfig()
    private val carPhysics = CarPhysics()
    private val carRenderer = CarRenderer(game.assets.playerCar)
    private val trackRenderer = TrackRenderer()
    private val keyboardInput = KeyboardInputController()
    private val touchInput = TouchInputController()
    private val cameraController = RaceCameraController(
        camera = worldCamera,
        bounds = CameraBounds(
            minX = track.cameraBounds.x,
            minY = track.cameraBounds.y,
            maxX = track.cameraBounds.maxX,
            maxY = track.cameraBounds.maxY,
        ),
    )

    override fun show() {
        super.show()
        cameraController.snapTo(carState)
        Gdx.input.inputProcessor = touchInput.inputProcessor
    }

    override fun resize(width: Int, height: Int) {
        super.resize(width, height)
        worldViewport.update(width, height, true)
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
        cameraController.update(carState, min(delta, CarPhysics.MAX_FRAME_DELTA_SECONDS))

        trackRenderer.render(worldViewport, worldCamera, shapes, track)

        carRenderer.render(worldCamera, carState, carConfig)

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
        carState.x = playerStart.position.x
        carState.y = playerStart.position.y
        carState.rotationDeg = playerStart.rotationDeg
        carState.speed = 0f
        carState.velocityX = 0f
        carState.velocityY = 0f
        carState.angularVelocity = 0f
        accumulator = 0f
        manuallyPaused = false
        touchInput.reset()
        cameraController.snapTo(carState)
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
        const val CAMERA_VIEW_WIDTH = 24f
        const val CAMERA_VIEW_HEIGHT = CAMERA_VIEW_WIDTH * 9f / 16f
    }
}
