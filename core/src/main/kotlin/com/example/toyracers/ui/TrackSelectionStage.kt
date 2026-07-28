package com.example.toyracers.ui

import com.badlogic.gdx.InputProcessor
import com.badlogic.gdx.graphics.Texture
import com.badlogic.gdx.scenes.scene2d.InputEvent
import com.badlogic.gdx.scenes.scene2d.Stage
import com.badlogic.gdx.scenes.scene2d.ui.Image
import com.badlogic.gdx.scenes.scene2d.ui.Label
import com.badlogic.gdx.scenes.scene2d.ui.Table
import com.badlogic.gdx.scenes.scene2d.ui.TextButton
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener
import com.badlogic.gdx.utils.Disposable
import com.badlogic.gdx.utils.Scaling
import com.badlogic.gdx.utils.viewport.FitViewport
import com.example.toyracers.ToyRacersGame
import com.example.toyracers.track.TrackId

/** Presents visual track cards immediately after the player presses Play. */
class TrackSelectionStage(
    options: List<TrackSelectionOption>,
    private val onTrackSelected: (TrackId) -> Unit,
    onBack: () -> Unit,
    private val onButtonClick: () -> Unit = {},
) : Disposable {
    init {
        require(options.isNotEmpty()) { "Track selection requires at least one option" }
    }

    private val skin = createGameUiSkin()
    private val stage = Stage(
        FitViewport(ToyRacersGame.VIRTUAL_WIDTH, ToyRacersGame.VIRTUAL_HEIGHT),
    )

    val inputProcessor: InputProcessor
        get() = stage

    init {
        val cardWidth = minOf(MAX_CARD_WIDTH, CARD_ROW_WIDTH / options.size)
        val content = Table().apply {
            setFillParent(true)
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
        addListener(object : ClickListener() {
            override fun clicked(event: InputEvent, x: Float, y: Float) {
                onButtonClick()
                onTrackSelected(option.trackId)
            }
        })
    }

    private fun button(
        text: String,
        action: () -> Unit,
    ): TextButton = TextButton(text, skin).apply {
        addListener(object : ClickListener() {
            override fun clicked(event: InputEvent, x: Float, y: Float) {
                onButtonClick()
                action()
            }
        })
    }

    fun resize(width: Int, height: Int) {
        stage.viewport.update(width, height, true)
    }

    fun render(delta: Float) {
        stage.act(delta.coerceAtMost(MAX_UI_DELTA))
        stage.draw()
    }

    override fun dispose() {
        stage.dispose()
        skin.dispose()
    }

    private companion object {
        const val MAX_UI_DELTA = 0.1f
        const val MAX_CARD_WIDTH = 480f
        const val CARD_ROW_WIDTH = 1040f
    }
}

data class TrackSelectionOption(
    val trackId: TrackId,
    val preview: Texture,
)
