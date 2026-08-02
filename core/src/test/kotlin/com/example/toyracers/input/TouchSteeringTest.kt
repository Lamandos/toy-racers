package com.example.toyracers.input

import org.junit.Assert.assertEquals
import org.junit.Test

class TouchSteeringTest {
    @Test
    fun `wheel touch maps center and edges to steering range`() {
        assertEquals(-1f, steeringFromWheelTouch(0f, 300f), 0.001f)
        assertEquals(0f, steeringFromWheelTouch(150f, 300f), 0.001f)
        assertEquals(1f, steeringFromWheelTouch(300f, 300f), 0.001f)
    }

    @Test
    fun `wheel steering clamps drags beyond its bounds`() {
        assertEquals(-1f, steeringFromWheelTouch(-80f, 300f), 0.001f)
        assertEquals(1f, steeringFromWheelTouch(420f, 300f), 0.001f)
    }
}
