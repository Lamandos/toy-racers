package com.example.toyracers.collision

import com.example.toyracers.car.CarState
import com.example.toyracers.track.TrackLoader
import com.example.toyracers.track.TrackPoint
import com.example.toyracers.track.TrackPolygon
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class CollisionSystemTest {
    private val collisionSystem = CollisionSystem()
    private val track = TrackLoader().load()
    private val trackWithoutObjects = track.copy(collisionShapes = emptyList())

    @Test
    fun `world edge pushes car inside and removes outward velocity`() {
        val state = CarState(
            x = -1f,
            y = 6f,
            velocityX = -10f,
            velocityY = 4f,
            speed = -10f,
        )

        val result = collisionSystem.resolveTrackCollision(state, radius = 1f, trackWithoutObjects)

        assertTrue(result.collided)
        assertEquals(CollisionType.WORLD_BOUNDARY, result.contacts.first().type)
        assertEquals(1f, state.x, TOLERANCE)
        assertEquals(0f, state.velocityX, TOLERANCE)
        assertEquals(2.6f, state.velocityY, TOLERANCE)
        assertEquals(10f, result.maxImpactSpeed, TOLERANCE)
    }

    @Test
    fun `track object pushes car out and reports object contact`() {
        val obstacle = TrackPolygon(
            listOf(
                TrackPoint(50f, 50f),
                TrackPoint(54f, 50f),
                TrackPoint(54f, 54f),
                TrackPoint(50f, 54f),
            ),
        )
        val leftX = obstacle.vertices.minOf { it.x }
        val centerY = obstacle.vertices.map { it.y }.average().toFloat()
        val state = CarState(
            x = leftX - 0.5f,
            y = centerY,
            velocityX = 8f,
            speed = 8f,
        )

        val result = collisionSystem.resolveTrackCollision(
            state,
            radius = 1f,
            track.copy(collisionShapes = listOf(obstacle)),
        )

        assertTrue(result.collided)
        assertEquals(CollisionType.TRACK_OBJECT, result.contacts.first().type)
        assertTrue(state.velocityX < 8f)
        assertTrue(state.x != leftX - 0.5f)
    }

    @Test
    fun `car does not remain stuck in world corner`() {
        val state = CarState(x = -1f, y = -2f, velocityX = -5f, velocityY = -5f)

        collisionSystem.resolveTrackCollision(state, radius = 1f, trackWithoutObjects)
        val secondResult =
            collisionSystem.resolveTrackCollision(state, radius = 1f, trackWithoutObjects)

        assertEquals(1f, state.x, TOLERANCE)
        assertEquals(1f, state.y, TOLERANCE)
        assertFalse(secondResult.collided)
    }

    @Test
    fun `leaving asphalt does not collide before world edge`() {
        val state = CarState(x = 2f, y = 6f, velocityX = -2f)

        val result = collisionSystem.resolveTrackCollision(state, radius = 1f, trackWithoutObjects)

        assertFalse(result.collided)
        assertEquals(2f, state.x, TOLERANCE)
    }

    @Test
    fun `separated car does not report collision`() {
        val state = CarState(x = 7f, y = 6f)

        val result = collisionSystem.resolveTrackCollision(state, radius = 1f, trackWithoutObjects)

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

    @Test
    fun `oriented collision capsule reaches the visible nose of car`() {
        val state = CarState(x = 1.5f, y = 6f, rotationDeg = 0f, velocityX = -2f)

        val result = collisionSystem.resolveTrackCollision(
            state = state,
            radius = 0.81f,
            longitudinalOffset = 0.81f,
            track = trackWithoutObjects,
        )

        assertTrue(result.collided)
        assertEquals(1.62f, state.x, TOLERANCE)
    }

    @Test
    fun `oriented car capsules collide nose to tail near sprite boundaries`() {
        val first = CarState(x = 0f, rotationDeg = 0f)
        val second = CarState(x = 3.1f, rotationDeg = 0f)

        val result = collisionSystem.resolveCarCollision(
            first = first,
            firstRadius = 0.81f,
            firstLongitudinalOffset = 0.81f,
            second = second,
            secondRadius = 0.81f,
            secondLongitudinalOffset = 0.81f,
        )

        assertTrue(result.collided)
    }

    @Test
    fun `invalid capsule resolution does not leave car shifted`() {
        val state = CarState(x = 4f, y = 6f, rotationDeg = 45f)

        assertThrows(IllegalArgumentException::class.java) {
            collisionSystem.resolveTrackCollision(
                state = state,
                radius = track.worldBounds.width,
                longitudinalOffset = 1f,
                track = trackWithoutObjects,
            )
        }

        assertEquals(4f, state.x, TOLERANCE)
        assertEquals(6f, state.y, TOLERANCE)
    }

    private companion object {
        const val TOLERANCE = 0.001f
    }
}
