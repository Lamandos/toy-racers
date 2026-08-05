package com.example.toyracers.ai

import com.example.toyracers.car.CarState
import com.example.toyracers.track.Track
import com.example.toyracers.track.TrackCircle
import com.example.toyracers.track.TrackPoint
import com.example.toyracers.track.TrackPolygon
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

    fun scanTrack(carState: CarState, track: Track?): List<AiSensorRay> {
        if (track == null) return emptyList()
        return listOf(-config.sensorRayAngleDeg, 0f, config.sensorRayAngleDeg).map { offset ->
            val radians = Math.toRadians((carState.rotationDeg + offset).toDouble())
            val directionX = cos(radians).toFloat()
            val directionY = sin(radians).toFloat()
            var distance = config.sensorRayStep
            while (distance <= config.obstacleDetectionDistance) {
                val point = TrackPoint(
                    carState.x + directionX * distance,
                    carState.y + directionY * distance,
                )
                if (track.isBlocked(point)) break
                distance += config.sensorRayStep
            }
            AiSensorRay(
                start = TrackPoint(carState.x, carState.y),
                end = TrackPoint(
                    carState.x + directionX * distance.coerceAtMost(config.obstacleDetectionDistance),
                    carState.y + directionY * distance.coerceAtMost(config.obstacleDetectionDistance),
                ),
                hit = distance <= config.obstacleDetectionDistance,
                angleOffsetDeg = offset,
            )
        }
    }

    private fun Track.isBlocked(point: TrackPoint): Boolean {
        if (!worldBounds.contains(point)) return true
        if (innerObstacles.any { it.contains(point) }) return true
        return collisionShapes.any { shape ->
            when (shape) {
                is TrackCircle -> {
                    val dx = point.x - shape.center.x
                    val dy = point.y - shape.center.y
                    dx * dx + dy * dy <= shape.radius * shape.radius
                }
                is TrackPolygon -> shape.contains(point.x, point.y)
            }
        }
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

data class AiSensorRay(
    val start: TrackPoint,
    val end: TrackPoint,
    val hit: Boolean,
    val angleOffsetDeg: Float,
)
