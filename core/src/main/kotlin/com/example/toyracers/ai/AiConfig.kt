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
    }
}
