package com.example.toyracers.screen

import com.badlogic.gdx.Gdx
import com.badlogic.gdx.Input
import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.utils.ScreenUtils
import com.example.toyracers.ToyRacersGame
import com.example.toyracers.track.TrackId
import com.example.toyracers.ui.TrackSelectionOption
import com.example.toyracers.ui.TrackSelectionStage

/** Track selection shown as the second step of the Play flow. */
class TrackSelectionScreen(game: ToyRacersGame) : ToyRacersScreen(game) {
    private var selectedTrack: TrackId? = null
    private var backRequested = false
    private val selection = TrackSelectionStage(
        options = TrackId.entries.map { trackId ->
            TrackSelectionOption(trackId, game.assets.track(trackId))
        },
        onTrackSelected = { selectedTrack = it },
        onBack = { backRequested = true },
        onButtonClick = game.audio::buttonClick,
    )

    override fun show() {
        super.show()
        Gdx.input.inputProcessor = selection.inputProcessor
    }

    override fun resize(width: Int, height: Int) {
        super.resize(width, height)
        selection.resize(width, height)
    }

    override fun render(delta: Float) {
        ScreenUtils.clear(BACKGROUND)
        selection.render(delta)
        selectedTrack?.let {
            selectedTrack = null
            game.startRace(it)
            return
        }
        if (!lifecyclePaused &&
            (backRequested || Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE))
        ) {
            game.showMainMenu()
        }
    }

    override fun hide() {
        if (Gdx.input.inputProcessor === selection.inputProcessor) {
            Gdx.input.inputProcessor = null
        }
    }

    override fun dispose() {
        selection.dispose()
        super.dispose()
    }

    private companion object {
        val BACKGROUND = Color(0.07f, 0.12f, 0.18f, 1f)
    }
}
