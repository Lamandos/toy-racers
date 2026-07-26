package com.example.toyracers.render

import com.example.toyracers.car.CarConfig
import com.example.toyracers.car.CarState
import org.junit.Assert.assertEquals
import org.junit.Test

class CarRendererTest {
    @Test
    fun `render bounds use the same world units as car state and config`() {
        val state = CarState(x = 20f, y = 10f)
        val config = CarConfig(width = 2f, length = 4f)

        val bounds = calculateCarRenderBounds(state, config)

        assertEquals(19f, bounds.x, EPSILON)
        assertEquals(8f, bounds.y, EPSILON)
        assertEquals(2f, bounds.width, EPSILON)
        assertEquals(4f, bounds.length, EPSILON)
    }

    private companion object {
        const val EPSILON = 0.0001f
    }
}
