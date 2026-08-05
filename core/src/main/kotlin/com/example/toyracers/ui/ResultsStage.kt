package com.example.toyracers.ui

import com.badlogic.gdx.scenes.scene2d.ui.Label
import com.badlogic.gdx.scenes.scene2d.ui.Table
import com.example.toyracers.race.RaceResult

class ResultsStage(
    result: RaceResult,
    onRetry: () -> Unit,
    onMainMenu: () -> Unit,
    onButtonClick: () -> Unit = {},
) : GameUiStage(onButtonClick) {

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
            add(button("MAIN MENU", onMainMenu)).width(360f).height(72f).pad(8f)
        }
        stage.addActor(results)
    }

    private fun label(
        text: String,
        scale: Float,
    ): Label = Label(text, skin).apply { setFontScale(scale) }

}
