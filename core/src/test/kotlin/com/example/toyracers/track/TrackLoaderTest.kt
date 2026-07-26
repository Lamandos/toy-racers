package com.example.toyracers.track

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TrackLoaderTest {
    private val track = TrackLoader().load()

    @Test
    fun `built in track contains all required race data`() {
        assertTrue(track.innerObstacles.isNotEmpty())
        assertTrue(track.surfaceRegions.isNotEmpty())
        assertTrue(track.checkpoints.isNotEmpty())
        assertEquals(4, track.startGrid.size)
        assertTrue(track.racingLine.size >= 3)
        assertTrue(track.worldBounds.contains(track.cameraBounds))
        assertTrue(track.worldBounds.contains(track.outerBoundary))
    }

    @Test
    fun `checkpoints are stored in race order`() {
        assertEquals(track.checkpoints.indices.toList(), track.checkpoints.map(Checkpoint::order))
    }

    @Test
    fun `grid and racing line stay on asphalt`() {
        track.startGrid.forEach {
            assertEquals(SurfaceType.ASPHALT, track.surfaceAt(it.position))
        }
        track.racingLine.forEach {
            assertEquals(SurfaceType.ASPHALT, track.surfaceAt(it))
        }
    }

    @Test
    fun `infield and outside area use background surface`() {
        val obstacleCenter = track.innerObstacles.first().let {
            TrackPoint(it.x + it.width / 2f, it.y + it.height / 2f)
        }

        assertEquals(track.backgroundSurface, track.surfaceAt(obstacleCenter))
        assertEquals(track.backgroundSurface, track.surfaceAt(TrackPoint(1f, 1f)))
        assertFalse(track.outerBoundary.contains(TrackPoint(1f, 1f)))
    }

    @Test(expected = IllegalArgumentException::class)
    fun `unknown track id is rejected`() {
        TrackLoader().load("missing-track")
    }

    @Test(expected = IllegalArgumentException::class)
    fun `unordered checkpoints are rejected`() {
        track.copy(checkpoints = track.checkpoints.reversed())
    }
}
