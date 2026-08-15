package com.example.toyracers.screen

import com.badlogic.gdx.Gdx
import com.badlogic.gdx.Input
import com.badlogic.gdx.utils.ScreenUtils
import com.example.toyracers.ToyRacersGame
import com.example.toyracers.ui.MainMenuStage

/** Scene2D entry menu; Play continues to the dedicated track selection step. */
class MainMenuScreen(
    game: ToyRacersGame,
) : ToyRacersScreen(game) {
    private var playRequested = false
    private var settingsRequested = false
    private val menu =
        MainMenuStage(
            background = game.assets.mainMenuBackground,
            onPlay = { playRequested = true },
            onSettings = { settingsRequested = true },
            onButtonClick = game.audio::buttonClick,
        )

    override fun show() {
        super.show()
        Gdx.input.inputProcessor = menu.inputProcessor
    }

    override fun resize(
        width: Int,
        height: Int,
    ) {
        super.resize(width, height)
        menu.resize(width, height)
    }

    override fun render(delta: Float) {
        ScreenUtils.clear(0.02f, 0.03f, 0.04f, 1f)
        menu.render(delta)

        if (!lifecyclePaused && (playRequested || startRequested())) {
            playRequested = false
            game.showTrackSelection()
        } else if (!lifecyclePaused && settingsRequested) {
            settingsRequested = false
            game.showSettings()
        }
    }

    private fun startRequested(): Boolean =
        Gdx.input.isKeyJustPressed(Input.Keys.ENTER) ||
            Gdx.input.isKeyJustPressed(Input.Keys.SPACE)

    override fun hide() {
        if (Gdx.input.inputProcessor === menu.inputProcessor) {
            Gdx.input.inputProcessor = null
        }
    }

    override fun dispose() {
        menu.dispose()
        super.dispose()
    }
}
