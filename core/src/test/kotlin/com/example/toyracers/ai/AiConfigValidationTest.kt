package com.example.toyracers.ai

import org.junit.Assert.assertThrows
import org.junit.Test

class AiConfigValidationTest {
    @Test
    fun `basic movement settings reject invalid values`() {
        assertRejected { AiConfig(waypointRadius = 0f) }
        assertRejected { AiConfig(fullSteeringAngleDeg = 0f) }
        assertRejected { AiConfig(straightSpeed = 0f) }
        assertRejected { AiConfig(cornerSpeed = 0f) }
        assertRejected { AiConfig(cornerSpeed = 14f) }
        assertRejected { AiConfig(brakingMargin = -1f) }
        assertRejected { AiConfig(stuckSpeed = -1f) }
        assertRejected { AiConfig(stuckDurationSeconds = 0f) }
        assertRejected { AiConfig(recoveryDurationSeconds = 0f) }
        assertRejected { AiConfig(steeringResponse = 0f) }
        assertRejected { AiConfig(lookAheadPoints = 0) }
    }

    @Test
    fun `obstacle sensing settings reject invalid values`() {
        assertRejected { AiConfig(obstacleDetectionDistance = 0f) }
        assertRejected { AiConfig(obstacleLaneHalfWidth = 0f) }
        assertRejected { AiConfig(staticObstacleReactionDistance = 8f) }
        assertRejected { AiConfig(avoidanceSteering = 1.1f) }
        assertRejected { AiConfig(overtakeSpeedAdvantage = -0.1f) }
        assertRejected { AiConfig(overtakeLaneOffset = 0f) }
        assertRejected { AiConfig(overtakeLaneHalfWidth = 0f) }
        assertRejected { AiConfig(overtakeMinimumClearance = 8f) }
        assertRejected { AiConfig(sensorRayAngleDeg = 91f) }
        assertRejected { AiConfig(sensorRayStep = 0f) }
    }

    @Test
    fun `recovery and mistake settings reject invalid values`() {
        assertRejected { AiConfig(wrongWayAngleDeg = 89f) }
        assertRejected { AiConfig(wrongWayDurationSeconds = 0f) }
        assertRejected { AiConfig(offTrackDurationSeconds = 0f) }
        assertRejected { AiConfig(racingLineBiasDistance = -0.1f) }
        assertRejected { AiConfig(obstacleSpeedReduction = -0.1f) }
        assertRejected { AiConfig(mistakeCheckIntervalSeconds = 0f) }
        assertRejected { AiConfig(mistakeProbability = 1.1f) }
        assertRejected { AiConfig(mistakeDurationSeconds = -0.1f) }
        assertRejected { AiConfig(mistakeSteering = -0.1f) }
        assertRejected { AiConfig(routeTurnPriority = 1.1f) }
    }

    private fun assertRejected(create: () -> AiConfig) {
        assertThrows(IllegalArgumentException::class.java) { create() }
    }
}
