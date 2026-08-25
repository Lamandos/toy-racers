package com.example.toyracers.collision

import org.junit.Assert.assertThrows
import org.junit.Test

class CollisionConfigValidationTest {
    @Test
    fun `collision config rejects values outside its supported range`() {
        assertRejected { CollisionConfig(wallSpeedRetention = -0.1f) }
        assertRejected { CollisionConfig(carRestitution = 1.1f) }
        assertRejected { CollisionConfig(maxCarImpulse = -0.1f) }
    }

    private fun assertRejected(create: () -> CollisionConfig) {
        assertThrows(IllegalArgumentException::class.java) { create() }
    }
}
