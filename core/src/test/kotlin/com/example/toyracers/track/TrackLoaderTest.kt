package com.example.toyracers.track

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TrackLoaderTest {
    private val track = TrackLoader().load()

    @Test
    fun `built in track contains all required race data`() {
        assertTrue(track.collisionShapes.isNotEmpty())
        assertTrue(track.roadOuter != null)
        assertTrue(track.roadInner != null)
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
    fun `infield and outside area use parquet`() {
        assertEquals(track.backgroundSurface, track.surfaceAt(TrackPoint(54f, 36f)))
        assertEquals(track.backgroundSurface, track.surfaceAt(TrackPoint(3f, 3f)))
        assertFalse(track.roadOuter!!.contains(3f, 3f))
    }

    @Test
    fun `oval road edges separate asphalt from parquet`() {
        assertEquals(SurfaceType.ASPHALT, track.surfaceAt(TrackPoint(54f, 18f)))
        assertEquals(SurfaceType.PARQUET, track.surfaceAt(TrackPoint(54f, 36f)))
        assertEquals(SurfaceType.PARQUET, track.surfaceAt(TrackPoint(54f, 6f)))
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
