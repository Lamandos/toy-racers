package com.example.toyracers.race

import com.example.toyracers.track.StartLine
import com.example.toyracers.track.Track
import com.example.toyracers.track.TrackPoint
import com.example.toyracers.track.TrackSegment
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Advances ordered checkpoint, lap, and timing state from a car's simulated movement.
 *
 * Callers can suppress progression for teleports and respawns while still advancing race time.
 */
class RaceRules(
    private val track: Track,
    val requiredLaps: Int = DEFAULT_LAP_COUNT,
) {
    private var nextFinishPosition = 1

    init {
        require(requiredLaps > 0) { "Required lap count must be positive" }
    }

    fun update(
        progress: RaceProgress,
        previousPosition: TrackPoint,
        currentPosition: TrackPoint,
        deltaSeconds: Float,
        allowProgress: Boolean = true,
    ) {
        require(deltaSeconds >= 0f) { "Delta time must not be negative" }
        if (progress.finished) return

        progress.totalRaceTime += deltaSeconds
        if (!allowProgress) return

        if (progress.currentCheckpointIndex < track.checkpoints.size) {
            val checkpoint = track.checkpoints[progress.currentCheckpointIndex]
            if (
                crossesForward(
                    previousPosition,
                    currentPosition,
                    checkpoint.gate,
                    checkpoint.forwardX,
                    checkpoint.forwardY,
                )
            ) {
                progress.currentCheckpointIndex++
            }
            return
        }

        if (!crossesForward(previousPosition, currentPosition, track.startLine)) return

        progress.completedLaps++
        val lapTime = progress.totalRaceTime - progress.lapStartTime
        progress.bestLapTime = progress.bestLapTime?.let { minOf(it, lapTime) } ?: lapTime
        progress.lapStartTime = progress.totalRaceTime
        progress.currentCheckpointIndex = 0

        if (progress.completedLaps >= requiredLaps) {
            progress.finished = true
            progress.finishPosition = nextFinishPosition++
        }
    }

    private fun crossesForward(
        previous: TrackPoint,
        current: TrackPoint,
        startLine: StartLine,
    ): Boolean {
        val centerX = startLine.bounds.x + startLine.bounds.width / 2f
        val centerY = startLine.bounds.y + startLine.bounds.height / 2f
        val forwardLength = vectorLength(startLine.forwardX, startLine.forwardY)
        val perpendicularX = -startLine.forwardY / forwardLength
        val perpendicularY = startLine.forwardX / forwardLength
        val halfLength =
            abs(perpendicularX) * startLine.bounds.width / 2f +
                abs(perpendicularY) * startLine.bounds.height / 2f
        val gate = TrackSegment(
            start = TrackPoint(
                centerX - perpendicularX * halfLength,
                centerY - perpendicularY * halfLength,
            ),
            end = TrackPoint(
                centerX + perpendicularX * halfLength,
                centerY + perpendicularY * halfLength,
            ),
        )
        return crossesForward(
            previous,
            current,
            gate,
            startLine.forwardX,
            startLine.forwardY,
        )
    }

    private fun crossesForward(
        previous: TrackPoint,
        current: TrackPoint,
        gate: TrackSegment,
        forwardX: Float,
        forwardY: Float,
    ): Boolean {
        val forwardLength = vectorLength(forwardX, forwardY)
        val normalX = forwardX / forwardLength
        val normalY = forwardY / forwardLength
        val previousDistance =
            (previous.x - gate.start.x) * normalX +
                (previous.y - gate.start.y) * normalY
        val currentDistance =
            (current.x - gate.start.x) * normalX +
                (current.y - gate.start.y) * normalY
        if (previousDistance >= -CROSSING_EPSILON || currentDistance < -CROSSING_EPSILON) {
            return false
        }

        val movementX = current.x - previous.x
        val movementY = current.y - previous.y
        if (movementX * normalX + movementY * normalY <= CROSSING_EPSILON) return false

        val crossingFraction = previousDistance / (previousDistance - currentDistance)
        val crossingX = previous.x + movementX * crossingFraction
        val crossingY = previous.y + movementY * crossingFraction
        val gateX = gate.end.x - gate.start.x
        val gateY = gate.end.y - gate.start.y
        val gateLengthSquared = gateX * gateX + gateY * gateY
        val gateFraction =
            ((crossingX - gate.start.x) * gateX + (crossingY - gate.start.y) * gateY) /
                gateLengthSquared
        return gateFraction in -CROSSING_EPSILON..(1f + CROSSING_EPSILON)
    }

    private fun vectorLength(
        x: Float,
        y: Float,
    ): Float = sqrt(x * x + y * y)

    companion object {
        const val DEFAULT_LAP_COUNT = 3
        private const val CROSSING_EPSILON = 0.0001f
    }
}
