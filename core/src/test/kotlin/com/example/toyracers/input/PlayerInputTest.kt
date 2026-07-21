package com.example.toyracers.input

import org.junit.Assert.assertEquals
import org.junit.Test

class PlayerInputTest {
    @Test
    fun `normalization clamps every control to its public range`() {
        val input = PlayerInput(throttle = 2f, brake = -1f, steering = -3f).normalized()

        assertEquals(PlayerInput(throttle = 1f, brake = 0f, steering = -1f), input)
    }

    @Test
    fun `keyboard and touch commands combine into one player input`() {
        val keyboard = PlayerInput(throttle = 1f, steering = -1f)
        val touch = PlayerInput(brake = 1f, steering = 1f)

        assertEquals(
            PlayerInput(throttle = 1f, brake = 1f, steering = 0f),
            keyboard.combinedWith(touch),
        )
    }
}
