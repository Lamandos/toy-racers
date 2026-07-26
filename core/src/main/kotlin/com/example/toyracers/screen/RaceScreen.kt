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
import com.example.toyracers.collision.CollisionSystem
import com.example.toyracers.debug.CollisionDebugRenderer
import com.example.toyracers.debug.DebugCar
import com.example.toyracers.debug.DebugSettings
import com.example.toyracers.input.KeyboardInputController
import com.example.toyracers.input.TouchInputController
import com.example.toyracers.race.RaceProgress
import com.example.toyracers.race.RaceRules
import com.example.toyracers.render.CarRenderer
import com.example.toyracers.render.TrackRenderer
import com.example.toyracers.surface.SurfaceSpeedState
import com.example.toyracers.surface.SurfaceSpeedSystem
import com.example.toyracers.track.TrackLoader
import com.example.toyracers.track.TrackPoint
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
    private val collisionSystem = CollisionSystem()
    private val raceRules = RaceRules(track)
    private val raceProgress = RaceProgress()
    private val surfaceSpeedSystem = SurfaceSpeedSystem()
    private val surfaceSpeedState = SurfaceSpeedState()
    private val carRenderer = CarRenderer(game.assets.playerCar)
    private val trackRenderer = TrackRenderer()
    private val collisionDebugRenderer = CollisionDebugRenderer()
    private val debugSettings = DebugSettings()
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
        if (Gdx.input.isKeyJustPressed(Input.Keys.F3)) {
            debugSettings.showCollisions = !debugSettings.showCollisions
        }

        if (!lifecyclePaused && !manuallyPaused) {
            val playerInput = keyboardInput.readInput().combinedWith(touchInput.readInput())
            accumulator += min(delta, CarPhysics.MAX_FRAME_DELTA_SECONDS)
            while (accumulator >= CarPhysics.FIXED_DELTA_SECONDS) {
                val previousPosition = TrackPoint(carState.x, carState.y)
                carPhysics.update(
                    carState,
                    carConfig,
                    playerInput,
                    CarPhysics.FIXED_DELTA_SECONDS,
                )
                val collision = collisionSystem.resolveTrackCollision(
                    state = carState,
                    radius = carConfig.collisionRadius,
                    track = track,
                )
                surfaceSpeedSystem.update(
                    carState = carState,
                    carConfig = carConfig,
                    surfaceState = surfaceSpeedState,
                    surface = track.surfaceAt(carState.x, carState.y),
                    deltaSeconds = CarPhysics.FIXED_DELTA_SECONDS,
                )
                raceRules.update(
                    progress = raceProgress,
                    previousPosition = previousPosition,
                    currentPosition = TrackPoint(carState.x, carState.y),
                    deltaSeconds = CarPhysics.FIXED_DELTA_SECONDS,
                )
                if (collision.maxImpactSpeed >= MIN_SHAKE_IMPACT_SPEED) {
                    cameraController.addShake(
                        collision.maxImpactSpeed * SHAKE_PER_IMPACT_SPEED,
                    )
                }
                accumulator -= CarPhysics.FIXED_DELTA_SECONDS
            }
        }
        cameraController.update(carState, min(delta, CarPhysics.MAX_FRAME_DELTA_SECONDS))

        trackRenderer.render(worldViewport, worldCamera, shapes, track)

        carRenderer.render(worldCamera, carState, carConfig)
        if (debugSettings.showCollisions) {
            collisionDebugRenderer.render(
                viewport = worldViewport,
                camera = worldCamera,
                shapes = shapes,
                track = track,
                cars = listOf(DebugCar(carState, carConfig.collisionRadius)),
            )
        }

        if (manuallyPaused || lifecyclePaused) {
            beginShapes(ShapeRenderer.ShapeType.Filled)
            shapes.color = Color(0f, 0f, 0f, 0.55f)
            shapes.rect(0f, 0f, ToyRacersGame.VIRTUAL_WIDTH, ToyRacersGame.VIRTUAL_HEIGHT)
            shapes.color = Color(0.98f, 0.76f, 0.22f, 1f)
            shapes.rect(465f, 300f, 350f, 120f)
            shapes.end()
        }

        touchInput.render(delta)

        if (!lifecyclePaused && !manuallyPaused && raceProgress.finished) {
            game.showResults()
        }
    }

    private fun resetRace() {
        carState.x = playerStart.position.x
        carState.y = playerStart.position.y
        carState.rotationDeg = playerStart.rotationDeg
        carState.speed = 0f
        carState.velocityX = 0f
        carState.velocityY = 0f
        carState.angularVelocity = 0f
        surfaceSpeedState.speedMultiplier = 1f
        raceProgress.currentCheckpointIndex = 0
        raceProgress.completedLaps = 0
        raceProgress.lapStartTime = 0f
        raceProgress.bestLapTime = null
        raceProgress.totalRaceTime = 0f
        raceProgress.finished = false
        raceProgress.finishPosition = null
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
        const val MIN_SHAKE_IMPACT_SPEED = 3f
        const val SHAKE_PER_IMPACT_SPEED = 0.025f
    }
}
