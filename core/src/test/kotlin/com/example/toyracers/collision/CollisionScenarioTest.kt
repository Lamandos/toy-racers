package com.example.toyracers.collision

import com.example.toyracers.car.CarConfig
import com.example.toyracers.car.CarState
import com.example.toyracers.track.TrackLoader
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.hypot

class CollisionScenarioTest {
    private val collisionSystem = CollisionSystem()
    private val trackWithoutObjects = TrackLoader().load().copy(collisionShapes = emptyList())
    private val carConfig = CarConfig()

    @Test
    fun `head-on car collision reports contact and transfers momentum`() {
        val first = car(x = 0f, rotationDeg = 0f, velocityX = 12f)
        val second = car(x = 2.5f, rotationDeg = 180f, velocityX = -12f)

        val result = collide(first, second)

        assertCarContact(result)
        assertEquals(24f, result.maxImpactSpeed, TOLERANCE)
        assertSeparated(first, second)
        assertTrue(first.velocityX < 12f)
        assertTrue(second.velocityX > -12f)
    }

    @Test
    fun `side collision reports contact and redirects lateral movement`() {
        val first = car(y = 0f, rotationDeg = 0f, velocityY = 8f)
        val second = car(y = 2f, rotationDeg = 90f)

        val result = collide(first, second)

        assertCarContact(result)
        assertSeparated(first, second)
        assertTrue(first.velocityY < 8f)
        assertTrue(second.velocityY > 0f)
    }

    @Test
    fun `rear collision reports contact and accelerates leading car`() {
        val first = car(x = 0f, rotationDeg = 0f, velocityX = 8f)
        val second = car(x = 2.5f, rotationDeg = 0f, velocityX = 2f)

        val result = collide(first, second)

        assertCarContact(result)
        assertSeparated(first, second)
        assertTrue(first.velocityX < 8f)
        assertTrue(second.velocityX > 2f)
    }

    @Test
    fun `glancing collision reports contact and imparts diagonal velocity`() {
        val first = car(x = 0f, y = 0f, rotationDeg = 20f, velocityX = 10f)
        val second = car(x = 2.5f, y = 0.8f, rotationDeg = 200f)

        val result = collide(first, second)

        assertCarContact(result)
        assertSeparated(first, second)
        assertTrue(second.velocityX > 0f)
        assertTrue(second.velocityY > 0f)
    }

    @Test
    fun `low speed collision preserves a low impact result and separates cars`() {
        val first = car(x = 0f, rotationDeg = 0f, velocityX = 1f)
        val second = car(x = 2.5f, rotationDeg = 180f)

        val result = collide(first, second)

        assertCarContact(result)
        assertEquals(1f, result.maxImpactSpeed, TOLERANCE)
        assertSeparated(first, second)
        assertTrue(second.velocityX in 0f..1f)
    }

    @Test
    fun `high speed collision caps impulse while reporting full impact`() {
        val first = car(x = 0f, rotationDeg = 0f, velocityX = 100f)
        val second = car(x = 2.5f, rotationDeg = 180f)

        val result = collide(first, second)

        assertCarContact(result)
        assertEquals(100f, result.maxImpactSpeed, TOLERANCE)
        assertSeparated(first, second)
        assertEquals(8f, second.velocityX, TOLERANCE)
    }

    @Test
    fun `car track collision reports world boundary and removes outward velocity`() {
        val state = car(x = 0.2f, y = 6f, velocityX = -10f)

        val result = resolveTrackCollision(state)

        assertTrackContact(result)
        assertEquals(EXPECTED_BOUNDARY_CENTER, state.x, TOLERANCE)
        assertEquals(0f, state.velocityX, TOLERANCE)
    }

    @Test
    fun `repeated contact over multiple ticks reports every contact and stays inside track`() {
        val state = car(x = 0.5f, y = 6f, velocityX = -4f)

        repeat(3) {
            state.x = 0.5f
            state.velocityX = -4f
            val result = resolveTrackCollision(state)
            assertTrackContact(result)
            assertEquals(EXPECTED_BOUNDARY_CENTER, state.x, TOLERANCE)
            assertEquals(0f, state.velocityX, TOLERANCE)
        }
    }

    @Test
    fun `collision near track corner reports both boundary contacts and resolves position`() {
        val state = car(x = 0.5f, y = 0.5f, velocityX = -8f, velocityY = -8f)

        val result =
            collisionSystem.resolveTrackCollision(
                state = state,
                radius = carConfig.collisionRadius,
                longitudinalOffset = carConfig.collisionLongitudinalOffset,
                track = trackWithoutObjects,
            )

        assertEquals(2, result.contacts.size)
        assertTrue(result.contacts.all { it.type == CollisionType.WORLD_BOUNDARY })
        assertEquals(1.62f, state.x, TOLERANCE)
        assertEquals(carConfig.collisionRadius, state.y, TOLERANCE)
        assertEquals(0f, state.velocityX, TOLERANCE)
        assertEquals(0f, state.velocityY, TOLERANCE)
    }

    @Test
    fun `cars separating after collision increase their distance on the next tick`() {
        val first = car(x = 0f, rotationDeg = 0f, velocityX = 8f)
        val second = car(x = 2.5f, rotationDeg = 180f)

        assertCarContact(collide(first, second))
        val distanceAfterCollision = distanceBetween(first, second)
        first.x += first.velocityX
        second.x += second.velocityX

        assertTrue(distanceBetween(first, second) > distanceAfterCollision)
    }

    @Test
    fun `near but non touching cars do not report a false positive or change state`() {
        val first = car(x = 0f, rotationDeg = 0f)
        val second = car(x = 3.25f, rotationDeg = 180f)

        val result = collide(first, second)

        assertFalse(result.collided)
        assertEquals(0f, first.x, TOLERANCE)
        assertEquals(3.25f, second.x, TOLERANCE)
        assertEquals(0f, first.velocityX, TOLERANCE)
        assertEquals(0f, second.velocityX, TOLERANCE)
    }

    private fun collide(
        first: CarState,
        second: CarState,
    ): CollisionResult =
        collisionSystem.resolveCarCollision(
            first = first,
            firstRadius = carConfig.collisionRadius,
            firstLongitudinalOffset = carConfig.collisionLongitudinalOffset,
            second = second,
            secondRadius = carConfig.collisionRadius,
            secondLongitudinalOffset = carConfig.collisionLongitudinalOffset,
        )

    private fun resolveTrackCollision(state: CarState): CollisionResult =
        collisionSystem.resolveTrackCollision(
            state = state,
            radius = carConfig.collisionRadius,
            longitudinalOffset = carConfig.collisionLongitudinalOffset,
            track = trackWithoutObjects,
        )

    private fun car(
        x: Float = 0f,
        y: Float = 0f,
        rotationDeg: Float = 0f,
        velocityX: Float = 0f,
        velocityY: Float = 0f,
    ): CarState =
        CarState(
            x = x,
            y = y,
            rotationDeg = rotationDeg,
            velocityX = velocityX,
            velocityY = velocityY,
        )

    private fun assertCarContact(result: CollisionResult) {
        assertTrue(result.collided)
        assertEquals(CollisionType.CAR, result.contacts.single().type)
    }

    private fun assertTrackContact(result: CollisionResult) {
        assertTrue(result.collided)
        assertTrue(result.contacts.all { it.type == CollisionType.WORLD_BOUNDARY })
    }

    private fun assertSeparated(
        first: CarState,
        second: CarState,
    ) {
        val firstCircles =
            carCollisionCircles(
                first,
                carConfig.collisionRadius,
                carConfig.collisionLongitudinalOffset,
            )
        val secondCircles =
            carCollisionCircles(
                second,
                carConfig.collisionRadius,
                carConfig.collisionLongitudinalOffset,
            )
        firstCircles.forEach { firstCircle ->
            secondCircles.forEach { secondCircle ->
                val distance = hypot(secondCircle.x - firstCircle.x, secondCircle.y - firstCircle.y)
                assertTrue(
                    "Collision circles still overlap: first=$firstCircle, second=$secondCircle",
                    distance >= firstCircle.radius + secondCircle.radius - TOLERANCE,
                )
            }
        }
    }

    private fun distanceBetween(
        first: CarState,
        second: CarState,
    ): Float = hypot(second.x - first.x, second.y - first.y)

    private companion object {
        const val EXPECTED_BOUNDARY_CENTER = 1.62f
        const val TOLERANCE = 0.001f
    }
}
