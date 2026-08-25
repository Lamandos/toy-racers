package com.example.toyracers.collision

import com.example.toyracers.car.CarState
import com.example.toyracers.track.Track
import com.example.toyracers.track.TrackCircle
import com.example.toyracers.track.TrackLoader
import com.example.toyracers.track.TrackPoint
import com.example.toyracers.track.TrackPolygon
import com.example.toyracers.track.TrackRectangle
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CollisionEdgeCaseTest {
    private val collisionSystem = CollisionSystem()
    private val baseTrack = TrackLoader().load()

    @Test
    fun `inside rectangle resolves through its nearest side`() {
        val obstacle = TrackRectangle(20f, 20f, 4f, 4f)
        val cases =
            listOf(
                RectangleCase(20.5f, 22f, 19f, 22f),
                RectangleCase(23.5f, 22f, 25f, 22f),
                RectangleCase(22f, 20.5f, 22f, 19f),
                RectangleCase(22f, 23.5f, 22f, 25f),
            )

        cases.forEach { case ->
            val state = CarState(x = case.x, y = case.y)

            val result = collisionSystem.resolveTrackCollision(state, radius = 1f, rectangleTrack(obstacle))

            assertTrue(result.collided)
            assertEquals(CollisionType.TRACK_OBJECT, result.contacts.single().type)
            assertEquals(case.expectedX, state.x, TOLERANCE)
            assertEquals(case.expectedY, state.y, TOLERANCE)
        }
    }

    @Test
    fun `rectangle corner contact uses diagonal normal`() {
        val state = CarState(x = 19.5f, y = 19.5f, velocityX = 2f, velocityY = 2f)

        val result =
            collisionSystem.resolveTrackCollision(
                state,
                radius = 1f,
                rectangleTrack(TrackRectangle(20f, 20f, 4f, 4f)),
            )

        val contact = result.contacts.single()
        assertTrue(result.collided)
        assertTrue(contact.normalX < 0f)
        assertTrue(contact.normalY < 0f)
        assertTrue(state.x < 19.5f)
        assertTrue(state.y < 19.5f)
    }

    @Test
    fun `circle collision handles center overlap and exact tangent`() {
        val circle = TrackCircle(TrackPoint(30f, 30f), radius = 2f)
        val centered = CarState(x = 30f, y = 30f)

        val centeredResult = collisionSystem.resolveTrackCollision(centered, radius = 1f, shapeTrack(circle))
        val tangent = CarState(x = 33f, y = 30f)
        val tangentResult = collisionSystem.resolveTrackCollision(tangent, radius = 1f, shapeTrack(circle))

        assertTrue(centeredResult.collided)
        assertEquals(33f, centered.x, TOLERANCE)
        assertFalse(tangentResult.collided)
        assertEquals(33f, tangent.x, TOLERANCE)
    }

    @Test
    fun `polygon collision resolves interior for either winding direction`() {
        val counterClockwise = squareVertices()
        val clockwise = counterClockwise.reversed()

        listOf(counterClockwise, clockwise).forEach { vertices ->
            val state = CarState(x = 42f, y = 41f)

            val result =
                collisionSystem.resolveTrackCollision(
                    state,
                    radius = 1f,
                    shapeTrack(TrackPolygon(vertices)),
                )

            assertTrue(result.collided)
            assertEquals(CollisionType.TRACK_OBJECT, result.contacts.single().type)
            assertEquals(39f, state.y, TOLERANCE)
        }
    }

    @Test
    fun `world boundary resolves right and top edges and preserves inward motion`() {
        val state = CarState(x = baseTrack.worldBounds.maxX + 2f, y = baseTrack.worldBounds.maxY + 2f)
        state.velocityX = -3f
        state.velocityY = -4f

        val result =
            collisionSystem.resolveTrackCollision(
                state,
                radius = 1f,
                baseTrack.copy(collisionShapes = emptyList()),
            )

        assertEquals(baseTrack.worldBounds.maxX - 1f, state.x, TOLERANCE)
        assertEquals(baseTrack.worldBounds.maxY - 1f, state.y, TOLERANCE)
        assertEquals(-3f, state.velocityX, TOLERANCE)
        assertEquals(-4f, state.velocityY, TOLERANCE)
        assertEquals(2, result.contacts.size)
    }

    @Test
    fun `car collision resolves coincident centers and ignores tangent cars`() {
        val first = CarState(x = 50f, y = 50f)
        val second = CarState(x = 50f, y = 50f)

        val overlap = collisionSystem.resolveCarCollision(first, 1f, second, 1f)
        val tangentFirst = CarState(x = 60f, y = 60f)
        val tangentSecond = CarState(x = 62f, y = 60f)
        val tangent = collisionSystem.resolveCarCollision(tangentFirst, 1f, tangentSecond, 1f)

        assertTrue(overlap.collided)
        assertEquals(49f, first.x, TOLERANCE)
        assertEquals(51f, second.x, TOLERANCE)
        assertFalse(tangent.collided)
        assertEquals(60f, tangentFirst.x, TOLERANCE)
        assertEquals(62f, tangentSecond.x, TOLERANCE)
    }

    private fun rectangleTrack(obstacle: TrackRectangle): Track =
        baseTrack.copy(innerObstacles = listOf(obstacle), collisionShapes = emptyList())

    private fun shapeTrack(shape: com.example.toyracers.track.TrackCollisionShape): Track =
        baseTrack.copy(innerObstacles = emptyList(), collisionShapes = listOf(shape))

    private fun squareVertices(): List<TrackPoint> =
        listOf(
            TrackPoint(40f, 40f),
            TrackPoint(44f, 40f),
            TrackPoint(44f, 44f),
            TrackPoint(40f, 44f),
        )

    private data class RectangleCase(
        val x: Float,
        val y: Float,
        val expectedX: Float,
        val expectedY: Float,
    )

    private companion object {
        const val TOLERANCE = 0.001f
    }
}
