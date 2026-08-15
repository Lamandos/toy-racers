package com.example.toyracers.ai

/** Tunable waypoint-following and recovery behavior for one AI driver. */
data class AiConfig(
    val waypointRadius: Float = 3f,
    val fullSteeringAngleDeg: Float = 60f,
    val straightSpeed: Float = 13f,
    val cornerSpeed: Float = 6f,
    val brakingMargin: Float = 2f,
    val stuckSpeed: Float = 1f,
    val stuckDurationSeconds: Float = 2f,
    val recoveryDurationSeconds: Float = 1.25f,
    val steeringResponse: Float = 60f,
    val lookAheadPoints: Int = 1,
    val obstacleDetectionDistance: Float = 7f,
    val obstacleLaneHalfWidth: Float = 1.4f,
    val staticObstacleReactionDistance: Float = 5f,
    val avoidanceSteering: Float = 0.7f,
    val overtakeSpeedAdvantage: Float = 1.5f,
    val overtakeLaneOffset: Float = 2f,
    val overtakeLaneHalfWidth: Float = 0.8f,
    val overtakeMinimumClearance: Float = 3f,
    val wrongWayAngleDeg: Float = 110f,
    val wrongWayDurationSeconds: Float = 1.25f,
    val offTrackDurationSeconds: Float = 4f,
    val sensorRayAngleDeg: Float = 32f,
    val sensorRayStep: Float = 0.35f,
    val racingLineBiasDistance: Float = 0.45f,
    val obstacleSpeedReduction: Float = 0.65f,
    val mistakeCheckIntervalSeconds: Float = 1f,
    val mistakeProbability: Float = 0.08f,
    val mistakeDurationSeconds: Float = 0.25f,
    val mistakeSteering: Float = 0.18f,
    val routeTurnPriority: Float = 0.25f,
) {
    init {
        require(waypointRadius > 0f)
        require(fullSteeringAngleDeg > 0f)
        require(straightSpeed > 0f)
        require(cornerSpeed > 0f)
        require(cornerSpeed <= straightSpeed)
        require(brakingMargin >= 0f)
        require(stuckSpeed >= 0f)
        require(stuckDurationSeconds > 0f)
        require(recoveryDurationSeconds > 0f)
        require(steeringResponse > 0f)
        require(lookAheadPoints > 0)
        require(obstacleDetectionDistance > 0f)
        require(obstacleLaneHalfWidth > 0f)
        require(staticObstacleReactionDistance in sensorRayStep..obstacleDetectionDistance)
        require(avoidanceSteering in 0f..1f)
        require(overtakeSpeedAdvantage >= 0f)
        require(overtakeLaneOffset > 0f)
        require(overtakeLaneHalfWidth > 0f)
        require(overtakeMinimumClearance in 0f..obstacleDetectionDistance)
        require(wrongWayAngleDeg in 90f..180f)
        require(wrongWayDurationSeconds > 0f)
        require(offTrackDurationSeconds > 0f)
        require(sensorRayAngleDeg in 0f..90f)
        require(sensorRayStep > 0f)
        require(racingLineBiasDistance >= 0f)
        require(obstacleSpeedReduction in 0f..1f)
        require(mistakeCheckIntervalSeconds > 0f)
        require(mistakeProbability in 0f..1f)
        require(mistakeDurationSeconds >= 0f)
        require(mistakeSteering in 0f..1f)
        require(routeTurnPriority in 0f..1f)
    }

    fun forDifficulty(difficulty: AiDifficulty): AiConfig =
        when (difficulty) {
            AiDifficulty.EASY -> {
                val adjustedStraightSpeed = straightSpeed * 0.78f
                val adjustedDetectionDistance =
                    maxOf(
                        obstacleDetectionDistance * 0.75f,
                        sensorRayStep,
                    )
                copy(
                    straightSpeed = adjustedStraightSpeed,
                    cornerSpeed = minOf(cornerSpeed * 0.85f, adjustedStraightSpeed),
                    steeringResponse = steeringResponse * 0.65f,
                    obstacleDetectionDistance = adjustedDetectionDistance,
                    staticObstacleReactionDistance =
                        (staticObstacleReactionDistance * 0.75f)
                            .coerceIn(sensorRayStep, adjustedDetectionDistance),
                    avoidanceSteering = avoidanceSteering * 0.75f,
                    overtakeMinimumClearance = overtakeMinimumClearance * 0.75f,
                    mistakeProbability = 0.18f,
                    mistakeDurationSeconds = 0.4f,
                    mistakeSteering = 0.28f,
                )
            }

            AiDifficulty.NORMAL -> {
                this
            }

            AiDifficulty.HARD -> {
                val adjustedStraightSpeed = straightSpeed * 1.08f
                copy(
                    straightSpeed = adjustedStraightSpeed,
                    cornerSpeed = minOf(cornerSpeed * 1.12f, adjustedStraightSpeed),
                    steeringResponse = steeringResponse * 1.25f,
                    obstacleDetectionDistance = obstacleDetectionDistance * 1.2f,
                    staticObstacleReactionDistance = staticObstacleReactionDistance * 1.2f,
                    overtakeSpeedAdvantage = overtakeSpeedAdvantage * 0.75f,
                    overtakeMinimumClearance = overtakeMinimumClearance * 1.2f,
                    mistakeProbability = 0.02f,
                    mistakeDurationSeconds = 0.12f,
                    mistakeSteering = 0.08f,
                )
            }
        }
}

enum class AiDifficulty { EASY, NORMAL, HARD }
