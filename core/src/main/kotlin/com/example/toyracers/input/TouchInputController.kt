package com.example.toyracers.input

import com.badlogic.gdx.InputProcessor
import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.Pixmap
import com.badlogic.gdx.graphics.Texture
import com.badlogic.gdx.graphics.g2d.Batch
import com.badlogic.gdx.scenes.scene2d.Actor
import com.badlogic.gdx.scenes.scene2d.InputEvent
import com.badlogic.gdx.scenes.scene2d.InputListener
import com.badlogic.gdx.scenes.scene2d.Stage
import com.badlogic.gdx.utils.Disposable
import com.badlogic.gdx.utils.IntSet
import com.badlogic.gdx.utils.viewport.FitViewport
import com.example.toyracers.ToyRacersGame

/** Multi-touch Scene2D controls using a viewport independent from the race world. */
class TouchInputController : InputController, Disposable {
    private val viewport = FitViewport(ToyRacersGame.VIRTUAL_WIDTH, ToyRacersGame.VIRTUAL_HEIGHT)
    private val stage = Stage(viewport)
    private val whiteTexture = createWhiteTexture()

    private val steerLeft = ControlButton(whiteTexture, STEERING_COLOR, Symbol.LEFT).apply {
        setBounds(60f, 55f, 175f, 155f)
    }
    private val steerRight = ControlButton(whiteTexture, STEERING_COLOR, Symbol.RIGHT).apply {
        setBounds(270f, 55f, 175f, 155f)
    }
    private val brake = ControlButton(whiteTexture, BRAKE_COLOR, Symbol.BRAKE).apply {
        setBounds(850f, 55f, 155f, 155f)
    }
    private val throttle = ControlButton(whiteTexture, THROTTLE_COLOR, Symbol.THROTTLE).apply {
        setBounds(1040f, 55f, 180f, 210f)
    }

    val inputProcessor: InputProcessor
        get() = stage

    init {
        stage.addActor(steerLeft)
        stage.addActor(steerRight)
        stage.addActor(brake)
        stage.addActor(throttle)
    }

    override fun readInput(): PlayerInput {
        val steering = when {
            steerLeft.isPressed == steerRight.isPressed -> 0f
            steerLeft.isPressed -> -1f
            else -> 1f
        }
        return PlayerInput(
            throttle = if (throttle.isPressed) 1f else 0f,
            brake = if (brake.isPressed) 1f else 0f,
            steering = steering,
        )
    }

    fun resize(width: Int, height: Int) {
        viewport.update(width, height, true)
    }

    fun render(delta: Float) {
        stage.act(delta.coerceAtMost(MAX_UI_DELTA))
        stage.draw()
    }

    fun reset() {
        stage.cancelTouchFocus()
        steerLeft.reset()
        steerRight.reset()
        brake.reset()
        throttle.reset()
    }

    override fun dispose() {
        stage.dispose()
        whiteTexture.dispose()
    }

    private class ControlButton(
        private val texture: Texture,
        private val idleColor: Color,
        private val symbol: Symbol,
    ) : Actor() {
        private val activePointers = IntSet()

        val isPressed: Boolean
            get() = activePointers.notEmpty()

        init {
            addListener(object : InputListener() {
                override fun touchDown(
                    event: InputEvent,
                    x: Float,
                    y: Float,
                    pointer: Int,
                    button: Int,
                ): Boolean {
                    activePointers.add(pointer)
                    return true
                }

                override fun touchUp(
                    event: InputEvent,
                    x: Float,
                    y: Float,
                    pointer: Int,
                    button: Int,
                ) {
                    activePointers.remove(pointer)
                }
            })
        }

        override fun draw(batch: Batch, parentAlpha: Float) {
            batch.color = if (isPressed) PRESSED_COLOR else idleColor
            batch.draw(texture, x, y, width, height)
            batch.color = SYMBOL_COLOR
            drawSymbol(batch)
            batch.color = Color.WHITE
        }

        private fun drawSymbol(batch: Batch) {
            val centerX = x + width / 2f
            val centerY = y + height / 2f
            when (symbol) {
                Symbol.LEFT -> {
                    batch.draw(texture, centerX - 42f, centerY - 8f, 82f, 16f)
                    drawRotated(batch, centerX - 42f, centerY + 17f, 55f, 14f, 45f)
                    drawRotated(batch, centerX - 42f, centerY - 31f, 55f, 14f, -45f)
                }
                Symbol.RIGHT -> {
                    batch.draw(texture, centerX - 40f, centerY - 8f, 82f, 16f)
                    drawRotated(batch, centerX + 3f, centerY + 17f, 55f, 14f, -45f)
                    drawRotated(batch, centerX + 3f, centerY - 31f, 55f, 14f, 45f)
                }
                Symbol.BRAKE -> {
                    batch.draw(texture, centerX - 48f, centerY - 25f, 96f, 16f)
                    batch.draw(texture, centerX - 48f, centerY + 9f, 96f, 16f)
                }
                Symbol.THROTTLE -> {
                    batch.draw(texture, centerX - 8f, centerY - 48f, 16f, 90f)
                    drawRotated(batch, centerX - 39f, centerY + 19f, 55f, 14f, 45f)
                    drawRotated(batch, centerX - 8f, centerY + 19f, 55f, 14f, -45f)
                }
            }
        }

        private fun drawRotated(
            batch: Batch,
            drawX: Float,
            drawY: Float,
            drawWidth: Float,
            drawHeight: Float,
            rotation: Float,
        ) {
            batch.draw(
                texture,
                drawX,
                drawY,
                0f,
                drawHeight / 2f,
                drawWidth,
                drawHeight,
                1f,
                1f,
                rotation,
                0,
                0,
                1,
                1,
                false,
                false,
            )
        }

        fun reset() {
            activePointers.clear()
        }
    }

    private enum class Symbol {
        LEFT,
        RIGHT,
        BRAKE,
        THROTTLE,
    }

    private companion object {
        val STEERING_COLOR = Color(0.15f, 0.45f, 0.92f, 0.68f)
        val BRAKE_COLOR = Color(0.88f, 0.18f, 0.16f, 0.68f)
        val THROTTLE_COLOR = Color(0.12f, 0.72f, 0.32f, 0.68f)
        val PRESSED_COLOR = Color(0.98f, 0.82f, 0.24f, 0.88f)
        val SYMBOL_COLOR = Color(1f, 1f, 1f, 0.9f)
        const val MAX_UI_DELTA = 0.1f

        fun createWhiteTexture(): Texture {
            val pixmap = Pixmap(1, 1, Pixmap.Format.RGBA8888)
            pixmap.setColor(Color.WHITE)
            pixmap.fill()
            return Texture(pixmap).also { pixmap.dispose() }
        }
    }
}
