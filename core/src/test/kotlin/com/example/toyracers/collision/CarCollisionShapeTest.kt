package com.example.toyracers.collision

import com.example.toyracers.car.CarState
import org.junit.Assert.assertEquals
import org.junit.Test

class CarCollisionShapeTest {
    @Test
    fun `capsule circle centers follow car position and rotation`() {
        val state = CarState(x = 10f, y = 20f, rotationDeg = 90f)

        val circles = carCollisionCircles(state, radius = 0.8f, longitudinalOffset = 1f)

        assertEquals(3, circles.size)
        assertEquals(19f, circles[0].y, TOLERANCE)
        assertEquals(20f, circles[1].y, TOLERANCE)
        assertEquals(21f, circles[2].y, TOLERANCE)
        circles.forEach { circle ->
            assertEquals(10f, circle.x, TOLERANCE)
            assertEquals(0.8f, circle.radius, TOLERANCE)
        }
    }

    private companion object {
        const val TOLERANCE = 0.0001f
    }
}
