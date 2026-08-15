package com.example.toyracers.ai

import com.example.toyracers.car.CarState
import org.junit.Assert.assertEquals
import org.junit.Test

class AiRecoveryControllerTest {
    private val config =
        AiConfig(
            stuckDurationSeconds = 0.5f,
            recoveryDurationSeconds = 0.5f,
        )

    @Test
    fun `successful reverse recovery resumes driving without respawn`() {
        val controller = AiRecoveryController(config)

        assertEquals(
            AiRecoveryAction.REVERSE,
            controller.update(CarState(), 0f, isOnTrack = true, deltaSeconds = 0.5f),
        )
        assertEquals(
            AiRecoveryAction.NONE,
            controller.update(
                CarState(speed = config.stuckSpeed),
                headingErrorDegrees = config.wrongWayAngleDeg,
                isOnTrack = true,
                deltaSeconds = 0.5f,
            ),
        )
    }

    @Test
    fun `failed reverse recovery requests respawn`() {
        val controller = AiRecoveryController(config)

        controller.update(CarState(), 0f, isOnTrack = true, deltaSeconds = 0.5f)

        assertEquals(
            AiRecoveryAction.RESPAWN,
            controller.update(
                CarState(speed = config.stuckSpeed),
                headingErrorDegrees = 0f,
                isOnTrack = false,
                deltaSeconds = 0.5f,
            ),
        )
    }
}
