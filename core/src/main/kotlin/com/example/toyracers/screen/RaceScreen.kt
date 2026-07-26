package com.example.toyracers.screen

import com.badlogic.gdx.Gdx
import com.badlogic.gdx.Input
import com.badlogic.gdx.InputMultiplexer
import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.OrthographicCamera
import com.badlogic.gdx.graphics.glutils.ShapeRenderer
import com.badlogic.gdx.utils.viewport.FitViewport
import com.example.toyracers.ToyRacersGame
import com.example.toyracers.ai.AiDriver
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
import com.example.toyracers.input.PlayerInput
import com.example.toyracers.race.RaceProgress
import com.example.toyracers.race.RacePhase
import com.example.toyracers.race.RaceCompetitor
import com.example.toyracers.race.RaceResult
import com.example.toyracers.race.RaceRules
import com.example.toyracers.race.RaceState
import com.example.toyracers.race.PositionTracker
import com.example.toyracers.render.CarRenderer
import com.example.toyracers.render.TrackRenderer
import com.example.toyracers.surface.SurfaceSpeedState
import com.example.toyracers.surface.SurfaceSpeedSystem
import com.example.toyracers.track.StartGridPosition
import com.example.toyracers.track.TrackLoader
import com.example.toyracers.track.TrackPoint
import com.example.toyracers.ui.RaceHudSnapshot
import com.example.toyracers.ui.RaceHudStage
import kotlin.math.min

/** First race view with a world-unit simulation and an independent screen-space UI. */
class RaceScreen(game: ToyRacersGame) : ToyRacersScreen(game) {
    private val worldCamera = OrthographicCamera()
    private val worldViewport = FitViewport(CAMERA_VIEW_WIDTH, CAMERA_VIEW_HEIGHT, worldCamera)
    private var accumulator = 0f
    private val track = TrackLoader().load()
    private val playerStart = track.startGrid.first()
    private val carState = CarState(
        x = playerStart.position.x,
        y = playerStart.position.y,
        rotationDeg = playerStart.rotationDeg,
    )
    private val aiCars = track.startGrid.drop(1).map { start ->
        AiCar(
            start = start,
            state = CarState(
                x = start.position.x,
                y = start.position.y,
                rotationDeg = start.rotationDeg,
            ),
            driver = AiDriver(track.racingLine, start.position),
        )
    }
    private val carConfig = CarConfig()
    private val carPhysics = CarPhysics()
    private val collisionSystem = CollisionSystem()
    private val raceRules = RaceRules(track)
    private val raceProgress = RaceProgress()
    private val raceState = RaceState()
    private val positionTracker = PositionTracker(track)
    private val surfaceSpeedSystem = SurfaceSpeedSystem()
    private val surfaceSpeedState = SurfaceSpeedState()
    private val playerCarRenderer = CarRenderer(game.assets.playerCar)
    private val opponentCarRenderer = CarRenderer(game.assets.opponentCar)
    private val trackRenderer = TrackRenderer()
    private val collisionDebugRenderer = CollisionDebugRenderer()
    private val debugSettings = DebugSettings()
    private val keyboardInput = KeyboardInputController()
    private val touchInput = TouchInputController()
    private var pendingUiAction: RaceUiAction? = null
    private var latestInput = PlayerInput.NONE
    private var lastCountdownNumber = -1
    private var finishSoundPlayed = false
    private val hud = RaceHudStage(
        onPause = { pendingUiAction = RaceUiAction.PAUSE },
        onResume = { pendingUiAction = RaceUiAction.RESUME },
        onRestart = { pendingUiAction = RaceUiAction.RESTART },
        onQuitToMenu = { pendingUiAction = RaceUiAction.QUIT_TO_MENU },
        onButtonClick = game.audio::buttonClick,
    )
    private val inputProcessor = InputMultiplexer(hud.inputProcessor, touchInput.inputProcessor)
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
        Gdx.input.inputProcessor = inputProcessor
        raceState.markReady()
        raceState.startCountdown()
        game.audio.startRaceLoops()
    }

    override fun resize(width: Int, height: Int) {
        super.resize(width, height)
        worldViewport.update(width, height, true)
        touchInput.resize(width, height)
        hud.resize(width, height)
    }

    override fun render(delta: Float) {
        if (handlePendingUiAction()) return
        if (!lifecyclePaused && Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE)) {
            when (raceState.phase) {
                RacePhase.RACING -> {
                    raceState.pause()
                    touchInput.reset()
                }
                RacePhase.PAUSED -> {
                    raceState.resume()
                    touchInput.reset()
                }
                else -> Unit
            }
        }
        if (!lifecyclePaused && Gdx.input.isKeyJustPressed(Input.Keys.R)) {
            resetRace()
        }
        if (Gdx.input.isKeyJustPressed(Input.Keys.F3)) {
            debugSettings.showCollisions = !debugSettings.showCollisions
        }

        val frameDelta = min(delta, CarPhysics.MAX_FRAME_DELTA_SECONDS)
        val phaseBeforeAdvance = raceState.phase
        val simulationDelta = if (lifecyclePaused) 0f else raceState.advance(frameDelta)
        updateCountdownAudio(phaseBeforeAdvance)
        if (simulationDelta > 0f) {
            val playerInput = keyboardInput.readInput().combinedWith(touchInput.readInput())
            latestInput = playerInput
            accumulator += simulationDelta
            while (accumulator >= CarPhysics.FIXED_DELTA_SECONDS) {
                val previousPosition = TrackPoint(carState.x, carState.y)
                val aiPreviousPositions = aiCars.map {
                    TrackPoint(it.state.x, it.state.y)
                }
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
                val checkpointBefore = raceProgress.currentCheckpointIndex
                raceRules.update(
                    progress = raceProgress,
                    previousPosition = previousPosition,
                    currentPosition = TrackPoint(carState.x, carState.y),
                    deltaSeconds = CarPhysics.FIXED_DELTA_SECONDS,
                )
                if (raceProgress.currentCheckpointIndex > checkpointBefore) {
                    game.audio.checkpoint()
                }
                aiCars.forEachIndexed { index, aiCar ->
                    carPhysics.update(
                        state = aiCar.state,
                        config = carConfig,
                        rawInput = aiCar.driver.update(
                            aiCar.state,
                            CarPhysics.FIXED_DELTA_SECONDS,
                        ),
                        deltaSeconds = CarPhysics.FIXED_DELTA_SECONDS,
                    )
                    collisionSystem.resolveTrackCollision(
                        state = aiCar.state,
                        radius = carConfig.collisionRadius,
                        track = track,
                    )
                    surfaceSpeedSystem.update(
                        carState = aiCar.state,
                        carConfig = carConfig,
                        surfaceState = aiCar.surfaceSpeedState,
                        surface = track.surfaceAt(aiCar.state.x, aiCar.state.y),
                        deltaSeconds = CarPhysics.FIXED_DELTA_SECONDS,
                    )
                    raceRules.update(
                        progress = aiCar.raceProgress,
                        previousPosition = aiPreviousPositions[index],
                        currentPosition = TrackPoint(aiCar.state.x, aiCar.state.y),
                        deltaSeconds = CarPhysics.FIXED_DELTA_SECONDS,
                    )
                }
                val maxImpact = maxOf(collision.maxImpactSpeed, resolveCarCollisions())
                if (maxImpact >= MIN_SHAKE_IMPACT_SPEED) {
                    cameraController.addShake(
                        maxImpact * SHAKE_PER_IMPACT_SPEED,
                    )
                    game.audio.collision(maxImpact / carConfig.maxForwardSpeed)
                }
                accumulator -= CarPhysics.FIXED_DELTA_SECONDS
                if (raceProgress.finished) {
                    raceState.finish()
                    accumulator = 0f
                    break
                }
            }
        }
        cameraController.update(carState, frameDelta)
        game.audio.updateRace(
            speed = carState.speed,
            maxSpeed = carConfig.maxForwardSpeed,
            throttle = latestInput.throttle,
            steering = latestInput.steering,
            racing = raceState.phase == RacePhase.RACING,
        )

        trackRenderer.render(worldViewport, worldCamera, shapes, track)

        aiCars.forEachIndexed { index, aiCar ->
            opponentCarRenderer.render(
                worldCamera,
                aiCar.state,
                carConfig,
                AI_CAR_TINTS[index % AI_CAR_TINTS.size],
            )
        }
        playerCarRenderer.render(worldCamera, carState, carConfig)
        if (debugSettings.showCollisions) {
            collisionDebugRenderer.render(
                viewport = worldViewport,
                camera = worldCamera,
                shapes = shapes,
                track = track,
                cars = listOf(DebugCar(carState, carConfig.collisionRadius)) +
                    aiCars.map { DebugCar(it.state, carConfig.collisionRadius) },
            )
        }

        if (raceState.phase == RacePhase.PAUSED || lifecyclePaused) {
            touchInput.reset()
        }
        touchInput.render(delta)
        hud.update(createHudSnapshot())
        hud.showPause(raceState.phase == RacePhase.PAUSED || lifecyclePaused)
        hud.render(delta)

        if (raceState.phase == RacePhase.COUNTDOWN) {
            renderCountdown()
        }

        if (!lifecyclePaused && raceState.phase == RacePhase.FINISHED) {
            if (!finishSoundPlayed) {
                finishSoundPlayed = true
                game.audio.finish()
            }
            game.showResults(
                RaceResult(
                    finishPosition = currentPlayerPosition(),
                    competitorCount = aiCars.size + 1,
                    totalRaceTime = raceProgress.totalRaceTime,
                    bestLapTime = raceProgress.bestLapTime,
                ),
            )
        }
    }

    private fun handlePendingUiAction(): Boolean {
        val action = pendingUiAction ?: return false
        pendingUiAction = null
        when (action) {
            RaceUiAction.PAUSE -> if (raceState.phase == RacePhase.RACING) {
                raceState.pause()
                game.audio.pauseRace()
                touchInput.reset()
            }
            RaceUiAction.RESUME -> if (raceState.phase == RacePhase.PAUSED && !lifecyclePaused) {
                raceState.resume()
                game.audio.resumeRace()
                touchInput.reset()
            }
            RaceUiAction.RESTART -> if (!lifecyclePaused) resetRace()
            RaceUiAction.QUIT_TO_MENU -> {
                game.showMainMenu()
                return true
            }
        }
        return false
    }

    private fun createHudSnapshot(): RaceHudSnapshot = RaceHudSnapshot(
        position = currentPlayerPosition(),
        competitorCount = aiCars.size + 1,
        completedLaps = raceProgress.completedLaps,
        requiredLaps = raceRules.requiredLaps,
        totalRaceTime = raceProgress.totalRaceTime,
        bestLapTime = raceProgress.bestLapTime,
    )

    private fun currentPlayerPosition(): Int =
        positionTracker.positions(
            listOf(
                RaceCompetitor(
                    id = PLAYER_ID,
                    progress = raceProgress,
                    position = TrackPoint(carState.x, carState.y),
                ),
            ) + aiCars.mapIndexed { index, aiCar ->
                RaceCompetitor(
                    id = "ai-$index",
                    progress = aiCar.raceProgress,
                    position = TrackPoint(aiCar.state.x, aiCar.state.y),
                )
            },
        ).getValue(PLAYER_ID)

    private fun resetRace() {
        carState.x = playerStart.position.x
        carState.y = playerStart.position.y
        carState.rotationDeg = playerStart.rotationDeg
        carState.speed = 0f
        carState.velocityX = 0f
        carState.velocityY = 0f
        carState.angularVelocity = 0f
        surfaceSpeedState.speedMultiplier = 1f
        resetProgress(raceProgress)
        aiCars.forEach { aiCar ->
            aiCar.state.x = aiCar.start.position.x
            aiCar.state.y = aiCar.start.position.y
            aiCar.state.rotationDeg = aiCar.start.rotationDeg
            aiCar.state.speed = 0f
            aiCar.state.velocityX = 0f
            aiCar.state.velocityY = 0f
            aiCar.state.angularVelocity = 0f
            aiCar.surfaceSpeedState.speedMultiplier = 1f
            resetProgress(aiCar.raceProgress)
            aiCar.driver.reset(aiCar.start.position)
        }
        accumulator = 0f
        raceState.restart()
        latestInput = PlayerInput.NONE
        lastCountdownNumber = -1
        finishSoundPlayed = false
        game.audio.resumeRace()
        touchInput.reset()
        cameraController.snapTo(carState)
    }

    private fun renderCountdown() {
        val activeLight = raceState.countdownRemainingSeconds.toInt().coerceIn(0, 2)
        beginShapes(ShapeRenderer.ShapeType.Filled)
        shapes.color = Color(0f, 0f, 0f, 0.68f)
        shapes.rect(530f, 275f, 220f, 170f)
        repeat(3) { index ->
            shapes.color = if (index == activeLight) COUNTDOWN_ACTIVE else COUNTDOWN_INACTIVE
            shapes.circle(580f + index * 60f, 360f, 22f)
        }
        shapes.end()
    }

    private fun resolveCarCollisions(): Float {
        val states = listOf(carState) + aiCars.map(AiCar::state)
        var maxImpactSpeed = 0f
        states.indices.forEach { firstIndex ->
            for (secondIndex in firstIndex + 1..<states.size) {
                val result = collisionSystem.resolveCarCollision(
                    first = states[firstIndex],
                    firstRadius = carConfig.collisionRadius,
                    second = states[secondIndex],
                    secondRadius = carConfig.collisionRadius,
                )
                maxImpactSpeed = maxOf(maxImpactSpeed, result.maxImpactSpeed)
            }
        }
        return maxImpactSpeed
    }

    private fun updateCountdownAudio(phaseBeforeAdvance: RacePhase) {
        if (raceState.phase == RacePhase.COUNTDOWN) {
            val countdownNumber = kotlin.math.ceil(raceState.countdownRemainingSeconds).toInt()
            if (countdownNumber != lastCountdownNumber) {
                lastCountdownNumber = countdownNumber
                game.audio.countdown()
            }
        } else if (phaseBeforeAdvance == RacePhase.COUNTDOWN && raceState.phase == RacePhase.RACING) {
            game.audio.go()
        }
    }

    private fun resetProgress(progress: RaceProgress) {
        progress.currentCheckpointIndex = 0
        progress.completedLaps = 0
        progress.lapStartTime = 0f
        progress.bestLapTime = null
        progress.totalRaceTime = 0f
        progress.finished = false
        progress.finishPosition = null
    }

    override fun pause() {
        touchInput.reset()
        if (raceState.phase == RacePhase.RACING) {
            raceState.pause()
            game.audio.pauseRace()
        }
        super.pause()
    }

    override fun resume() {
        touchInput.reset()
        super.resume()
    }

    override fun hide() {
        touchInput.reset()
        if (Gdx.input.inputProcessor === inputProcessor) {
            Gdx.input.inputProcessor = null
        }
    }

    override fun dispose() {
        game.audio.stopRaceLoops()
        touchInput.dispose()
        hud.dispose()
        playerCarRenderer.dispose()
        opponentCarRenderer.dispose()
        super.dispose()
    }

    private companion object {
        const val CAMERA_VIEW_WIDTH = 24f
        const val CAMERA_VIEW_HEIGHT = CAMERA_VIEW_WIDTH * 9f / 16f
        const val MIN_SHAKE_IMPACT_SPEED = 3f
        const val SHAKE_PER_IMPACT_SPEED = 0.025f
        const val PLAYER_ID = "player"
        val COUNTDOWN_ACTIVE = Color(0.95f, 0.28f, 0.18f, 1f)
        val COUNTDOWN_INACTIVE = Color(0.25f, 0.27f, 0.31f, 1f)
        val AI_CAR_TINTS = listOf(
            Color.WHITE,
            Color(0.72f, 0.90f, 1f, 1f),
            Color(1f, 0.72f, 0.82f, 1f),
        )
    }

    private data class AiCar(
        val start: StartGridPosition,
        val state: CarState,
        val driver: AiDriver,
        val surfaceSpeedState: SurfaceSpeedState = SurfaceSpeedState(),
        val raceProgress: RaceProgress = RaceProgress(),
    )

    private enum class RaceUiAction {
        PAUSE,
        RESUME,
        RESTART,
        QUIT_TO_MENU,
    }
}
