package com.example.toyracers.car

import org.junit.Assert.assertEquals
import org.junit.Test

class CarStateInterpolationTest {
    @Test
    fun `interpolates position speed and velocity without mutating either simulation state`() {
        val previous = CarState(x = 2f, y = 4f, speed = 8f, velocityX = 6f, velocityY = -2f)
        val current = CarState(x = 10f, y = 20f, speed = 16f, velocityX = 14f, velocityY = 2f)

        val rendered = interpolateCarState(previous, current, alpha = 0.25f)

        assertEquals(4f, rendered.x, EPSILON)
        assertEquals(8f, rendered.y, EPSILON)
        assertEquals(10f, rendered.speed, EPSILON)
        assertEquals(8f, rendered.velocityX, EPSILON)
        assertEquals(-1f, rendered.velocityY, EPSILON)
        assertEquals(CarState(x = 2f, y = 4f, speed = 8f, velocityX = 6f, velocityY = -2f), previous)
        assertEquals(CarState(x = 10f, y = 20f, speed = 16f, velocityX = 14f, velocityY = 2f), current)
    }

    @Test
    fun `interpolates rotation over the shortest arc across zero degrees`() {
        assertEquals(0f, interpolateRotationDegrees(359f, 1f, 0.5f), EPSILON)
        assertEquals(0f, interpolateRotationDegrees(1f, 359f, 0.5f), EPSILON)
    }

    @Test
    fun `clamps interpolation alpha to the available simulation states`() {
        val previous = CarState(x = 3f, rotationDeg = 350f)
        val current = CarState(x = 9f, rotationDeg = 10f)

        assertEquals(3f, interpolateCarState(previous, current, -1f).x, EPSILON)
        assertEquals(9f, interpolateCarState(previous, current, 2f).x, EPSILON)
        assertEquals(350f, interpolateCarState(previous, current, -1f).rotationDeg, EPSILON)
        assertEquals(10f, interpolateCarState(previous, current, 2f).rotationDeg, EPSILON)
    }

    private companion object {
        const val EPSILON = 0.0001f
    }
}
