package com.example.toyracers.screen

import com.badlogic.gdx.Gdx
import com.badlogic.gdx.Input
import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.utils.ScreenUtils
import com.example.toyracers.ToyRacersGame
import com.example.toyracers.car.CarModel
import com.example.toyracers.track.TrackId
import com.example.toyracers.ui.CarSelectionOption
import com.example.toyracers.ui.CarSelectionStage

/** Final Play-flow step: select a car for the chosen track and start the race. */
class CarSelectionScreen(
    game: ToyRacersGame,
    private val trackId: TrackId,
) : ToyRacersScreen(game) {
    private var backRequested = false
    private var startRequested = false
    private val selection = CarSelectionStage(
        options = CarModel.entries.map { CarSelectionOption(it, game.assets.car(it)) },
        initiallySelected = game.selectedCar,
        initiallySelectedDifficulty = game.selectedAiDifficulty,
        onCarSelected = game::selectCar,
        onDifficultySelected = game::selectAiDifficulty,
        onStartRace = { startRequested = true },
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
        if (!lifecyclePaused && startRequested) {
            startRequested = false
            game.startRace(trackId)
            return
        }
        if (!lifecyclePaused && (backRequested || Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE))) {
            game.showTrackSelection()
        }
    }

    override fun hide() {
        if (Gdx.input.inputProcessor === selection.inputProcessor) Gdx.input.inputProcessor = null
    }

    override fun dispose() {
        selection.dispose()
        super.dispose()
    }

    private companion object {
        val BACKGROUND = Color(0.07f, 0.12f, 0.18f, 1f)
    }
}
