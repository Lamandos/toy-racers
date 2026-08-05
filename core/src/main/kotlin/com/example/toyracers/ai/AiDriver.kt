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

        val routeSteering = (-headingError / config.fullSteeringAngleDeg).coerceIn(-1f, 1f)
        val obstacleDecision = obstacleDecision(carState, obstacles, rays)
        behaviorState = obstacleDecision.behaviorState
        val steering = steeringDecision(routeSteering, obstacleDecision, deltaSeconds)
        val shouldBrake = shouldBrake(carState, headingError, obstacleDecision)
        return publish(
            carState,
            PlayerInput(
                throttle = if (shouldBrake) 0f else 1f,
                brake = if (shouldBrake) 1f else 0f,
                steering = steering,
            ),
            target,
            obstacleDecision.movingObstacle,
            rays,
        )
    }

    private fun obstacleDecision(
        carState: CarState,
        obstacles: List<AiObstacle>,
        rays: List<AiSensorRay>,
    ): ObstacleDecision {
        val movingObstacle = obstacleDetector.nearestAhead(carState, obstacles)
        val staticThreat = rays.asSequence()
            .filter { it.hit && it.distance() <= config.staticObstacleReactionDistance }
            .minByOrNull(AiSensorRay::distance)
        val passingDirection = movingObstacle?.let {
            safestPassingDirection(carState, obstacles, rays, it)
        }
        val canOvertake = movingObstacle != null && passingDirection != null &&
            movingObstacle.obstacle.speed + config.overtakeSpeedAdvantage < carState.speed
        val behavior = when {
            canOvertake -> AiBehaviorState.OVERTAKE
            movingObstacle != null || staticThreat != null -> AiBehaviorState.AVOID
            else -> AiBehaviorState.FOLLOW_ROUTE
        }
        return ObstacleDecision(movingObstacle, staticThreat, passingDirection, behavior, rays)
    }

    private fun steeringDecision(
        routeSteering: Float,
        obstacleDecision: ObstacleDecision,
        deltaSeconds: Float,
    ): Float {
        updateMistake(deltaSeconds)
        val routeContribution = if (
            obstacleDecision.staticThreat != null && abs(routeSteering) < config.routeTurnPriority
        ) 0f else routeSteering
        val dynamicAvoidance = obstacleDecision.passingDirection
            ?.times(config.avoidanceSteering) ?: 0f
        val staticAvoidance = obstacleDecision.staticThreat?.let {
            safestTrackDirection(obstacleDecision.rays) * config.avoidanceSteering
        } ?: 0f
        val mistakeSteering = if (mistakeTimeRemaining > 0f) config.mistakeSteering else 0f
        val desired = (routeContribution + dynamicAvoidance + staticAvoidance + mistakeSteering)
            .coerceIn(-1f, 1f)
        val blend = (config.steeringResponse * deltaSeconds).coerceIn(0f, 1f)
        smoothedSteering += (desired - smoothedSteering) * blend
        return smoothedSteering
    }

    private fun shouldBrake(
        carState: CarState,
        headingError: Float,
        obstacleDecision: ObstacleDecision,
    ): Boolean {
        val cornerAmount = (maxOf(abs(headingError), pathFollower.turnAheadDegrees(carState)) / 90f)
            .coerceIn(0f, 1f)
        val desiredSpeed = config.straightSpeed +
            (config.cornerSpeed - config.straightSpeed) * cornerAmount
        val safeSpeed = obstacleDecision.distance?.let { distance ->
            val proximity = 1f - distance / config.obstacleDetectionDistance
            desiredSpeed * (1f - proximity.coerceIn(0f, 1f) * config.obstacleSpeedReduction)
        } ?: desiredSpeed
        return carState.speed > safeSpeed + config.brakingMargin
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

    private fun safestPassingDirection(
        carState: CarState,
        obstacles: List<AiObstacle>,
        rays: List<AiSensorRay>,
        detected: DetectedObstacle,
    ): Float? {
        val preferred = when {
            detected.lateralDistance > 0f -> 1f
            detected.lateralDistance < 0f -> -1f
            else -> -racingLineBias.nonZeroSign()
        }
        val candidates = listOf(preferred, -preferred).map { direction ->
            direction to minOf(
                obstacleDetector.passingClearance(carState, obstacles, direction),
                trackClearance(rays, direction),
            )
        }
        return candidates.maxByOrNull { it.second }?.takeIf {
            it.second >= config.overtakeMinimumClearance
        }?.first
    }

    private fun safestTrackDirection(rays: List<AiSensorRay>): Float {
        val leftClearance = trackClearance(rays, -1f)
        val rightClearance = trackClearance(rays, 1f)
        return if (leftClearance >= rightClearance) -1f else 1f
    }

    private fun trackClearance(rays: List<AiSensorRay>, steeringDirection: Float): Float {
        val wantedAngleSign = if (steeringDirection < 0f) 1 else -1
        return rays.firstOrNull { ray -> ray.angleOffsetDeg.sign() == wantedAngleSign }
            ?.distance() ?: config.obstacleDetectionDistance
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

    private fun Float.sign(): Int = when {
        this < 0f -> -1
        this > 0f -> 1
        else -> 0
    }

    private data class ObstacleDecision(
        val movingObstacle: DetectedObstacle?,
        val staticThreat: AiSensorRay?,
        val passingDirection: Float?,
        val behaviorState: AiBehaviorState,
        val rays: List<AiSensorRay>,
    ) {
        val distance: Float?
            get() = movingObstacle?.forwardDistance ?: staticThreat?.distance()
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
