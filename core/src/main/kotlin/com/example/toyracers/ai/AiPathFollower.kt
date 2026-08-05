package com.example.toyracers.ai

import com.example.toyracers.car.CarState
import com.example.toyracers.track.TrackPoint
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.sqrt

/** Owns waypoint progression, look-ahead targeting and racing-line variation. */
class AiPathFollower(
    private val racingLine: List<TrackPoint>,
    initialPosition: TrackPoint,
    private val config: AiConfig,
    private val racingLineBias: Float,
) {
    var targetWaypointIndex: Int = waypointAfterNearest(initialPosition)
        private set

    fun reset(position: TrackPoint) { targetWaypointIndex = waypointAfterNearest(position) }

    fun update(position: TrackPoint) {
        var checked = 0
        while (checked < racingLine.size && distanceSquared(position, racingLine[targetWaypointIndex]) <= config.waypointRadius * config.waypointRadius) {
            targetWaypointIndex = (targetWaypointIndex + 1) % racingLine.size
            checked++
        }
    }

    fun target(): TrackPoint {
        val index = (targetWaypointIndex + config.lookAheadPoints - 1) % racingLine.size
        val point = racingLine[index]
        if (racingLineBias == 0f) return point
        val next = racingLine[(index + 1) % racingLine.size]
        val dx = next.x - point.x
        val dy = next.y - point.y
        val length = sqrt(dx * dx + dy * dy)
        if (length == 0f) return point
        return TrackPoint(
            point.x - dy / length * racingLineBias * config.racingLineBiasDistance,
            point.y + dx / length * racingLineBias * config.racingLineBiasDistance,
        )
    }

    fun headingError(carState: CarState, target: TrackPoint = target()): Float {
        val angle = Math.toDegrees(atan2((target.y - carState.y).toDouble(), (target.x - carState.x).toDouble())).toFloat()
        return normalizeSignedDegrees(angle - carState.rotationDeg)
    }

    fun turnAheadDegrees(carState: CarState): Float {
        val target = racingLine[targetWaypointIndex]
        val next = racingLine[(targetWaypointIndex + config.lookAheadPoints) % racingLine.size]
        val approach = Math.toDegrees(atan2((target.y - carState.y).toDouble(), (target.x - carState.x).toDouble())).toFloat()
        val exit = Math.toDegrees(atan2((next.y - target.y).toDouble(), (next.x - target.x).toDouble())).toFloat()
        return abs(normalizeSignedDegrees(exit - approach))
    }

    private fun waypointAfterNearest(position: TrackPoint): Int =
        ((racingLine.indices.minByOrNull { distanceSquared(position, racingLine[it]) } ?: 0) + 1) % racingLine.size

    private fun distanceSquared(first: TrackPoint, second: TrackPoint): Float {
        val dx = second.x - first.x
        val dy = second.y - first.y
        return dx * dx + dy * dy
    }

    private fun normalizeSignedDegrees(degrees: Float): Float {
        val wrapped = (degrees + 180f) % 360f
        return (if (wrapped < 0f) wrapped + 360f else wrapped) - 180f
    }
}
