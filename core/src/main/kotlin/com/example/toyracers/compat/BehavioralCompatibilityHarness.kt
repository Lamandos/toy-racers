package com.example.toyracers.compat

import com.example.toyracers.ai.AiDifficulty
import com.example.toyracers.car.CarModel
import com.example.toyracers.car.CarPhysics
import com.example.toyracers.input.PlayerInput
import com.example.toyracers.race.RaceParticipant
import com.example.toyracers.race.RaceSession
import com.example.toyracers.track.TrackId
import com.example.toyracers.track.TrackLoader

/**
 * GPU-free adapter for replaying normalized player input through the reference simulation.
 *
 * It only creates a [RaceSession], injects an explicitly supplied initial state, advances its
 * fixed timestep, and exposes immutable observations. Gameplay rules remain in the existing core.
 */
class BehavioralCompatibilityHarness(
    configuration: BehavioralRaceConfiguration,
) {
    private val track = TrackLoader().load(TrackId.fromValue(configuration.trackId))
    private val session =
        RaceSession(
            track = track,
            playerCarModel = CarModel.valueOf(configuration.playerCar),
            opponentDifficulty = AiDifficulty.valueOf(configuration.opponentDifficulty),
        )
    private val seed = configuration.seed
    private var simulationTicks = 0
    private var lastImpactSpeed = 0f

    /** Starts the normal READY → COUNTDOWN transition. */
    fun start(): BehavioralSnapshot {
        session.start()
        return snapshot()
    }

    /** Advances the countdown without running a physical timestep. */
    fun finishCountdown(): BehavioralSnapshot {
        session.advance(session.raceState.countdownDurationSeconds, PlayerInput.NONE)
        return snapshot()
    }

    /** Applies a fixture-supplied initial state before its first physical tick. */
    fun setInitialStates(states: List<BehavioralInitialState>) {
        val participants = participantsById()
        states.forEach { initial ->
            val participant =
                requireNotNull(participants[initial.id]) {
                    "Unknown compatibility participant: ${initial.id}"
                }
            initial.applyTo(participant)
        }
    }

    /** Advances exactly one fixed simulation tick and returns the observed state. */
    fun advance(input: BehavioralInput): BehavioralSnapshot {
        val result =
            session.advance(
                frameDeltaSeconds = CarPhysics.FIXED_DELTA_SECONDS,
                playerInput = input.toPlayerInput(),
            )
        simulationTicks += result.physicalSteps
        lastImpactSpeed = result.maxImpactSpeed
        return snapshot()
    }

    /** Returns a normalized, rendering-independent observation of the current race state. */
    fun snapshot(): BehavioralSnapshot =
        BehavioralSnapshot(
            seed = seed,
            simulationTicks = simulationTicks,
            phase = session.raceState.phase.name,
            countdownRemainingSeconds = session.raceState.countdownRemainingSeconds,
            playerPosition = session.playerPosition,
            requiredLaps = session.requiredLaps,
            lastImpactSpeed = lastImpactSpeed,
            participants = participants().map(::participantSnapshot),
        )

    private fun participants(): List<RaceParticipant> = listOf(session.player) + session.opponents

    private fun participantsById(): Map<String, RaceParticipant> = participants().associateBy { it.id }

    private fun participantSnapshot(participant: RaceParticipant): BehavioralParticipantSnapshot =
        BehavioralParticipantSnapshot(
            id = participant.id,
            car = participant.carModel.name,
            surface = track.surfaceAt(participant.state.x, participant.state.y).name,
            aiBehavior = participant.driver?.behaviorState?.name,
            x = participant.state.x,
            y = participant.state.y,
            rotationDeg = participant.state.rotationDeg,
            speed = participant.state.speed,
            velocityX = participant.state.velocityX,
            velocityY = participant.state.velocityY,
            angularVelocity = participant.state.angularVelocity,
            lateralSpeed = participant.state.lateralSpeed,
            driftAmount = participant.state.driftAmount,
            surfaceSpeedMultiplier = participant.surfaceSpeedState.speedMultiplier,
            currentCheckpointIndex = participant.progress.currentCheckpointIndex,
            completedLaps = participant.progress.completedLaps,
            totalRaceTime = participant.progress.totalRaceTime,
            bestLapTime = participant.progress.bestLapTime,
            finished = participant.progress.finished,
            finishPosition = participant.progress.finishPosition,
        )
}

/** Stable race options shared by Kotlin's reference runner and a future adapter. */
data class BehavioralRaceConfiguration(
    val seed: Long,
    val trackId: String,
    val playerCar: String,
    val opponentDifficulty: String = AiDifficulty.NORMAL.name,
)

/** Normalized input; keyboard and touch adapters both produce this value. */
data class BehavioralInput(
    val throttle: Float = 0f,
    val brake: Float = 0f,
    val steering: Float = 0f,
) {
    fun toPlayerInput(): PlayerInput =
        PlayerInput(
            throttle = throttle,
            brake = brake,
            steering = steering,
        ).normalized()
}

/** Optional fixture state applied before the replay begins. */
data class BehavioralInitialState(
    val id: String,
    val x: Float? = null,
    val y: Float? = null,
    val rotationDeg: Float? = null,
    val speed: Float? = null,
    val velocityX: Float? = null,
    val velocityY: Float? = null,
    val angularVelocity: Float? = null,
    val lateralSpeed: Float? = null,
    val driftAmount: Float? = null,
    val surfaceSpeedMultiplier: Float? = null,
    val currentCheckpointIndex: Int? = null,
    val completedLaps: Int? = null,
    val totalRaceTime: Float? = null,
    val finished: Boolean? = null,
    val finishPosition: Int? = null,
) {
    internal fun applyTo(participant: RaceParticipant) {
        x?.let { participant.state.x = it }
        y?.let { participant.state.y = it }
        rotationDeg?.let { participant.state.rotationDeg = it }
        speed?.let { participant.state.speed = it }
        velocityX?.let { participant.state.velocityX = it }
        velocityY?.let { participant.state.velocityY = it }
        angularVelocity?.let { participant.state.angularVelocity = it }
        lateralSpeed?.let { participant.state.lateralSpeed = it }
        driftAmount?.let { participant.state.driftAmount = it }
        surfaceSpeedMultiplier?.let { participant.surfaceSpeedState.speedMultiplier = it }
        currentCheckpointIndex?.let { participant.progress.currentCheckpointIndex = it }
        completedLaps?.let { participant.progress.completedLaps = it }
        totalRaceTime?.let { participant.progress.totalRaceTime = it }
        finished?.let { participant.progress.finished = it }
        finishPosition?.let { participant.progress.finishPosition = it }
        participant.captureStateForRendering()
    }
}

/** Versioned normalized state intended for JSON serialization and cross-language comparison. */
data class BehavioralSnapshot(
    val seed: Long,
    val simulationTicks: Int,
    val phase: String,
    val countdownRemainingSeconds: Float,
    val playerPosition: Int,
    val requiredLaps: Int,
    val lastImpactSpeed: Float,
    val participants: List<BehavioralParticipantSnapshot>,
)

/** Rendering-free observation of one race participant. */
data class BehavioralParticipantSnapshot(
    val id: String,
    val car: String,
    val surface: String,
    val aiBehavior: String?,
    val x: Float,
    val y: Float,
    val rotationDeg: Float,
    val speed: Float,
    val velocityX: Float,
    val velocityY: Float,
    val angularVelocity: Float,
    val lateralSpeed: Float,
    val driftAmount: Float,
    val surfaceSpeedMultiplier: Float,
    val currentCheckpointIndex: Int,
    val completedLaps: Int,
    val totalRaceTime: Float,
    val bestLapTime: Float?,
    val finished: Boolean,
    val finishPosition: Int?,
)
