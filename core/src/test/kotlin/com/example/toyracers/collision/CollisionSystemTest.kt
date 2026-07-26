package com.example.toyracers.collision

import com.example.toyracers.car.CarState
import com.example.toyracers.track.TrackLoader
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CollisionSystemTest {
    private val collisionSystem = CollisionSystem()
    private val track = TrackLoader().load()

    @Test
    fun `world edge pushes car inside and removes outward velocity`() {
        val state = CarState(
            x = -1f,
            y = 6f,
            velocityX = -10f,
            velocityY = 4f,
            speed = -10f,
        )

        val result = collisionSystem.resolveTrackCollision(state, radius = 1f, track)

        assertTrue(result.collided)
        assertEquals(CollisionType.WORLD_BOUNDARY, result.contacts.first().type)
        assertEquals(1f, state.x, TOLERANCE)
        assertEquals(0f, state.velocityX, TOLERANCE)
        assertEquals(2.6f, state.velocityY, TOLERANCE)
        assertEquals(10f, result.maxImpactSpeed, TOLERANCE)
    }

    @Test
    fun `center obstacle does not cause collision`() {
        val obstacle = track.innerObstacles.first()
        val state = CarState(
            x = obstacle.x + obstacle.width / 2f,
            y = obstacle.y + obstacle.height / 2f,
            rotationDeg = 90f,
            velocityY = 8f,
            speed = 8f,
        )

        val result = collisionSystem.resolveTrackCollision(state, radius = 1f, track)

        assertFalse(result.collided)
        assertEquals(obstacle.x + obstacle.width / 2f, state.x, TOLERANCE)
        assertEquals(obstacle.y + obstacle.height / 2f, state.y, TOLERANCE)
        assertEquals(8f, state.velocityY, TOLERANCE)
    }

    @Test
    fun `car does not remain stuck in world corner`() {
        val state = CarState(x = -1f, y = -2f, velocityX = -5f, velocityY = -5f)

        collisionSystem.resolveTrackCollision(state, radius = 1f, track)
        val secondResult = collisionSystem.resolveTrackCollision(state, radius = 1f, track)

        assertEquals(1f, state.x, TOLERANCE)
        assertEquals(1f, state.y, TOLERANCE)
        assertFalse(secondResult.collided)
    }

    @Test
    fun `leaving asphalt does not collide before world edge`() {
        val state = CarState(x = 2f, y = 6f, velocityX = -2f)

        val result = collisionSystem.resolveTrackCollision(state, radius = 1f, track)

        assertFalse(result.collided)
        assertEquals(2f, state.x, TOLERANCE)
    }

    @Test
    fun `separated car does not report collision`() {
        val state = CarState(x = 7f, y = 6f)

        val result = collisionSystem.resolveTrackCollision(state, radius = 1f, track)

        assertFalse(result.collided)
    }

    @Test
    fun `car collision separates overlap and transfers momentum`() {
        val first = CarState(x = 0f, velocityX = 10f, speed = 10f)
        val second = CarState(x = 1.5f)

        val result = collisionSystem.resolveCarCollision(
            first = first,
            firstRadius = 1f,
            second = second,
            secondRadius = 1f,
        )

        assertTrue(result.collided)
        assertEquals(-0.25f, first.x, TOLERANCE)
        assertEquals(1.75f, second.x, TOLERANCE)
        assertTrue(first.velocityX < 10f)
        assertTrue(second.velocityX > 0f)
        assertEquals(10f, first.velocityX + second.velocityX, TOLERANCE)
    }

    @Test
    fun `car collision impulse is capped`() {
        val first = CarState(x = 0f, velocityX = 100f, speed = 100f)
        val second = CarState(x = 1f)

        collisionSystem.resolveCarCollision(first, 1f, second, 1f)

        assertEquals(8f, second.velocityX, TOLERANCE)
    }

    private companion object {
        const val TOLERANCE = 0.001f
    }
}
