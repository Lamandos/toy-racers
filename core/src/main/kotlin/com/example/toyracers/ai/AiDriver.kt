package com.example.toyracers.ai

import com.example.toyracers.car.CarState
import com.example.toyracers.input.PlayerInput
import com.example.toyracers.track.Track
import com.example.toyracers.track.TrackPoint
import kotlin.math.abs

/** Coordinates path, obstacle, recovery and difficulty decisions without mutating car state. */
class AiDriver(
    racingLine: List<TrackPoint>,
    initialPosition: TrackPoint,
    config: AiConfig = AiConfig(),
    val difficulty: AiDifficulty = AiDifficulty.NORMAL,
    private val racingLineBias: Float = 0f,
    private val track: Track? = null,
) {
    private val config = config.forDifficulty(difficulty)
    private val pathFollower = AiPathFollower(racingLine, initialPosition, this.config, racingLineBias)
    private val obstacleDetector = AiObstacleDetector(this.config)
    private val recoveryController = AiRecoveryController(this.config)
    private var smoothedSteering = 0f
    private var mistakeCheckAccumulator = 0f
    private var mistakeTimeRemaining = 0f
    private var randomState = initialPosition.x.toBits() xor initialPosition.y.toBits() xor
        racingLineBias.toBits()

    var behaviorState: AiBehaviorState = AiBehaviorState.FOLLOW_ROUTE
        private set
    var debugSnapshot: AiDebugSnapshot? = null
        private set
    var respawnRequested: Boolean = false
        private set

    val targetWaypointIndex: Int
        get() = pathFollower.targetWaypointIndex

    init {
        require(racingLine.size >= 3) { "Racing line must contain at least 3 points" }
        require(racingLineBias in -1f..1f) { "Racing line bias must be normalized" }
    }

    fun reset(position: TrackPoint) {
        pathFollower.reset(position)
        recoveryController.reset()
        smoothedSteering = 0f
        respawnRequested = false
        behaviorState = AiBehaviorState.FOLLOW_ROUTE
        debugSnapshot = null
    }

    fun consumeRespawnRequest(): Boolean = respawnRequested.also { respawnRequested = false }

    fun update(
        carState: CarState,
        deltaSeconds: Float,
        obstacles: List<AiObstacle> = emptyList(),
        finished: Boolean = false,
        isOnTrack: Boolean = true,
    ): PlayerInput {
        require(deltaSeconds >= 0f) { "Delta time must not be negative" }
        pathFollower.update(TrackPoint(carState.x, carState.y))
        val target = pathFollower.target()
        val rays = obstacleDetector.scanTrack(carState, track)
        if (finished) {
            if (!isOnTrack) respawnRequested = true
            behaviorState = AiBehaviorState.FINISHED
            return publish(carState, PlayerInput(brake = 1f), target, null, rays)
        }

        val headingError = pathFollower.headingError(carState, target)
        when (recoveryController.update(carState, headingError, isOnTrack, deltaSeconds)) {
            AiRecoveryAction.REVERSE -> {
                behaviorState = AiBehaviorState.RECOVER
                val steering = (-headingError / config.fullSteeringAngleDeg).coerceIn(-1f, 1f)
                return publish(carState, PlayerInput(brake = 1f, steering = steering), target, null, rays)
            }
            AiRecoveryAction.RESPAWN -> {
                respawnRequested = true
                behaviorState = AiBehaviorState.RECOVER
                return publish(carState, PlayerInput.NONE, target, null, rays)
            }
            AiRecoveryAction.NONE -> Unit
        }

        val movingObstacle = obstacleDetector.nearestAhead(carState, obstacles)
        val immediateObstacleDistance = config.obstacleLaneHalfWidth
        val blockedRay = rays.filter { ray ->
            ray.hit && ray.distanceSquared() <= immediateObstacleDistance * immediateObstacleDistance
        }.minByOrNull { ray ->
            val dx = ray.end.x - ray.start.x
            val dy = ray.end.y - ray.start.y
            dx * dx + dy * dy
        }
        val routeSteering = (-headingError / config.fullSteeringAngleDeg).coerceIn(-1f, 1f)
        val dynamicAvoidance = movingObstacle?.let {
            val side = if (it.lateralDistance == 0f) racingLineBias.nonZeroSign()
            else -it.lateralDistance.nonZeroSign()
            side * config.avoidanceSteering
        } ?: 0f
        val staticThreat = blockedRay?.takeIf { abs(routeSteering) < config.routeTurnPriority }
        val staticAvoidance = staticThreat?.let {
            -it.angleOffsetDeg.nonZeroSign() * config.avoidanceSteering
        } ?: 0f
        behaviorState = when {
            movingObstacle?.obstacle?.speed?.plus(config.overtakeSpeedAdvantage) != null &&
                movingObstacle.obstacle.speed + config.overtakeSpeedAdvantage < carState.speed ->
                AiBehaviorState.OVERTAKE
            movingObstacle != null || staticThreat != null -> AiBehaviorState.AVOID
            else -> AiBehaviorState.FOLLOW_ROUTE
        }

        updateMistake(deltaSeconds)
        val mistakeSteering = if (mistakeTimeRemaining > 0f) config.mistakeSteering else 0f
        val desiredSteering = (routeSteering + dynamicAvoidance + staticAvoidance + mistakeSteering)
            .coerceIn(-1f, 1f)
        val blend = (config.steeringResponse * deltaSeconds).coerceIn(0f, 1f)
        smoothedSteering += (desiredSteering - smoothedSteering) * blend

        val cornerAmount = (maxOf(abs(headingError), pathFollower.turnAheadDegrees(carState)) / 90f)
            .coerceIn(0f, 1f)
        val desiredSpeed = config.straightSpeed +
            (config.cornerSpeed - config.straightSpeed) * cornerAmount
        val obstacleDistance = movingObstacle?.forwardDistance ?: if (staticThreat != null) {
            val dx = staticThreat.end.x - staticThreat.start.x
            val dy = staticThreat.end.y - staticThreat.start.y
            kotlin.math.sqrt(dx * dx + dy * dy)
        } else null
        val safeSpeed = obstacleDistance?.let {
            val proximity = 1f - it / config.obstacleDetectionDistance
            desiredSpeed * (1f - proximity.coerceIn(0f, 1f) * config.obstacleSpeedReduction)
        } ?: desiredSpeed
        val shouldBrake = carState.speed > safeSpeed + config.brakingMargin
        return publish(
            carState,
            PlayerInput(
                throttle = if (shouldBrake) 0f else 1f,
                brake = if (shouldBrake) 1f else 0f,
                steering = smoothedSteering,
            ),
            target,
            movingObstacle,
            rays,
        )
    }

    private fun updateMistake(deltaSeconds: Float) {
        mistakeTimeRemaining = (mistakeTimeRemaining - deltaSeconds).coerceAtLeast(0f)
        mistakeCheckAccumulator += deltaSeconds
        while (mistakeCheckAccumulator >= config.mistakeCheckIntervalSeconds) {
            mistakeCheckAccumulator -= config.mistakeCheckIntervalSeconds
            randomState = randomState * 1664525 + 1013904223
            val sample = (randomState ushr 8).toFloat() / 0x01000000
            if (sample < config.mistakeProbability) mistakeTimeRemaining = config.mistakeDurationSeconds
        }
    }

    private fun publish(
        carState: CarState,
        input: PlayerInput,
        target: TrackPoint,
        obstacle: DetectedObstacle?,
        rays: List<AiSensorRay>,
    ): PlayerInput = input.normalized().also {
        debugSnapshot = AiDebugSnapshot(
            position = TrackPoint(carState.x, carState.y),
            speed = carState.speed,
            targetPoint = target,
            behaviorState = behaviorState,
            detectedObstacle = obstacle,
            sensorRays = rays,
            input = it,
        )
    }

    private fun Float.nonZeroSign(): Float = if (this < 0f) -1f else 1f

    private fun AiSensorRay.distanceSquared(): Float {
        val dx = end.x - start.x
        val dy = end.y - start.y
        return dx * dx + dy * dy
    }

}

enum class AiBehaviorState { FOLLOW_ROUTE, AVOID, OVERTAKE, RECOVER, FINISHED }

data class AiDebugSnapshot(
    val position: TrackPoint,
    val speed: Float,
    val targetPoint: TrackPoint,
    val behaviorState: AiBehaviorState,
    val detectedObstacle: DetectedObstacle?,
    val sensorRays: List<AiSensorRay>,
    val input: PlayerInput,
)
