package com.example.toyracers.input

import org.junit.Assert.assertEquals
import org.junit.Test

class PlayerControlConfigTest {
    @Test
    fun `applies steering sensitivity without changing pedals`() {
        val input = PlayerInput(throttle = 0.7f, brake = 0.2f, steering = -1f)

        val adjusted = PlayerControlConfig(steeringSensitivity = 0.85f).applyTo(input)

        assertEquals(-0.85f, adjusted.steering, 0.0001f)
        assertEquals(input.throttle, adjusted.throttle, 0.0001f)
        assertEquals(input.brake, adjusted.brake, 0.0001f)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `rejects sensitivity outside normalized range`() {
        PlayerControlConfig(steeringSensitivity = 1.01f)
    }
}
