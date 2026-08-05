package com.example.toyracers.ai

import com.example.toyracers.car.CarState
import com.example.toyracers.input.PlayerInput
import com.example.toyracers.track.TrackPoint
import kotlin.math.abs
import kotlin.math.atan2

/** Produces ordinary car input while following a closed racing line. */
class AiDriver(
    private val racingLine: List<TrackPoint>,
    initialPosition: TrackPoint,
    config: AiConfig = AiConfig(),
    val difficulty: AiDifficulty = AiDifficulty.NORMAL,
    /** Stable per-car variation: negative prefers left, positive prefers right. */
    private val racingLineBias: Float = 0f,
) {
    private val config = config.forDifficulty(difficulty)
    private val obstacleDetector = AiObstacleDetector(this.config)
    private val recoveryController = AiRecoveryController(this.config)
    private var smoothedSteering = 0f

    var targetWaypointIndex: Int
        private set

    var behaviorState: AiBehaviorState = AiBehaviorState.FOLLOW_ROUTE
        private set

    var debugSnapshot: AiDebugSnapshot? = null
        private set

    init {
        require(racingLine.size >= MIN_RACING_LINE_POINTS) {
            "Racing line must contain at least $MIN_RACING_LINE_POINTS points"
        }
        require(racingLineBias in -1f..1f) { "Racing line bias must be normalized" }
        targetWaypointIndex = waypointAfterNearest(initialPosition)
    }

    fun reset(position: TrackPoint) {
        targetWaypointIndex = waypointAfterNearest(position)
        recoveryController.reset()
        smoothedSteering = 0f
        behaviorState = AiBehaviorState.FOLLOW_ROUTE
        debugSnapshot = null
    }

    fun update(
        carState: CarState,
        deltaSeconds: Float,
        obstacles: List<AiObstacle> = emptyList(),
        finished: Boolean = false,
    ): PlayerInput {
        require(deltaSeconds >= 0f) { "Delta time must not be negative" }
        advanceReachedWaypoints(carState)
        if (finished) {
            behaviorState = AiBehaviorState.FINISHED
            return publish(PlayerInput(brake = 1f), targetPoint(), null)
        }

        val target = targetPoint()
        val headingError = headingErrorDegrees(carState, target)
        if (recoveryController.update(carState, headingError, deltaSeconds)) {
            behaviorState = AiBehaviorState.RECOVER
            val recoverySteering = (-headingError / config.fullSteeringAngleDeg).coerceIn(-1f, 1f)
            return publish(PlayerInput(brake = 1f, steering = recoverySteering), target, null)
        }

        val obstacle = obstacleDetector.nearestAhead(carState, obstacles)
        val routeSteering = (-headingError / config.fullSteeringAngleDeg).coerceIn(-1f, 1f)
        val obstacleSteering = obstacle?.let {
            val preferredSide = if (it.lateralDistance == 0f) racingLineBias.nonZeroSign() else {
                -it.lateralDistance.nonZeroSign()
            }
            preferredSide * config.avoidanceSteering
        } ?: 0f
        behaviorState = when {
            obstacle == null -> AiBehaviorState.FOLLOW_ROUTE
            obstacle.obstacle.speed + config.overtakeSpeedAdvantage < carState.speed ->
                AiBehaviorState.OVERTAKE
            else -> AiBehaviorState.AVOID
        }

        val desiredSteering = (routeSteering + obstacleSteering).coerceIn(-1f, 1f)
        val steeringBlend = (config.steeringResponse * deltaSeconds).coerceIn(0f, 1f)
        smoothedSteering += (desiredSteering - smoothedSteering) * steeringBlend

        val cornerAmount = (
            maxOf(abs(headingError), turnAheadDegrees(carState)) / RIGHT_ANGLE_DEGREES
        ).coerceIn(0f, 1f)
        val desiredSpeed = config.straightSpeed +
            (config.cornerSpeed - config.straightSpeed) * cornerAmount
        val obstacleSpeed = obstacle?.let {
            val proximity = 1f - it.forwardDistance / config.obstacleDetectionDistance
            desiredSpeed * (1f - proximity.coerceIn(0f, 1f) * OBSTACLE_SPEED_REDUCTION)
        } ?: desiredSpeed
        val shouldBrake = carState.speed > obstacleSpeed + config.brakingMargin
        return publish(
            PlayerInput(
                throttle = if (shouldBrake) 0f else 1f,
                brake = if (shouldBrake) 1f else 0f,
                steering = smoothedSteering,
            ),
            target,
            obstacle,
        )
    }

    private fun publish(
        input: PlayerInput,
        target: TrackPoint,
        obstacle: DetectedObstacle?,
    ): PlayerInput = input.normalized().also {
        debugSnapshot = AiDebugSnapshot(target, behaviorState, obstacle, it)
    }

    private fun targetPoint(): TrackPoint {
        val lookAheadIndex = (targetWaypointIndex + config.lookAheadPoints - 1) % racingLine.size
        val point = racingLine[lookAheadIndex]
        if (racingLineBias == 0f) return point
        val next = racingLine[(lookAheadIndex + 1) % racingLine.size]
        val deltaX = next.x - point.x
        val deltaY = next.y - point.y
        val length = kotlin.math.sqrt(deltaX * deltaX + deltaY * deltaY)
        if (length == 0f) return point
        return TrackPoint(
            point.x - deltaY / length * racingLineBias * LINE_BIAS_WORLD_UNITS,
            point.y + deltaX / length * racingLineBias * LINE_BIAS_WORLD_UNITS,
        )
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

    private fun headingErrorDegrees(carState: CarState, target: TrackPoint): Float {
        val targetAngle = Math.toDegrees(
            atan2((target.y - carState.y).toDouble(), (target.x - carState.x).toDouble()),
        ).toFloat()
        return normalizeSignedDegrees(targetAngle - carState.rotationDeg)
    }

    private fun turnAheadDegrees(carState: CarState): Float {
        val target = racingLine[targetWaypointIndex]
        val next = racingLine[(targetWaypointIndex + config.lookAheadPoints) % racingLine.size]
        val approachAngle = Math.toDegrees(
            atan2((target.y - carState.y).toDouble(), (target.x - carState.x).toDouble()),
        ).toFloat()
        val exitAngle = Math.toDegrees(
            atan2((next.y - target.y).toDouble(), (next.x - target.x).toDouble()),
        ).toFloat()
        return abs(normalizeSignedDegrees(exitAngle - approachAngle))
    }

    private fun normalizeSignedDegrees(degrees: Float): Float {
        val wrapped = (degrees + HALF_CIRCLE_DEGREES) % FULL_CIRCLE_DEGREES
        val positive = if (wrapped < 0f) wrapped + FULL_CIRCLE_DEGREES else wrapped
        return positive - HALF_CIRCLE_DEGREES
    }

    private fun distanceSquared(x: Float, y: Float, point: TrackPoint): Float {
        val deltaX = point.x - x
        val deltaY = point.y - y
        return deltaX * deltaX + deltaY * deltaY
    }

    private fun Float.nonZeroSign(): Float = if (this < 0f) -1f else 1f

    private companion object {
        const val MIN_RACING_LINE_POINTS = 3
        const val RIGHT_ANGLE_DEGREES = 90f
        const val HALF_CIRCLE_DEGREES = 180f
        const val FULL_CIRCLE_DEGREES = 360f
        const val LINE_BIAS_WORLD_UNITS = 0.45f
        const val OBSTACLE_SPEED_REDUCTION = 0.65f
    }
}

enum class AiBehaviorState { FOLLOW_ROUTE, AVOID, OVERTAKE, RECOVER, FINISHED }

data class AiDebugSnapshot(
    val targetPoint: TrackPoint,
    val behaviorState: AiBehaviorState,
    val detectedObstacle: DetectedObstacle?,
    val input: PlayerInput,
)
