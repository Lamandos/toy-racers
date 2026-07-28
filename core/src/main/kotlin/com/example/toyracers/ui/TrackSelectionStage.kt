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
    track01: Texture,
    track02: Texture,
    private val onTrackSelected: (TrackId) -> Unit,
    onBack: () -> Unit,
    private val onButtonClick: () -> Unit = {},
) : Disposable {
    private val skin = createGameUiSkin()
    private val stage = Stage(
        FitViewport(ToyRacersGame.VIRTUAL_WIDTH, ToyRacersGame.VIRTUAL_HEIGHT),
    )

    val inputProcessor: InputProcessor
        get() = stage

    init {
        val content = Table().apply {
            setFillParent(true)
            add(Label("SELECT TRACK", this@TrackSelectionStage.skin).apply {
                setFontScale(2.2f)
            }).colspan(2).height(100f)
            row()
            add(trackCard(track01, TrackId.LIVING_ROOM)).width(480f).height(390f).pad(20f)
            add(trackCard(track02, TrackId.BATHROOM)).width(480f).height(390f).pad(20f)
            row()
            add(button("BACK", onBack)).colspan(2).width(300f).height(68f).padTop(14f)
        }
        stage.addActor(content)
    }

    private fun trackCard(
        texture: Texture,
        trackId: TrackId,
    ): TextButton = TextButton("", skin).apply {
        clearChildren()
        add(Image(texture).apply {
            setScaling(Scaling.fit)
        }).grow().pad(12f)
        row()
        add(Label(trackId.displayName, skin).apply {
            setFontScale(1.45f)
        }).height(62f)
        addListener(object : ClickListener() {
            override fun clicked(event: InputEvent, x: Float, y: Float) {
                onButtonClick()
                onTrackSelected(trackId)
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
    }
}
