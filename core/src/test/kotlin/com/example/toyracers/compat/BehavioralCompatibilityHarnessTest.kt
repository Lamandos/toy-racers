package com.example.toyracers.compat

import org.junit.Assert.assertEquals
import org.junit.Test

class BehavioralCompatibilityHarnessTest {
    @Test
    fun `normalized snapshot wraps initial rotations at the snapshot boundary`() {
        val harness =
            BehavioralCompatibilityHarness(
                BehavioralRaceConfiguration(
                    seed = 1L,
                    trackId = "track-01",
                    playerCar = "red-stripe",
                ),
            )
        harness.setInitialStates(
            listOf(
                BehavioralInitialState(id = "player", rotationDeg = 725f),
                BehavioralInitialState(id = "ai-0", rotationDeg = -10f),
                BehavioralInitialState(id = "ai-1", rotationDeg = -0.000001f),
            ),
        )

        val participants = harness.start().participants.associateBy { it.id }

        assertEquals(5f, participants.getValue("player").rotation, 0f)
        assertEquals(350f, participants.getValue("ai-0").rotation, 0f)
        assertEquals(0f, participants.getValue("ai-1").rotation, 0f)
    }
}
