package com.example.toyracers.surface

import org.junit.Assert.assertThrows
import org.junit.Test

class SurfaceConfigValidationTest {
    @Test
    fun `surface config rejects invalid speed limits and transitions`() {
        assertRejected { SurfaceSpeedConfig(offRoadSpeedMultiplier = -0.1f) }
        assertRejected { SurfaceSpeedConfig(offRoadSpeedMultiplier = 1.1f) }
        assertRejected { SurfaceSpeedConfig(transitionSeconds = 0f) }
        assertThrows(IllegalArgumentException::class.java) { SurfaceSpeedState(speedMultiplier = -0.1f) }
    }

    private fun assertRejected(create: () -> SurfaceSpeedConfig) {
        assertThrows(IllegalArgumentException::class.java) { create() }
    }
}
