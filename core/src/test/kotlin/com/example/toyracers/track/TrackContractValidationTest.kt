package com.example.toyracers.track

import org.junit.Assert.assertThrows
import org.junit.Test

class TrackContractValidationTest {
    private val track = TrackLoader().load()

    @Test
    fun `geometry primitives reject invalid dimensions and points`() {
        assertThrows(IllegalArgumentException::class.java) { TrackRectangle(0f, 0f, 0f, 1f) }
        assertThrows(IllegalArgumentException::class.java) { TrackRectangle(0f, 0f, 1f, 0f) }
        assertThrows(IllegalArgumentException::class.java) {
            TrackSegment(TrackPoint(1f, 1f), TrackPoint(1f, 1f))
        }
        assertThrows(IllegalArgumentException::class.java) { TrackCircle(TrackPoint(1f, 1f), 0f) }
        assertThrows(IllegalArgumentException::class.java) {
            TrackPolygon(listOf(TrackPoint(0f, 0f), TrackPoint(1f, 1f)))
        }
    }

    @Test
    fun `checkpoint and start line require a forward direction`() {
        val gate = track.checkpoints.first().gate

        assertThrows(IllegalArgumentException::class.java) { Checkpoint(-1, gate, 1f, 0f) }
        assertThrows(IllegalArgumentException::class.java) { Checkpoint(0, gate, 0f, 0f) }
        assertThrows(IllegalArgumentException::class.java) { StartLine(track.startLine.bounds, 0f, 0f) }
    }

    @Test
    fun `track rejects invalid identifiers and nested geometry`() {
        assertRejected { track.copy(id = "") }
        assertRejected { track.copy(name = "") }
        assertRejected { track.copy(cameraBounds = outsideBounds()) }
        assertRejected { track.copy(outerBoundary = outsideBounds()) }
        assertRejected { track.copy(innerObstacles = listOf(outsideBounds())) }
        assertRejected { track.copy(surfaceRegions = listOf(SurfaceRegion(outsideBounds(), SurfaceType.GRASS))) }
        assertRejected { track.copy(startLine = StartLine(outsideBounds(), 1f, 0f)) }
    }

    @Test
    fun `track rejects incomplete race metadata`() {
        assertRejected { track.copy(checkpoints = emptyList()) }
        assertRejected { track.copy(checkpoints = track.checkpoints.reversed()) }
        assertRejected { track.copy(startGrid = emptyList()) }
        assertRejected { track.copy(startGrid = listOf(StartGridPosition(TrackPoint(-1f, 1f), 0f))) }
        assertRejected { track.copy(racingLine = track.racingLine.take(2)) }
        assertRejected {
            track.copy(
                racingLine = listOf(TrackPoint(-1f, 1f), track.racingLine[1], track.racingLine[2]),
            )
        }
        assertRejected { track.copy(racingLineWaypointRadius = 0f) }
        assertRejected { track.copy(roadOuter = null) }
    }

    private fun outsideBounds(): TrackRectangle =
        TrackRectangle(-1f, -1f, track.worldBounds.width, track.worldBounds.height)

    private fun assertRejected(create: () -> Track) {
        assertThrows(IllegalArgumentException::class.java) { create() }
    }
}
