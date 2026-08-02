package com.example.toyracers.input

import com.badlogic.gdx.InputProcessor
import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.g2d.Batch
import com.badlogic.gdx.graphics.g2d.TextureRegion
import com.badlogic.gdx.math.MathUtils
import com.badlogic.gdx.scenes.scene2d.Actor
import com.badlogic.gdx.scenes.scene2d.InputEvent
import com.badlogic.gdx.scenes.scene2d.InputListener
import com.badlogic.gdx.scenes.scene2d.Stage
import com.badlogic.gdx.utils.Disposable
import com.badlogic.gdx.utils.IntSet
import com.badlogic.gdx.utils.viewport.ExtendViewport
import com.example.toyracers.ToyRacersGame

/** Multi-touch dashboard controls using a viewport independent from the race world. */
class TouchInputController(
    steeringWheelTexture: TextureRegion,
    brakePedalTexture: TextureRegion,
    throttlePedalTexture: TextureRegion,
) : InputController, Disposable {
    private val viewport = ExtendViewport(
        ToyRacersGame.VIRTUAL_WIDTH,
        ToyRacersGame.VIRTUAL_HEIGHT,
    )
    private val stage = Stage(viewport)
    private val steeringWheel = SteeringWheel(steeringWheelTexture).apply {
        setSize(WHEEL_SIZE, WHEEL_SIZE)
    }
    private val brake = Pedal(brakePedalTexture).apply {
        setSize(BRAKE_WIDTH, BRAKE_HEIGHT)
    }
    private val throttle = Pedal(throttlePedalTexture).apply {
        setSize(THROTTLE_WIDTH, THROTTLE_HEIGHT)
    }

    val inputProcessor: InputProcessor get() = stage

    init {
        stage.addActor(steeringWheel)
        stage.addActor(brake)
        stage.addActor(throttle)
        layoutControls(ToyRacersGame.VIRTUAL_WIDTH)
    }

    override fun readInput() = PlayerInput(
        throttle = if (throttle.isPressed) 1f else 0f,
        brake = if (brake.isPressed) 1f else 0f,
        steering = steeringWheel.steering,
    )

    fun resize(width: Int, height: Int) {
        viewport.update(width, height, true)
        layoutControls(viewport.worldWidth)
    }

    private fun layoutControls(worldWidth: Float) {
        steeringWheel.setPosition(EDGE_PADDING, CONTROL_BOTTOM)
        throttle.setPosition(worldWidth - EDGE_PADDING - THROTTLE_WIDTH, CONTROL_BOTTOM)
        brake.setPosition(throttle.x - PEDAL_GAP - BRAKE_WIDTH, CONTROL_BOTTOM)
    }

    fun render(delta: Float) {
        stage.act(delta.coerceAtMost(MAX_UI_DELTA))
        stage.draw()
    }

    fun reset() {
        stage.cancelTouchFocus()
        steeringWheel.reset()
        brake.reset()
        throttle.reset()
    }

    override fun dispose() = stage.dispose()

    private class SteeringWheel(private val texture: TextureRegion) : Actor() {
        private var pointer = NO_POINTER
        var steering = 0f
            private set

        init {
            addListener(object : InputListener() {
                override fun touchDown(
                    event: InputEvent,
                    x: Float,
                    y: Float,
                    pointer: Int,
                    button: Int,
                ): Boolean {
                    if (this@SteeringWheel.pointer != NO_POINTER) return false
                    this@SteeringWheel.pointer = pointer
                    updateSteering(x)
                    return true
                }

                override fun touchDragged(event: InputEvent, x: Float, y: Float, pointer: Int) {
                    if (this@SteeringWheel.pointer == pointer) updateSteering(x)
                }

                override fun touchUp(
                    event: InputEvent,
                    x: Float,
                    y: Float,
                    pointer: Int,
                    button: Int,
                ) {
                    if (this@SteeringWheel.pointer == pointer) reset()
                }
            })
        }

        private fun updateSteering(localX: Float) {
            steering = steeringFromWheelTouch(localX, width)
        }

        override fun draw(batch: Batch, parentAlpha: Float) {
            batch.color = Color(1f, 1f, 1f, parentAlpha)
            batch.draw(
                texture,
                x,
                y,
                width / 2f,
                height / 2f,
                width,
                height,
                1f,
                1f,
                steering * -MAX_WHEEL_ROTATION,
            )
            batch.color = Color.WHITE
        }

        fun reset() {
            pointer = NO_POINTER
            steering = 0f
        }
    }

    private class Pedal(private val texture: TextureRegion) : Actor() {
        private val activePointers = IntSet()
        val isPressed: Boolean get() = activePointers.notEmpty()

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
            val travel = if (isPressed) PEDAL_TRAVEL else 0f
            batch.color = if (isPressed) PRESSED_TINT else Color(1f, 1f, 1f, parentAlpha)
            batch.draw(texture, x, y - travel, width, height)
            batch.color = Color.WHITE
        }

        fun reset() = activePointers.clear()
    }

    private companion object {
        const val NO_POINTER = -1
        const val MAX_UI_DELTA = 0.1f
        const val MAX_WHEEL_ROTATION = 70f
        const val PEDAL_TRAVEL = 12f
        const val WHEEL_SIZE = 285f
        const val BRAKE_WIDTH = 145f
        const val BRAKE_HEIGHT = 205f
        const val THROTTLE_WIDTH = 108f
        const val THROTTLE_HEIGHT = 230f
        const val EDGE_PADDING = 72f
        const val CONTROL_BOTTOM = 25f
        const val PEDAL_GAP = 26f
        val PRESSED_TINT = Color(1f, 0.72f, 0.55f, 1f)
    }
}

internal fun steeringFromWheelTouch(localX: Float, wheelWidth: Float): Float {
    if (wheelWidth <= 0f) return 0f
    return MathUtils.clamp((localX - wheelWidth / 2f) / (wheelWidth / 2f), -1f, 1f)
}
