package com.example.toyracers.screen

import com.badlogic.gdx.Gdx
import com.badlogic.gdx.Input
import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.utils.ScreenUtils
import com.example.toyracers.ToyRacersGame
import com.example.toyracers.race.RaceResult
import com.example.toyracers.ui.ResultsStage

/** Displays the completed race summary and navigation actions. */
class ResultsScreen(
    game: ToyRacersGame,
    result: RaceResult,
) : ToyRacersScreen(game) {
    private var retryRequested = false
    private var mainMenuRequested = false
    private val results = ResultsStage(
        result = result,
        onRetry = { retryRequested = true },
        onMainMenu = { mainMenuRequested = true },
        onButtonClick = game.audio::buttonClick,
    )

    override fun show() {
        super.show()
        Gdx.input.inputProcessor = results.inputProcessor
    }

    override fun resize(width: Int, height: Int) {
        super.resize(width, height)
        results.resize(width, height)
    }

    override fun render(delta: Float) {
        ScreenUtils.clear(BACKGROUND)
        results.render(delta)

        if (lifecyclePaused) return

        when {
            mainMenuRequested || Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE) ->
                game.showMainMenu()
            retryRequested || retryKeyPressed() -> game.startRace()
        }
    }

    private fun retryKeyPressed(): Boolean =
        Gdx.input.isKeyJustPressed(Input.Keys.R) ||
            Gdx.input.isKeyJustPressed(Input.Keys.ENTER) ||
            Gdx.input.isKeyJustPressed(Input.Keys.SPACE)

    override fun hide() {
        if (Gdx.input.inputProcessor === results.inputProcessor) {
            Gdx.input.inputProcessor = null
        }
    }

    override fun dispose() {
        results.dispose()
        super.dispose()
    }

    private companion object {
        val BACKGROUND = Color(0.08f, 0.10f, 0.16f, 1f)
    }
}
