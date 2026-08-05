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
    val avoidanceSteering: Float = 0.7f,
    val overtakeSpeedAdvantage: Float = 1.5f,
    val wrongWayAngleDeg: Float = 110f,
    val wrongWayDurationSeconds: Float = 1.25f,
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
        require(avoidanceSteering in 0f..1f)
        require(overtakeSpeedAdvantage >= 0f)
        require(wrongWayAngleDeg in 90f..180f)
        require(wrongWayDurationSeconds > 0f)
    }

    fun forDifficulty(difficulty: AiDifficulty): AiConfig = when (difficulty) {
        AiDifficulty.EASY -> copy(
            straightSpeed = straightSpeed * 0.78f,
            cornerSpeed = cornerSpeed * 0.85f,
            steeringResponse = steeringResponse * 0.65f,
            obstacleDetectionDistance = obstacleDetectionDistance * 0.75f,
            avoidanceSteering = avoidanceSteering * 0.75f,
        )
        AiDifficulty.NORMAL -> this
        AiDifficulty.HARD -> copy(
            straightSpeed = straightSpeed * 1.08f,
            cornerSpeed = cornerSpeed * 1.12f,
            steeringResponse = steeringResponse * 1.25f,
            obstacleDetectionDistance = obstacleDetectionDistance * 1.2f,
            overtakeSpeedAdvantage = overtakeSpeedAdvantage * 0.75f,
        )
    }
}

enum class AiDifficulty { EASY, NORMAL, HARD }
