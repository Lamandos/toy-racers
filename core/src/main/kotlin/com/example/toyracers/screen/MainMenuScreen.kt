package com.example.toyracers.screen

import com.badlogic.gdx.Gdx
import com.badlogic.gdx.Input
import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.utils.ScreenUtils
import com.example.toyracers.ToyRacersGame
import com.example.toyracers.ui.MainMenuStage

/** Scene2D main menu with explicit placeholders for post-MVP selections and settings. */
class MainMenuScreen(game: ToyRacersGame) : ToyRacersScreen(game) {
    private var playRequested = false
    private val menu = MainMenuStage { playRequested = true }

    override fun show() {
        super.show()
        Gdx.input.inputProcessor = menu.inputProcessor
    }

    override fun resize(width: Int, height: Int) {
        super.resize(width, height)
        menu.resize(width, height)
    }

    override fun render(delta: Float) {
        ScreenUtils.clear(BACKGROUND)
        menu.render(delta)

        if (!lifecyclePaused && (playRequested || startRequested())) {
            playRequested = false
            game.startRace()
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

    private companion object {
        val BACKGROUND = Color(0.07f, 0.12f, 0.18f, 1f)
    }
}
