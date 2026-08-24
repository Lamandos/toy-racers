package com.example.toyracers.track

import com.example.toyracers.car.CarState
import com.example.toyracers.collision.CollisionSystem
import com.example.toyracers.collision.CollisionType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class TrackScenarioTest {
    private val trackLoader = TrackLoader()

    @Test
    fun `track 01 loads its known layout`() {
        val track = trackLoader.load(TrackId.LIVING_ROOM)

        assertEquals(TrackId.LIVING_ROOM.value, track.id)
        assertEquals(108f, track.worldBounds.width, TOLERANCE)
        assertEquals(72f, track.worldBounds.height, TOLERANCE)
        assertEquals(3, track.checkpoints.size)
        assertEquals(28, track.collisionShapes.size)
        assertTrue(track.roadOuter != null)
        assertTrue(track.roadInner != null)
    }

    @Test
    fun `track 02 loads its known layout`() {
        val track = trackLoader.load(TrackId.BATHROOM)

        assertEquals(TrackId.BATHROOM.value, track.id)
        assertEquals(108f, track.worldBounds.width, TOLERANCE)
        assertEquals(108f, track.worldBounds.height, TOLERANCE)
        assertEquals(5, track.checkpoints.size)
        assertEquals(25, track.collisionShapes.size)
        assertTrue(track.roadOuter != null)
        assertTrue(track.roadInner != null)
    }

    @Test
    fun `built in tracks retain their known start positions`() {
        assertEquals(
            livingRoomStartGrid(),
            trackLoader.load(TrackId.LIVING_ROOM).startGrid,
        )
        assertEquals(
            bathroomStartGrid(),
            trackLoader.load(TrackId.BATHROOM).startGrid,
        )
    }

    @Test
    fun `loaded collision geometry blocks cars at known objects`() {
        val livingRoom = trackLoader.load(TrackId.LIVING_ROOM)
        val bathroom = trackLoader.load(TrackId.BATHROOM)

        val livingRoomEllipse = livingRoom.collisionShapes[3] as TrackPolygon
        assertEquals(24, livingRoomEllipse.vertices.size)
        assertTrue(livingRoomEllipse.contains(LIVING_ROOM_ELLIPSE_CENTER.x, LIVING_ROOM_ELLIPSE_CENTER.y))
        assertTrackObjectCollision(livingRoom, 3, LIVING_ROOM_ELLIPSE_CENTER)

        val bathroomObject = bathroom.collisionShapes.first() as TrackPolygon
        assertEquals(13, bathroomObject.vertices.size)
        assertTrue(bathroomObject.contains(BATHROOM_OBJECT_POINT.x, BATHROOM_OBJECT_POINT.y))
        assertTrackObjectCollision(bathroom, 0, BATHROOM_OBJECT_POINT)
    }

    private fun assertTrackObjectCollision(
        track: Track,
        shapeIndex: Int,
        position: TrackPoint,
    ) {
        val result =
            CollisionSystem().resolveTrackCollision(
                state = CarState(x = position.x, y = position.y),
                radius = COLLISION_RADIUS,
                track = track.copy(collisionShapes = listOf(track.collisionShapes[shapeIndex])),
            )

        assertTrue(result.collided)
        assertTrue(result.contacts.all { it.type == CollisionType.TRACK_OBJECT })
    }

    private fun livingRoomStartGrid(): List<StartGridPosition> =
        listOf(
            startPosition(16.5f, 5.2f),
            startPosition(14f, 5.7f),
            startPosition(11.5f, 5.2f),
            startPosition(9f, 5.7f),
            startPosition(9f, 6.9f),
            startPosition(9f, 7.5f),
        )

    private fun bathroomStartGrid(): List<StartGridPosition> =
        listOf(
            startPosition(15.5f, 5.3f),
            startPosition(13.5f, 5.7f),
            startPosition(11.5f, 5.3f),
            startPosition(10.5f, 5.7f),
            startPosition(10.5f, 6.9f),
            startPosition(10.5f, 7.5f),
        )

    private fun startPosition(
        x: Float,
        y: Float,
    ): StartGridPosition =
        StartGridPosition(
            position = TrackPoint(x * TrackLoader.MAP_SCALE, y * TrackLoader.MAP_SCALE),
            rotationDeg = 0f,
        )

    private companion object {
        const val COLLISION_RADIUS = 0.1f
        const val TOLERANCE = 0.001f
        val LIVING_ROOM_ELLIPSE_CENTER = TrackPoint(100.85f, 30.87f)
        val BATHROOM_OBJECT_POINT = TrackPoint(40f, 83f)
    }
}
