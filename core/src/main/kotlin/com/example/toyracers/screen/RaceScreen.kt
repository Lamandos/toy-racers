package com.example.toyracers.screen

import com.badlogic.gdx.Gdx
import com.badlogic.gdx.Input
import com.badlogic.gdx.InputMultiplexer
import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.OrthographicCamera
import com.badlogic.gdx.graphics.g2d.SpriteBatch
import com.badlogic.gdx.graphics.glutils.ShapeRenderer
import com.badlogic.gdx.utils.ScreenUtils
import com.badlogic.gdx.utils.viewport.ExtendViewport
import com.example.toyracers.ToyRacersGame
import com.example.toyracers.camera.CameraBounds
import com.example.toyracers.camera.RaceCameraController
import com.example.toyracers.car.CarModel
import com.example.toyracers.car.CarPhysics
import com.example.toyracers.car.opponentModelsFor
import com.example.toyracers.debug.AiDebugRenderer
import com.example.toyracers.debug.CollisionDebugRenderer
import com.example.toyracers.debug.DebugCar
import com.example.toyracers.debug.DebugSettings
import com.example.toyracers.debug.FrameTelemetry
import com.example.toyracers.debug.FrameTelemetryRenderer
import com.example.toyracers.debug.FrameTelemetrySample
import com.example.toyracers.input.KeyboardInputController
import com.example.toyracers.input.PlayerInput
import com.example.toyracers.input.TouchInputController
import com.example.toyracers.race.RacePhase
import com.example.toyracers.race.RaceResult
import com.example.toyracers.race.RaceSession
import com.example.toyracers.render.CarRenderer
import com.example.toyracers.render.TrackRenderer
import com.example.toyracers.track.TrackLoader
import com.example.toyracers.track.TrackId
import com.example.toyracers.ui.RaceHudSnapshot
import com.example.toyracers.ui.RaceHudStage
import kotlin.math.min

/** First race view with a world-unit simulation and an independent screen-space UI. */
class RaceScreen(
    game: ToyRacersGame,
    private val trackId: TrackId = TrackId.LIVING_ROOM,
) : ToyRacersScreen(game) {
    private val worldCamera = OrthographicCamera()
    private val worldViewport = ExtendViewport(CAMERA_VIEW_WIDTH, CAMERA_VIEW_HEIGHT, worldCamera)
    private val track = TrackLoader().load(
        trackId = trackId,
        collisionMap = Gdx.files.internal(TrackLoader.tmxPath(trackId)).read(),
    )
    private val selectedCarModel = game.selectedCar
    private var raceSession = createRaceSession()
    private val carRenderers = CarModel.entries.associateWith { model ->
        CarRenderer(game.assets.car(model))
    }
    private val trackRenderer = TrackRenderer(game.assets.track(trackId))
    private val worldBatch = SpriteBatch()
    private val collisionDebugRenderer = CollisionDebugRenderer()
    private val aiDebugRenderer = AiDebugRenderer()
    private val debugSettings = DebugSettings()
    private val frameTelemetry = FrameTelemetry()
    private val frameTelemetryRenderer = FrameTelemetryRenderer()
    private val keyboardInput = KeyboardInputController()
    private val touchInput = TouchInputController(
        steeringWheelTexture = game.assets.steeringWheel,
        brakePedalTexture = game.assets.brakePedal,
        throttlePedalTexture = game.assets.throttlePedal,
    )
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
        cameraController.snapTo(raceSession.renderStateOf(raceSession.player))
        Gdx.input.inputProcessor = inputProcessor
        raceSession.start()
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
        handleKeyboardActions()

        val measureTimings = debugSettings.showPerformanceOverlay
        val frameDurationNanos = if (measureTimings) {
            (delta * NANOSECONDS_PER_SECOND).toLong()
        } else {
            0L
        }
        val frameDelta = min(delta, CarPhysics.MAX_FRAME_DELTA_SECONDS)
        val audioFadeStartedAt = if (measureTimings) System.nanoTime() else 0L
        game.audio.advanceRaceFadeOut(frameDelta)
        var audioDurationNanos = if (measureTimings) System.nanoTime() - audioFadeStartedAt else 0L

        val raceUpdate = updateRace(frameDelta, measureTimings)
        audioDurationNanos += raceUpdate.audioDurationNanos

        val worldRenderStartedAt = if (measureTimings) System.nanoTime() else 0L
        val worldRender = renderWorld()
        val worldRenderDurationNanos = if (measureTimings) {
            System.nanoTime() - worldRenderStartedAt
        } else {
            0L
        }

        val interfaceStartedAt = if (measureTimings) System.nanoTime() else 0L
        renderInterface(delta)
        val interfaceDurationNanos = if (measureTimings) {
            System.nanoTime() - interfaceStartedAt
        } else {
            0L
        }

        if (measureTimings) {
            val snapshot = frameTelemetry.record(
                FrameTelemetrySample(
                    frameDurationNanos = frameDurationNanos,
                    simulationDurationNanos = raceUpdate.simulationDurationNanos,
                    collisionDurationNanos = raceUpdate.collisionDurationNanos,
                    worldRenderDurationNanos = worldRenderDurationNanos,
                    interfaceDurationNanos = interfaceDurationNanos,
                    audioDurationNanos = audioDurationNanos,
                    physicalSteps = raceUpdate.physicalSteps,
                    worldDrawCalls = worldRender.drawCalls,
                    carFlushes = worldRender.carFlushes,
                    framesPerSecond = Gdx.graphics.framesPerSecond,
                    refreshRateHz = Gdx.graphics.displayMode?.refreshRate?.takeIf { it > 0 },
                ),
            )
            frameTelemetryRenderer.render(viewport, camera, snapshot)
        }

        showResultsIfFinished()
    }

    private fun handleKeyboardActions() {
        if (!lifecyclePaused && Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE)) {
            when (raceSession.raceState.phase) {
                RacePhase.RACING -> pauseRace()
                RacePhase.PAUSED -> resumeRace()
                else -> Unit
            }
        }
        if (!lifecyclePaused && Gdx.input.isKeyJustPressed(Input.Keys.R)) {
            resetRace()
        }
        if (Gdx.input.isKeyJustPressed(Input.Keys.F3)) {
            debugSettings.showCollisions = !debugSettings.showCollisions
        }
        if (Gdx.input.isKeyJustPressed(Input.Keys.F4)) {
            debugSettings.showAi = !debugSettings.showAi
        }
        if (Gdx.input.isKeyJustPressed(Input.Keys.F5)) {
            debugSettings.showPerformanceOverlay = !debugSettings.showPerformanceOverlay
            frameTelemetry.clear()
        }
    }

    private fun updateRace(
        frameDelta: Float,
        measureTimings: Boolean,
    ): RaceUpdateMetrics {
        var simulationDurationNanos = 0L
        var collisionDurationNanos = 0L
        var physicalSteps = 0
        var audioDurationNanos = 0L
        if (!lifecyclePaused) {
            val playerInput = keyboardInput.readInput().combinedWith(touchInput.readInput())
            val simulationStartedAt = if (measureTimings) System.nanoTime() else 0L
            val stepResult = raceSession.advance(
                frameDeltaSeconds = frameDelta,
                playerInput = playerInput,
                measureTimings = measureTimings,
            )
            if (measureTimings) {
                simulationDurationNanos = System.nanoTime() - simulationStartedAt
                collisionDurationNanos = stepResult.collisionDurationNanos
            }
            physicalSteps = stepResult.physicalSteps
            val audioEventsStartedAt = if (measureTimings) System.nanoTime() else 0L
            updateCountdownAudio(stepResult.phaseBeforeAdvance)
            if (raceSession.raceState.phase == RacePhase.RACING) {
                latestInput = playerInput
            }
            if (stepResult.playerCheckpointPassed) {
                game.audio.checkpoint()
            }
            if (stepResult.maxImpactSpeed >= MIN_SHAKE_IMPACT_SPEED) {
                cameraController.addShake(
                    stepResult.maxImpactSpeed * SHAKE_PER_IMPACT_SPEED,
                )
                game.audio.collision(
                    stepResult.maxImpactSpeed / raceSession.player.carConfig.maxForwardSpeed,
                )
            }
            if (measureTimings) {
                audioDurationNanos += System.nanoTime() - audioEventsStartedAt
            }
        }
        val renderedPlayerState = raceSession.renderStateOf(raceSession.player)
        cameraController.update(renderedPlayerState, frameDelta)
        val physicalPlayerState = raceSession.player.state
        val audioMixStartedAt = if (measureTimings) System.nanoTime() else 0L
        game.audio.updateRace(
            speed = physicalPlayerState.speed,
            maxSpeed = raceSession.player.carConfig.maxForwardSpeed,
            throttle = latestInput.throttle,
            brake = latestInput.brake,
            steering = latestInput.steering,
            racing = raceSession.raceState.phase == RacePhase.RACING,
            surface = track.surfaceAt(
                physicalPlayerState.x,
                physicalPlayerState.y,
            ),
        )
        if (measureTimings) {
            audioDurationNanos += System.nanoTime() - audioMixStartedAt
        }
        return RaceUpdateMetrics(
            simulationDurationNanos = simulationDurationNanos,
            collisionDurationNanos = collisionDurationNanos,
            audioDurationNanos = audioDurationNanos,
            physicalSteps = physicalSteps,
        )
    }

    private fun renderWorld(): WorldRenderMetrics {
        ScreenUtils.clear(0f, 0f, 0f, 1f)
        worldViewport.apply()
        worldCamera.update()
        worldBatch.projectionMatrix = worldCamera.combined
        worldBatch.begin()
        trackRenderer.render(worldBatch, track)
        (raceSession.opponents.sortedBy { it.carModel.ordinal } + raceSession.player)
            .forEach { participant ->
                carRenderers.getValue(participant.carModel).render(
                    batch = worldBatch,
                    state = raceSession.renderStateOf(participant),
                    config = participant.carConfig,
                )
            }
        worldBatch.end()
        val worldDrawCalls = worldBatch.renderCalls
        if (debugSettings.showCollisions) {
            collisionDebugRenderer.render(
                viewport = worldViewport,
                camera = worldCamera,
                shapes = shapes,
                track = track,
                cars = listOf(
                    DebugCar(
                        raceSession.renderStateOf(raceSession.player),
                        raceSession.player.carConfig.collisionRadius,
                        raceSession.player.carConfig.collisionLongitudinalOffset,
                    ),
                ) + raceSession.opponents.map {
                    DebugCar(
                        raceSession.renderStateOf(it),
                        it.carConfig.collisionRadius,
                        it.carConfig.collisionLongitudinalOffset,
                    )
                },
            )
        }
        if (debugSettings.showAi) {
            aiDebugRenderer.render(
                viewport = worldViewport,
                camera = worldCamera,
                shapes = shapes,
                racingLine = track.racingLine,
                snapshots = raceSession.opponents.mapNotNull { it.driver?.debugSnapshot },
            )
        }
        return WorldRenderMetrics(
            drawCalls = worldDrawCalls,
            carFlushes = (worldDrawCalls - TRACK_DRAW_CALLS).coerceAtLeast(0),
        )
    }

    private fun renderInterface(delta: Float) {
        if (raceSession.raceState.phase == RacePhase.PAUSED || lifecyclePaused) {
            touchInput.reset()
        }
        touchInput.render(delta)
        hud.update(createHudSnapshot())
        hud.showPause(raceSession.raceState.phase == RacePhase.PAUSED || lifecyclePaused)
        hud.render(delta)

        if (raceSession.raceState.phase == RacePhase.COUNTDOWN) {
            renderCountdown()
        }
    }

    private fun showResultsIfFinished() {
        if (!lifecyclePaused && raceSession.raceState.phase == RacePhase.FINISHED) {
            if (!finishSoundPlayed) {
                finishSoundPlayed = true
                latestInput = PlayerInput.NONE
                game.audio.finish()
                game.audio.beginRaceFadeOut()
            }
            if (!game.audio.isRaceFadeComplete) {
                return
            }
            game.showResults(
                RaceResult(
                    finishPosition = raceSession.playerPosition,
                    competitorCount = raceSession.opponents.size + 1,
                    totalRaceTime = raceSession.player.progress.totalRaceTime,
                    bestLapTime = raceSession.player.progress.bestLapTime,
                ),
            )
        }
    }

    private fun handlePendingUiAction(): Boolean {
        val action = pendingUiAction ?: return false
        pendingUiAction = null
        when (action) {
            RaceUiAction.PAUSE -> pauseRace()
            RaceUiAction.RESUME -> resumeRace()
            RaceUiAction.RESTART -> if (!lifecyclePaused) resetRace()
            RaceUiAction.QUIT_TO_MENU -> {
                game.showMainMenu()
                return true
            }
        }
        return false
    }

    private fun createHudSnapshot(): RaceHudSnapshot = RaceHudSnapshot(
        position = raceSession.playerPosition,
        competitorCount = raceSession.opponents.size + 1,
        completedLaps = raceSession.player.progress.completedLaps,
        requiredLaps = raceSession.requiredLaps,
        totalRaceTime = raceSession.player.progress.totalRaceTime,
        bestLapTime = raceSession.player.progress.bestLapTime,
    )

    private fun resetRace() {
        raceSession = createRaceSession().also(RaceSession::start)
        latestInput = PlayerInput.NONE
        lastCountdownNumber = -1
        finishSoundPlayed = false
        game.audio.resetRaceMix()
        game.audio.resumeRace()
        touchInput.reset()
        cameraController.snapTo(raceSession.renderStateOf(raceSession.player))
    }

    private fun renderCountdown() {
        val activeLight =
            raceSession.raceState.countdownRemainingSeconds.toInt().coerceIn(0, 2)
        beginShapes(ShapeRenderer.ShapeType.Filled)
        shapes.color = Color(0f, 0f, 0f, 0.68f)
        shapes.rect(530f, 275f, 220f, 170f)
        repeat(3) { index ->
            shapes.color = if (index == activeLight) COUNTDOWN_ACTIVE else COUNTDOWN_INACTIVE
            shapes.circle(580f + index * 60f, 360f, 22f)
        }
        shapes.end()
    }

    private fun createRaceSession(): RaceSession = RaceSession(
        track = track,
        playerCarModel = selectedCarModel,
        opponentCarModels = opponentModelsFor(selectedCarModel),
        opponentDifficulty = game.selectedAiDifficulty,
    )

    private fun updateCountdownAudio(phaseBeforeAdvance: RacePhase) {
        if (raceSession.raceState.phase == RacePhase.COUNTDOWN) {
            val countdownNumber =
                kotlin.math.ceil(raceSession.raceState.countdownRemainingSeconds).toInt()
            if (countdownNumber != lastCountdownNumber) {
                lastCountdownNumber = countdownNumber
                if (countdownNumber == COUNTDOWN_START_NUMBER) {
                    game.audio.countdown()
                }
            }
        } else if (
            phaseBeforeAdvance == RacePhase.COUNTDOWN &&
            raceSession.raceState.phase == RacePhase.RACING
        ) {
            game.audio.go()
        }
    }

    private fun pauseRace() {
        if (raceSession.raceState.phase != RacePhase.RACING) return
        raceSession.pause()
        game.audio.pauseRace()
        latestInput = PlayerInput.NONE
        touchInput.reset()
    }

    private fun resumeRace() {
        if (lifecyclePaused || raceSession.raceState.phase != RacePhase.PAUSED) return
        raceSession.resume()
        game.audio.resumeRace()
        touchInput.reset()
    }

    override fun pause() {
        pauseRace()
        touchInput.reset()
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
        worldBatch.dispose()
        carRenderers.values.forEach(CarRenderer::dispose)
        trackRenderer.dispose()
        aiDebugRenderer.dispose()
        frameTelemetryRenderer.dispose()
        super.dispose()
    }

    private companion object {
        const val CAMERA_VIEW_WIDTH = 24f
        const val CAMERA_VIEW_HEIGHT = CAMERA_VIEW_WIDTH * 9f / 16f
        const val MIN_SHAKE_IMPACT_SPEED = 3f
        const val SHAKE_PER_IMPACT_SPEED = 0.025f
        const val COUNTDOWN_START_NUMBER = 3
        const val TRACK_DRAW_CALLS = 1
        const val NANOSECONDS_PER_SECOND = 1_000_000_000f
        val COUNTDOWN_ACTIVE = Color(0.95f, 0.28f, 0.18f, 1f)
        val COUNTDOWN_INACTIVE = Color(0.25f, 0.27f, 0.31f, 1f)
    }

    private enum class RaceUiAction {
        PAUSE,
        RESUME,
        RESTART,
        QUIT_TO_MENU,
    }

    private data class RaceUpdateMetrics(
        val simulationDurationNanos: Long,
        val collisionDurationNanos: Long,
        val audioDurationNanos: Long,
        val physicalSteps: Int,
    )

    private data class WorldRenderMetrics(
        val drawCalls: Int,
        val carFlushes: Int,
    )
}
