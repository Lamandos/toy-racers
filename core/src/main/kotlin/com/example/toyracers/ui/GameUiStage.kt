package com.example.toyracers.ui

import com.badlogic.gdx.InputProcessor
import com.badlogic.gdx.scenes.scene2d.InputEvent
import com.badlogic.gdx.scenes.scene2d.Stage
import com.badlogic.gdx.scenes.scene2d.ui.TextButton
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener
import com.badlogic.gdx.utils.Disposable
import com.badlogic.gdx.utils.viewport.ExtendViewport
import com.example.toyracers.ToyRacersGame

/** Shared Scene2D ownership and interaction behavior for the game's UI stages. */
abstract class GameUiStage(
    private val onButtonClick: () -> Unit = {},
) : Disposable {
    protected val skin = createGameUiSkin()
    protected val stage =
        Stage(
            ExtendViewport(ToyRacersGame.VIRTUAL_WIDTH, ToyRacersGame.VIRTUAL_HEIGHT),
        )

    val inputProcessor: InputProcessor
        get() = stage

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

    protected fun button(
        text: String,
        style: String = "default",
        action: () -> Unit,
    ): TextButton =
        TextButton(text, skin, style).apply {
            name = text
            addListener(
                object : ClickListener() {
                    override fun clicked(
                        event: InputEvent,
                        x: Float,
                        y: Float,
                    ) {
                        onButtonClick()
                        action()
                    }
                },
            )
        }

    protected fun button(
        text: String,
        action: () -> Unit,
    ): TextButton = button(text, "default", action)

    protected fun TextButton.onClick(action: () -> Unit) {
        addListener(
            object : ClickListener() {
                override fun clicked(
                    event: InputEvent,
                    x: Float,
                    y: Float,
                ) {
                    onButtonClick()
                    action()
                }
            },
        )
    }

    override fun dispose() {
        stage.dispose()
        skin.dispose()
    }

    private companion object {
        const val MAX_UI_DELTA = 0.1f
    }
}
