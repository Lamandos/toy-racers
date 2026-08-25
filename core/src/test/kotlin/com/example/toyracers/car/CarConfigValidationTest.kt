package com.example.toyracers.car

import org.junit.Assert.assertThrows
import org.junit.Test

class CarConfigValidationTest {
    @Test
    fun `movement settings reject invalid values`() {
        assertRejected { CarConfig(acceleration = -1f) }
        assertRejected { CarConfig(brakeForce = -1f) }
        assertRejected { CarConfig(reverseAcceleration = -1f) }
        assertRejected { CarConfig(maxForwardSpeed = 0f) }
        assertRejected { CarConfig(maxReverseSpeed = 0f) }
        assertRejected { CarConfig(steeringSpeed = -1f) }
        assertRejected { CarConfig(grip = -1f) }
        assertRejected { CarConfig(lateralFriction = -1f) }
        assertRejected { CarConfig(rollingResistance = -1f) }
        assertRejected { CarConfig(driftEntrySpeed = 0f) }
    }

    @Test
    fun `drift settings reject invalid values`() {
        assertRejected { CarConfig(driftSteeringThreshold = 1f) }
        assertRejected { CarConfig(driftGripMultiplier = 1.1f) }
        assertRejected { CarConfig(driftSteeringMultiplier = 0.9f) }
        assertRejected { CarConfig(driftEntryResponse = 0f) }
        assertRejected { CarConfig(driftExitResponse = 0f) }
        assertRejected { CarConfig(driftDrag = -0.1f) }
    }

    @Test
    fun `collision shape settings reject invalid values`() {
        assertRejected { CarConfig(collisionRadius = 0f) }
        assertRejected { CarConfig(collisionLongitudinalOffset = -0.1f) }
        assertRejected { CarConfig(width = 0f) }
        assertRejected { CarConfig(length = 0f) }
        assertRejected { CarConfig(collisionRadius = 1f, width = 1.8f) }
        assertRejected { CarConfig(collisionLongitudinalOffset = 1f, length = 3f) }
    }

    private fun assertRejected(create: () -> CarConfig) {
        assertThrows(IllegalArgumentException::class.java) { create() }
    }
}
