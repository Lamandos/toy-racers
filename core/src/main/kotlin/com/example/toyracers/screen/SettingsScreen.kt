package com.example.toyracers.screen

import com.badlogic.gdx.Gdx
import com.badlogic.gdx.Input
import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.utils.ScreenUtils
import com.example.toyracers.ToyRacersGame
import com.example.toyracers.audio.AudioSettings
import com.example.toyracers.ui.AudioSettingsStage

/** Edits in-memory audio preferences; persistence is owned by the later save-system stage. */
class SettingsScreen(
    game: ToyRacersGame,
) : ToyRacersScreen(game) {
    private var backRequested = false
    private val settingsStage =
        AudioSettingsStage(
            initialSettings = game.audio.settings,
            onSettingsChanged = { game.audio.settings = it },
            onBack = { backRequested = true },
            onButtonClick = game.audio::buttonClick,
        )

    override fun show() {
        super.show()
        Gdx.input.inputProcessor = settingsStage.inputProcessor
    }

    override fun resize(
        width: Int,
        height: Int,
    ) {
        super.resize(width, height)
        settingsStage.resize(width, height)
    }

    override fun render(delta: Float) {
        ScreenUtils.clear(BACKGROUND)
        settingsStage.render(delta)
        if (!lifecyclePaused &&
            (backRequested || Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE))
        ) {
            game.showMainMenu()
        }
    }

    override fun hide() {
        if (Gdx.input.inputProcessor === settingsStage.inputProcessor) {
            Gdx.input.inputProcessor = null
        }
    }

    override fun dispose() {
        settingsStage.dispose()
        super.dispose()
    }

    private companion object {
        val BACKGROUND = Color(0.07f, 0.12f, 0.18f, 1f)
    }
}
