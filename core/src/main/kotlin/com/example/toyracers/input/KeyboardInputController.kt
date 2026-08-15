package com.example.toyracers.input

import com.badlogic.gdx.Gdx
import com.badlogic.gdx.Input

/** Desktop/debug driving controls. */
class KeyboardInputController : InputController {
    override fun readInput(): PlayerInput {
        val throttle = if (pressed(Input.Keys.W, Input.Keys.UP)) 1f else 0f
        val brake = if (pressed(Input.Keys.S, Input.Keys.DOWN)) 1f else 0f
        val left = pressed(Input.Keys.A, Input.Keys.LEFT)
        val right = pressed(Input.Keys.D, Input.Keys.RIGHT)
        val steering =
            when {
                left == right -> 0f
                left -> -1f
                else -> 1f
            }
        return PlayerInput(throttle, brake, steering)
    }

    private fun pressed(
        primary: Int,
        secondary: Int,
    ): Boolean = Gdx.input.isKeyPressed(primary) || Gdx.input.isKeyPressed(secondary)
}
