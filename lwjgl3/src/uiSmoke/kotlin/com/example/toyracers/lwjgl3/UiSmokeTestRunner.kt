package com.example.toyracers.lwjgl3

import com.badlogic.gdx.ApplicationAdapter
import com.badlogic.gdx.Gdx
import com.badlogic.gdx.Input
import com.badlogic.gdx.InputMultiplexer
import com.badlogic.gdx.backends.lwjgl3.Lwjgl3Application
import com.badlogic.gdx.backends.lwjgl3.Lwjgl3ApplicationConfiguration
import com.badlogic.gdx.math.Vector2
import com.badlogic.gdx.scenes.scene2d.Actor
import com.badlogic.gdx.scenes.scene2d.Stage
import com.example.toyracers.ToyRacersGame
import com.example.toyracers.car.CarModel
import com.example.toyracers.race.RaceResult
import com.example.toyracers.screen.CarSelectionScreen
import com.example.toyracers.screen.MainMenuScreen
import com.example.toyracers.screen.RaceScreen
import com.example.toyracers.screen.ResultsScreen
import com.example.toyracers.screen.TrackSelectionScreen
import kotlin.math.roundToInt

/** Runs the desktop presentation flow with real Scene2D input while keeping audio disabled. */
fun main() {
    val application = UiSmokeApplication()
    Lwjgl3Application(application, uiSmokeConfiguration())
    application.assertSucceeded()
    println("UI smoke flow passed.")
}

private fun uiSmokeConfiguration(): Lwjgl3ApplicationConfiguration =
    Lwjgl3ApplicationConfiguration().apply {
        setTitle("Toy Racers UI smoke")
        setWindowedMode(SMOKE_WINDOW_WIDTH, SMOKE_WINDOW_HEIGHT)
        useVsync(false)
        setForegroundFPS(120)
        setIdleFPS(120)
        setPauseWhenMinimized(false)
        setPauseWhenLostFocus(false)
        disableAudio(true)
    }

private class UiSmokeApplication : ApplicationAdapter() {
    private val game = ToyRacersGame()
    private val flow = UiSmokeFlow()
    private var failure: Throwable? = null

    override fun create() {
        game.create()
        game.resize(SMOKE_WINDOW_WIDTH, SMOKE_WINDOW_HEIGHT)
    }

    override fun resize(
        width: Int,
        height: Int,
    ) {
        game.resize(width, height)
    }

    override fun render() {
        runCatching {
            game.resize(SMOKE_WINDOW_WIDTH, SMOKE_WINDOW_HEIGHT)
            game.render()
            flow.advance(game)
        }.onFailure(::stopWithFailure)
    }

    override fun pause() {
        game.pause()
    }

    override fun resume() {
        game.resume()
    }

    override fun dispose() {
        game.dispose()
    }

    fun assertSucceeded() {
        failure?.let { throw IllegalStateException("UI smoke flow failed", it) }
        flow.assertCompleted()
    }

    private fun stopWithFailure(error: Throwable) {
        failure = error
        Gdx.app.exit()
    }
}

private class UiSmokeFlow {
    private var step = UiSmokeStep.WAIT_FOR_MAIN_MENU
    private var raceStartedAtNanos: Long? = null
    private val deadlineNanos = System.nanoTime() + TIMEOUT_NANOS

    fun advance(game: ToyRacersGame) {
        checkNotTimedOut(game)
        when (step) {
            UiSmokeStep.WAIT_FOR_MAIN_MENU -> openTrackSelection(game)
            UiSmokeStep.WAIT_FOR_TRACK_SELECTION -> selectTrack(game)
            UiSmokeStep.WAIT_FOR_CAR_SELECTION -> selectCarAndStartRace(game)
            UiSmokeStep.WAIT_FOR_RACE -> requestPauseWhenRacing(game)
            UiSmokeStep.WAIT_FOR_PAUSE_MENU -> resumeRace(game)
            UiSmokeStep.WAIT_FOR_RESUMED_RACE -> seedResults(game)
            UiSmokeStep.WAIT_FOR_RESULTS_RETRY -> retryRace(game)
            UiSmokeStep.WAIT_FOR_RETRIED_RACE -> seedResultsForMenu(game)
            UiSmokeStep.WAIT_FOR_RESULTS_MENU -> returnToMainMenu(game)
            UiSmokeStep.WAIT_FOR_RETURNED_MAIN_MENU -> completeWhenMainMenuIsShown(game)
            UiSmokeStep.COMPLETE -> Unit
        }
    }

    fun assertCompleted() {
        check(step == UiSmokeStep.COMPLETE) { "UI smoke flow stopped before completion at $step" }
    }

    private fun openTrackSelection(game: ToyRacersGame) {
        if (game.screen is TrackSelectionScreen) {
            step = UiSmokeStep.WAIT_FOR_TRACK_SELECTION
        } else if (game.screen is MainMenuScreen) {
            clickVisibleAction(MAIN_MENU_PLAY)
        }
    }

    private fun selectTrack(game: ToyRacersGame) {
        if (game.screen is CarSelectionScreen) {
            step = UiSmokeStep.WAIT_FOR_CAR_SELECTION
        } else if (game.screen is TrackSelectionScreen) {
            clickVisibleAction(BATHROOM_TRACK)
        } else if (game.screen is MainMenuScreen) {
            clickVisibleAction(MAIN_MENU_PLAY)
        }
    }

    private fun selectCarAndStartRace(game: ToyRacersGame) {
        if (game.screen is RaceScreen) {
            raceStartedAtNanos = System.nanoTime()
            step = UiSmokeStep.WAIT_FOR_RACE
        } else if (game.screen is CarSelectionScreen && game.selectedCar != CarModel.GREEN_RACER) {
            clickVisibleAction(GREEN_RACER_CAR)
        } else if (game.screen is CarSelectionScreen) {
            clickVisibleAction(START_RACE)
        } else if (game.screen is TrackSelectionScreen) {
            clickVisibleAction(BATHROOM_TRACK)
        }
    }

    private fun requestPauseWhenRacing(game: ToyRacersGame) {
        if (game.screen !is RaceScreen) return
        if (isVisibleAction(RESUME)) {
            step = UiSmokeStep.WAIT_FOR_PAUSE_MENU
            return
        }
        val startedAt = raceStartedAtNanos ?: System.nanoTime().also { raceStartedAtNanos = it }
        if (System.nanoTime() - startedAt >= COUNTDOWN_WAIT_NANOS) {
            clickVisibleAction(PAUSE)
        }
    }

    private fun resumeRace(game: ToyRacersGame) {
        if (game.screen is RaceScreen && isVisibleAction(PAUSE)) {
            step = UiSmokeStep.WAIT_FOR_RESUMED_RACE
        } else if (game.screen is RaceScreen) {
            clickVisibleAction(RESUME)
        }
    }

    private fun seedResults(game: ToyRacersGame) {
        if (game.screen is RaceScreen && isVisibleAction(PAUSE)) {
            game.showResults(SMOKE_RACE_RESULT)
            step = UiSmokeStep.WAIT_FOR_RESULTS_RETRY
        }
    }

    private fun retryRace(game: ToyRacersGame) {
        if (game.screen is RaceScreen) {
            step = UiSmokeStep.WAIT_FOR_RETRIED_RACE
        } else if (game.screen is ResultsScreen) {
            clickVisibleAction(RETRY)
        }
    }

    private fun seedResultsForMenu(game: ToyRacersGame) {
        if (game.screen is RaceScreen) {
            game.showResults(SMOKE_RACE_RESULT)
            step = UiSmokeStep.WAIT_FOR_RESULTS_MENU
        }
    }

    private fun returnToMainMenu(game: ToyRacersGame) {
        if (game.screen is MainMenuScreen) {
            step = UiSmokeStep.WAIT_FOR_RETURNED_MAIN_MENU
        } else if (game.screen is ResultsScreen) {
            clickVisibleAction(MAIN_MENU)
        }
    }

    private fun completeWhenMainMenuIsShown(game: ToyRacersGame) {
        if (game.screen is MainMenuScreen && isVisibleAction(MAIN_MENU_PLAY)) {
            step = UiSmokeStep.COMPLETE
            Gdx.app.exit()
        }
    }

    private fun checkNotTimedOut(game: ToyRacersGame) {
        check(System.nanoTime() < deadlineNanos) {
            "Timed out at $step while showing ${game.screen.javaClass.simpleName}"
        }
    }
}

private fun clickVisibleAction(actionName: String): Boolean {
    val target = findTapTarget(actionName) ?: return false
    val stagePosition =
        target.action
            .localToStageCoordinates(Vector2(target.action.width / 2f, target.action.height / 2f))
    if (!isHitTarget(target, stagePosition)) return false
    val screenPosition =
        stagePosition
            .let(target.stage::stageToScreenCoordinates)
    check(isHitTarget(target, target.stage.screenToStageCoordinates(screenPosition.cpy()))) {
        "Screen conversion missed $actionName at $screenPosition"
    }
    val touchDownHandled =
        target.stage.touchDown(
            screenPosition.x.roundToInt(),
            screenPosition.y.roundToInt(),
            0,
            Input.Buttons.LEFT,
        )
    val touchUpHandled =
        target.stage.touchUp(
            screenPosition.x.roundToInt(),
            screenPosition.y.roundToInt(),
            0,
            Input.Buttons.LEFT,
        )
    check(touchDownHandled && touchUpHandled) { "Scene2D did not handle action $actionName" }
    return true
}

private fun isVisibleAction(actionName: String): Boolean {
    val stage = activeStage() ?: return false
    val action = stage.root.findActor<Actor>(actionName) ?: return false
    return action.isVisible && action.ancestorsVisible()
}

private fun activeStage(): Stage? =
    when (val input = Gdx.input.inputProcessor) {
        is Stage -> input
        is InputMultiplexer -> input.processors.firstOrNull { it is Stage } as? Stage
        else -> null
    }

private fun findTapTarget(actionName: String): UiTapTarget? {
    val stage = activeStage() ?: return null
    val action = stage.root.findActor<Actor>(actionName) ?: return null
    return if (action.isVisible && action.ancestorsVisible() && action.width > 0f && action.height > 0f) {
        UiTapTarget(stage, action)
    } else {
        null
    }
}

private fun isHitTarget(
    target: UiTapTarget,
    stagePosition: Vector2,
): Boolean {
    val hit = target.stage.hit(stagePosition.x, stagePosition.y, true) ?: return false
    return hit === target.action || hit.isDescendantOf(target.action)
}

private data class UiTapTarget(
    val stage: Stage,
    val action: Actor,
)

private enum class UiSmokeStep {
    WAIT_FOR_MAIN_MENU,
    WAIT_FOR_TRACK_SELECTION,
    WAIT_FOR_CAR_SELECTION,
    WAIT_FOR_RACE,
    WAIT_FOR_PAUSE_MENU,
    WAIT_FOR_RESUMED_RACE,
    WAIT_FOR_RESULTS_RETRY,
    WAIT_FOR_RETRIED_RACE,
    WAIT_FOR_RESULTS_MENU,
    WAIT_FOR_RETURNED_MAIN_MENU,
    COMPLETE,
}

private const val MAIN_MENU_PLAY = "PLAY"
private const val BATHROOM_TRACK = "track-02"
private const val GREEN_RACER_CAR = "car-green-racer"
private const val START_RACE = "START RACE"
private const val PAUSE = "PAUSE"
private const val RESUME = "RESUME"
private const val RETRY = "RETRY"
private const val MAIN_MENU = "MAIN MENU"
private const val TIMEOUT_NANOS = 20_000_000_000L
private const val COUNTDOWN_WAIT_NANOS = 3_500_000_000L
private const val SMOKE_WINDOW_WIDTH = 1280
private const val SMOKE_WINDOW_HEIGHT = 720

private val SMOKE_RACE_RESULT =
    RaceResult(
        finishPosition = 1,
        competitorCount = 4,
        totalRaceTime = 84.321f,
        bestLapTime = 27.654f,
        isNewRecord = true,
    )
