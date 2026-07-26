package com.example.toyracers.ai

import com.example.toyracers.car.CarState
import com.example.toyracers.input.PlayerInput
import com.example.toyracers.track.TrackPoint
import kotlin.math.abs
import kotlin.math.atan2

/**
 * Produces ordinary car input while following a closed racing line.
 *
 * The driver never changes simulation state directly, so AI cars obey the same physics as the
 * player.
 */
class AiDriver(
    private val racingLine: List<TrackPoint>,
    initialPosition: TrackPoint,
    private val config: AiConfig = AiConfig(),
) {
    var targetWaypointIndex: Int
        private set

    private var stuckTime = 0f
    private var recoveryTimeRemaining = 0f

    init {
        require(racingLine.size >= MIN_RACING_LINE_POINTS) {
            "Racing line must contain at least $MIN_RACING_LINE_POINTS points"
        }
        targetWaypointIndex = waypointAfterNearest(initialPosition)
    }

    fun reset(position: TrackPoint) {
        targetWaypointIndex = waypointAfterNearest(position)
        stuckTime = 0f
        recoveryTimeRemaining = 0f
    }

    fun update(
        carState: CarState,
        deltaSeconds: Float,
    ): PlayerInput {
        require(deltaSeconds >= 0f) { "Delta time must not be negative" }
        advanceReachedWaypoints(carState)

        if (recoveryTimeRemaining > 0f) {
            recoveryTimeRemaining = (recoveryTimeRemaining - deltaSeconds).coerceAtLeast(0f)
            return recoveryInput(carState)
        }

        if (abs(carState.speed) < config.stuckSpeed) {
            stuckTime += deltaSeconds
            if (stuckTime >= config.stuckDurationSeconds) {
                stuckTime = 0f
                recoveryTimeRemaining = config.recoveryDurationSeconds
                return recoveryInput(carState)
            }
        } else {
            stuckTime = 0f
        }

        val headingError = headingErrorDegrees(carState, racingLine[targetWaypointIndex])
        val steering = (-headingError / config.fullSteeringAngleDeg).coerceIn(-1f, 1f)
        val turnAhead = turnAheadDegrees(carState)
        val cornerAmount =
            (maxOf(abs(headingError), turnAhead) / RIGHT_ANGLE_DEGREES).coerceIn(0f, 1f)
        val desiredSpeed =
            config.straightSpeed + (config.cornerSpeed - config.straightSpeed) * cornerAmount
        val shouldBrake = carState.speed > desiredSpeed + config.brakingMargin

        return PlayerInput(
            throttle = if (shouldBrake) 0f else 1f,
            brake = if (shouldBrake) 1f else 0f,
            steering = steering,
        )
    }

    private fun recoveryInput(carState: CarState): PlayerInput {
        val headingError = headingErrorDegrees(carState, racingLine[targetWaypointIndex])
        val steering = (-headingError / config.fullSteeringAngleDeg).coerceIn(-1f, 1f)
        return PlayerInput(brake = 1f, steering = steering)
    }

    private fun advanceReachedWaypoints(carState: CarState) {
        var checkedWaypoints = 0
        while (
            checkedWaypoints < racingLine.size &&
            distanceSquared(carState.x, carState.y, racingLine[targetWaypointIndex]) <=
            config.waypointRadius * config.waypointRadius
        ) {
            targetWaypointIndex = (targetWaypointIndex + 1) % racingLine.size
            checkedWaypoints++
        }
    }

    private fun waypointAfterNearest(position: TrackPoint): Int {
        val nearestIndex = racingLine.indices.minByOrNull {
            distanceSquared(position.x, position.y, racingLine[it])
        } ?: 0
        return (nearestIndex + 1) % racingLine.size
    }

    private fun headingErrorDegrees(
        carState: CarState,
        target: TrackPoint,
    ): Float {
        val targetAngle = Math.toDegrees(
            atan2(
                (target.y - carState.y).toDouble(),
                (target.x - carState.x).toDouble(),
            ),
        ).toFloat()
        return normalizeSignedDegrees(targetAngle - carState.rotationDeg)
    }

    private fun turnAheadDegrees(carState: CarState): Float {
        val target = racingLine[targetWaypointIndex]
        val next = racingLine[(targetWaypointIndex + 1) % racingLine.size]
        val approachAngle = Math.toDegrees(
            atan2(
                (target.y - carState.y).toDouble(),
                (target.x - carState.x).toDouble(),
            ),
        ).toFloat()
        val exitAngle = Math.toDegrees(
            atan2(
                (next.y - target.y).toDouble(),
                (next.x - target.x).toDouble(),
            ),
        ).toFloat()
        return abs(normalizeSignedDegrees(exitAngle - approachAngle))
    }

    private fun normalizeSignedDegrees(degrees: Float): Float {
        val wrapped = (degrees + HALF_CIRCLE_DEGREES) % FULL_CIRCLE_DEGREES
        val positive = if (wrapped < 0f) wrapped + FULL_CIRCLE_DEGREES else wrapped
        return positive - HALF_CIRCLE_DEGREES
    }

    private fun distanceSquared(
        x: Float,
        y: Float,
        point: TrackPoint,
    ): Float {
        val deltaX = point.x - x
        val deltaY = point.y - y
        return deltaX * deltaX + deltaY * deltaY
    }

    private companion object {
        const val MIN_RACING_LINE_POINTS = 3
        const val RIGHT_ANGLE_DEGREES = 90f
        const val HALF_CIRCLE_DEGREES = 180f
        const val FULL_CIRCLE_DEGREES = 360f
    }
}
