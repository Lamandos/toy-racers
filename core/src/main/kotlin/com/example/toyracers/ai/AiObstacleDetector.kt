package com.example.toyracers.ai

import com.example.toyracers.car.CarState
import kotlin.math.cos
import kotlin.math.sin

/** Lightweight, allocation-free-in-the-hot-loop obstacle query for AI cars. */
class AiObstacleDetector(private val config: AiConfig) {
    fun nearestAhead(carState: CarState, obstacles: List<AiObstacle>): DetectedObstacle? {
        val radians = Math.toRadians(carState.rotationDeg.toDouble())
        val forwardX = cos(radians).toFloat()
        val forwardY = sin(radians).toFloat()
        val rightX = -forwardY
        val rightY = forwardX

        var nearest: DetectedObstacle? = null
        obstacles.forEach { obstacle ->
            val deltaX = obstacle.x - carState.x
            val deltaY = obstacle.y - carState.y
            val forwardDistance = deltaX * forwardX + deltaY * forwardY
            val lateralDistance = deltaX * rightX + deltaY * rightY
            val laneWidth = config.obstacleLaneHalfWidth + obstacle.radius
            if (
                forwardDistance in 0f..config.obstacleDetectionDistance &&
                kotlin.math.abs(lateralDistance) <= laneWidth &&
                (nearest == null || forwardDistance < nearest!!.forwardDistance)
            ) {
                nearest = DetectedObstacle(obstacle, forwardDistance, lateralDistance)
            }
        }
        return nearest
    }
}

data class AiObstacle(
    val x: Float,
    val y: Float,
    val radius: Float,
    val speed: Float = 0f,
)

data class DetectedObstacle(
    val obstacle: AiObstacle,
    val forwardDistance: Float,
    val lateralDistance: Float,
)
