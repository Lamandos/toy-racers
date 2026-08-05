package com.example.toyracers.ui

import com.badlogic.gdx.graphics.Texture
import com.badlogic.gdx.scenes.scene2d.ui.Image
import com.badlogic.gdx.scenes.scene2d.ui.Label
import com.badlogic.gdx.scenes.scene2d.ui.Table
import com.badlogic.gdx.scenes.scene2d.ui.TextButton
import com.badlogic.gdx.utils.Scaling
import com.example.toyracers.track.TrackId

/** Presents visual track cards immediately after the player presses Play. */
class TrackSelectionStage(
    options: List<TrackSelectionOption>,
    private val onTrackSelected: (TrackId) -> Unit,
    onBack: () -> Unit,
    onButtonClick: () -> Unit = {},
) : GameUiStage(onButtonClick) {
    init {
        require(options.isNotEmpty()) { "Track selection requires at least one option" }
    }

    init {
        val cardWidth = minOf(MAX_CARD_WIDTH, CARD_ROW_WIDTH / options.size)
        val content = Table().apply {
            setFillParent(true)
            background = this@TrackSelectionStage.skin.panelDrawable()
            pad(28f)
            add(Label("SELECT TRACK", this@TrackSelectionStage.skin).apply {
                setFontScale(2.2f)
            }).colspan(options.size).height(100f)
            row()
            options.forEach { option ->
                add(trackCard(option)).width(cardWidth).height(390f).pad(20f)
            }
            row()
            add(button("BACK", onBack))
                .colspan(options.size)
                .width(300f)
                .height(68f)
                .padTop(14f)
        }
        stage.addActor(content)
    }

    private fun trackCard(
        option: TrackSelectionOption,
    ): TextButton = TextButton("", skin).apply {
        clearChildren()
        add(Image(option.preview).apply {
            setScaling(Scaling.fit)
        }).grow().pad(12f)
        row()
        add(Label(option.trackId.displayName, skin).apply {
            setFontScale(1.45f)
        }).height(62f)
        onClick { onTrackSelected(option.trackId) }
    }

    private companion object {
        const val MAX_CARD_WIDTH = 480f
        const val CARD_ROW_WIDTH = 1040f
    }
}

data class TrackSelectionOption(
    val trackId: TrackId,
    val preview: Texture,
)
