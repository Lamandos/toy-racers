package com.example.toyracers.ui

import com.badlogic.gdx.InputProcessor
import com.badlogic.gdx.scenes.scene2d.InputEvent
import com.badlogic.gdx.scenes.scene2d.Stage
import com.badlogic.gdx.scenes.scene2d.ui.Label
import com.badlogic.gdx.scenes.scene2d.ui.Table
import com.badlogic.gdx.scenes.scene2d.ui.TextButton
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener
import com.badlogic.gdx.utils.Disposable
import com.badlogic.gdx.utils.viewport.ExtendViewport
import com.example.toyracers.ToyRacersGame
import com.example.toyracers.race.RaceResult

class ResultsStage(
    result: RaceResult,
    onRetry: () -> Unit,
    onMainMenu: () -> Unit,
    private val onButtonClick: () -> Unit = {},
) : Disposable {
    private val skin = createGameUiSkin()
    private val stage = Stage(
        ExtendViewport(ToyRacersGame.VIRTUAL_WIDTH, ToyRacersGame.VIRTUAL_HEIGHT),
    )

    val inputProcessor: InputProcessor
        get() = stage

    init {
        val results = Table().apply {
            setFillParent(true)
            background = this@ResultsStage.skin.panelDrawable()
            pad(34f)
            add(label("RACE FINISHED", 2.4f)).width(470f).height(80f)
            row()
            add(label("POSITION ${result.finishPosition}/${result.competitorCount}", 1.7f))
                .width(470f).height(58f)
            row()
            add(label("TOTAL ${formatRaceTime(result.totalRaceTime)}", 1.5f))
                .width(470f).height(52f)
            row()
            add(
                label(
                    "BEST LAP ${result.bestLapTime?.let(::formatRaceTime) ?: "--:--.---"}",
                    1.5f,
                ),
            ).width(470f).height(52f)
            if (result.isNewRecord) {
                row()
                add(label("NEW RECORD!", 1.7f)).width(470f).height(58f)
            }
            row()
            add(button("RETRY", onRetry)).width(360f).height(72f).pad(8f)
            row()
            add(button("NEXT TRACK (SOON)") {}).width(360f).height(72f).pad(8f)
            row()
            add(button("MAIN MENU", onMainMenu)).width(360f).height(72f).pad(8f)
        }
        stage.addActor(results)
    }

    fun resize(
        width: Int,
        height: Int,
    ) {
        stage.viewport.update(width, height, true)
    }

    fun render(delta: Float) {
        stage.act(delta.coerceAtMost(MAX_UI_DELTA))
        stage.draw()
    }

    private fun label(
        text: String,
        scale: Float,
    ): Label = Label(text, skin).apply { setFontScale(scale) }

    private fun button(
        text: String,
        action: () -> Unit,
    ): TextButton = TextButton(text, skin).apply {
        addListener(object : ClickListener() {
            override fun clicked(
                event: InputEvent,
                x: Float,
                y: Float,
            ) {
                onButtonClick()
                action()
            }
        })
    }

    override fun dispose() {
        stage.dispose()
        skin.dispose()
    }

    private companion object {
        const val MAX_UI_DELTA = 0.1f
    }
}
