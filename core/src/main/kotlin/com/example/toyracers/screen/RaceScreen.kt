package com.example.toyracers.screen

import com.badlogic.gdx.Gdx
import com.badlogic.gdx.Input
import com.badlogic.gdx.InputMultiplexer
import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.OrthographicCamera
import com.badlogic.gdx.graphics.glutils.ShapeRenderer
import com.badlogic.gdx.utils.viewport.FitViewport
import com.example.toyracers.ToyRacersGame
import com.example.toyracers.camera.CameraBounds
import com.example.toyracers.camera.RaceCameraController
import com.example.toyracers.car.CarPhysics
import com.example.toyracers.debug.CollisionDebugRenderer
import com.example.toyracers.debug.DebugCar
import com.example.toyracers.debug.DebugSettings
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
    private val worldViewport = FitViewport(CAMERA_VIEW_WIDTH, CAMERA_VIEW_HEIGHT, worldCamera)
    private val track = TrackLoader().load(
        trackId = trackId,
        collisionMap = Gdx.files.internal(TrackLoader.tmxPath(trackId)).read(),
    )
    private var raceSession = RaceSession(track)
    private val playerCarRenderer = CarRenderer(game.assets.playerCar)
    private val opponentCarRenderer = CarRenderer(game.assets.opponentCar)
    private val trackRenderer = TrackRenderer(game.assets.track(trackId))
    private val collisionDebugRenderer = CollisionDebugRenderer()
    private val debugSettings = DebugSettings()
    private val keyboardInput = KeyboardInputController()
    private val touchInput = TouchInputController()
    private var pendingUiAction: RaceUiAction? = null
    private var latestInput = PlayerInput.NONE
    private var lastCountdownNumber = -1
    private var finishSoundPlayed = false
    private var finishTransitionRemaining = 0f
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
        cameraController.snapTo(raceSession.player.state)
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

        val frameDelta = min(delta, CarPhysics.MAX_FRAME_DELTA_SECONDS)
        game.audio.advanceRaceFadeOut(frameDelta)
        updateRace(frameDelta)
        renderWorld()
        renderInterface(delta)
        showResultsIfFinished(frameDelta)
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
    }

    private fun updateRace(frameDelta: Float) {
        if (!lifecyclePaused) {
            val playerInput = keyboardInput.readInput().combinedWith(touchInput.readInput())
            val stepResult = raceSession.advance(frameDelta, playerInput)
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
                    stepResult.maxImpactSpeed / raceSession.carConfig.maxForwardSpeed,
                )
            }
        }
        cameraController.update(raceSession.player.state, frameDelta)
        game.audio.updateRace(
            speed = raceSession.player.state.speed,
            maxSpeed = raceSession.carConfig.maxForwardSpeed,
            throttle = latestInput.throttle,
            brake = latestInput.brake,
            steering = latestInput.steering,
            racing = raceSession.raceState.phase == RacePhase.RACING,
            surface = track.surfaceAt(
                raceSession.player.state.x,
                raceSession.player.state.y,
            ),
        )
    }

    private fun renderWorld() {
        trackRenderer.render(worldViewport, worldCamera, track)
        raceSession.opponents.forEachIndexed { index, opponent ->
            opponentCarRenderer.render(
                worldCamera,
                opponent.state,
                raceSession.carConfig,
                AI_CAR_TINTS[index % AI_CAR_TINTS.size],
            )
        }
        playerCarRenderer.render(
            worldCamera,
            raceSession.player.state,
            raceSession.carConfig,
        )
        if (debugSettings.showCollisions) {
            collisionDebugRenderer.render(
                viewport = worldViewport,
                camera = worldCamera,
                shapes = shapes,
                track = track,
                cars = listOf(
                    DebugCar(
                        raceSession.player.state,
                        raceSession.carConfig.collisionRadius,
                    ),
                ) + raceSession.opponents.map {
                    DebugCar(it.state, raceSession.carConfig.collisionRadius)
                },
            )
        }
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

    private fun showResultsIfFinished(frameDelta: Float) {
        if (!lifecyclePaused && raceSession.raceState.phase == RacePhase.FINISHED) {
            if (!finishSoundPlayed) {
                finishSoundPlayed = true
                finishTransitionRemaining = FINISH_AUDIO_FADE_SECONDS
                latestInput = PlayerInput.NONE
                game.audio.finish()
                game.audio.beginRaceFadeOut()
            } else {
                finishTransitionRemaining -= frameDelta
            }
            if (finishTransitionRemaining > 0f) {
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
        raceSession = RaceSession(track).also(RaceSession::start)
        latestInput = PlayerInput.NONE
        lastCountdownNumber = -1
        finishSoundPlayed = false
        finishTransitionRemaining = 0f
        game.audio.resetRaceMix()
        game.audio.resumeRace()
        touchInput.reset()
        cameraController.snapTo(raceSession.player.state)
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
        playerCarRenderer.dispose()
        opponentCarRenderer.dispose()
        trackRenderer.dispose()
        super.dispose()
    }

    private companion object {
        const val CAMERA_VIEW_WIDTH = 24f
        const val CAMERA_VIEW_HEIGHT = CAMERA_VIEW_WIDTH * 9f / 16f
        const val MIN_SHAKE_IMPACT_SPEED = 3f
        const val SHAKE_PER_IMPACT_SPEED = 0.025f
        const val COUNTDOWN_START_NUMBER = 3
        const val FINISH_AUDIO_FADE_SECONDS = 0.8f
        val COUNTDOWN_ACTIVE = Color(0.95f, 0.28f, 0.18f, 1f)
        val COUNTDOWN_INACTIVE = Color(0.25f, 0.27f, 0.31f, 1f)
        val AI_CAR_TINTS = listOf(
            Color.WHITE,
            Color(0.72f, 0.90f, 1f, 1f),
            Color(1f, 0.72f, 0.82f, 1f),
        )
    }

    private enum class RaceUiAction {
        PAUSE,
        RESUME,
        RESTART,
        QUIT_TO_MENU,
    }
}
