package com.example.toyracers.ui

import com.example.toyracers.track.TrackRectangle
import org.junit.Assert.assertEquals
import org.junit.Test

class MinimapTransformTest {
    @Test
    fun `maps bounds corners and center with non-zero origin`() {
        val transform = MinimapTransform(TrackRectangle(10f, 20f, 20f, 10f), 120f, 70f, 10f)

        assertPoint(transform, 10f, 20f, 10f, 10f)
        assertPoint(transform, 30f, 30f, 110f, 60f)
        assertPoint(transform, 20f, 25f, 60f, 35f)
    }

    @Test
    fun `letterboxes wide track in tall widget`() {
        val transform = MinimapTransform(TrackRectangle(0f, 0f, 20f, 10f), 100f, 100f, 10f)

        assertPoint(transform, 0f, 0f, 10f, 30f)
        assertPoint(transform, 20f, 10f, 90f, 70f)
    }

    @Test
    fun `letterboxes tall track in wide widget`() {
        val transform = MinimapTransform(TrackRectangle(0f, 0f, 10f, 20f), 100f, 100f, 10f)

        assertPoint(transform, 0f, 0f, 30f, 10f)
        assertPoint(transform, 10f, 20f, 70f, 90f)
    }

    @Test
    fun `clamps markers to bounds`() {
        val transform = MinimapTransform(TrackRectangle(5f, 10f, 10f, 10f), 100f, 100f, 10f)

        assertPoint(transform, -20f, 50f, 10f, 90f)
    }

    private fun assertPoint(
        transform: MinimapTransform,
        worldX: Float,
        worldY: Float,
        expectedX: Float,
        expectedY: Float,
    ) {
        assertEquals(expectedX, transform.mapX(worldX), 0.0001f)
        assertEquals(expectedY, transform.mapY(worldY), 0.0001f)
    }
}
