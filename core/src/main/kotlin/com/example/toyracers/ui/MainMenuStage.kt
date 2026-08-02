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
import com.badlogic.gdx.utils.viewport.ExtendViewport
import com.example.toyracers.ToyRacersGame

class MainMenuStage(
    background: Texture,
    onPlay: () -> Unit,
    onSettings: () -> Unit = {},
    private val onButtonClick: () -> Unit = {},
) : Disposable {
    private val skin = createGameUiSkin()
    private val stage = Stage(
        ExtendViewport(ToyRacersGame.VIRTUAL_WIDTH, ToyRacersGame.VIRTUAL_HEIGHT),
    )

    val inputProcessor: InputProcessor
        get() = stage

    init {
        stage.addActor(Image(background).apply {
            setFillParent(true)
            setScaling(Scaling.fill)
        })
        val menu = Table().apply {
            setFillParent(true)
            left().padLeft(92f)
            val panel = Table().apply {
                this.background = this@MainMenuStage.skin.panelDrawable()
                pad(34f)
            }
            val title = Label("TOY RACERS", this@MainMenuStage.skin).apply {
                setFontScale(3f)
            }
            panel.add(title).width(430f).height(110f)
            panel.row()
            panel.add(button("PLAY", action = onPlay)).width(360f).height(80f).pad(10f)
            panel.row()
            panel.add(button("SETTINGS", SECONDARY_BUTTON_STYLE, onSettings))
                .width(360f).height(72f).pad(8f)
            add(panel).width(500f)
        }
        stage.addActor(menu)
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

    private fun button(
        text: String,
        style: String = "default",
        action: () -> Unit,
    ): TextButton = TextButton(text, skin, style).apply {
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
