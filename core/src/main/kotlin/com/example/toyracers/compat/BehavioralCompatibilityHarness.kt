package com.example.toyracers.compat

import com.example.toyracers.ai.AiDifficulty
import com.example.toyracers.car.CarModel
import com.example.toyracers.car.CarPhysics
import com.example.toyracers.input.PlayerInput
import com.example.toyracers.race.RaceParticipant
import com.example.toyracers.race.RacePhase
import com.example.toyracers.race.RaceSession
import com.example.toyracers.track.SurfaceType
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
            playerCarModel = CarModel.fromScenarioId(configuration.playerCar),
            opponentDifficulty = difficultyFromId(configuration.opponentDifficulty),
        )
    private var simulationTicks = 0

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
        session.synchronizeFinishOrdering()
    }

    /** Advances exactly one fixed simulation tick and returns the observed state. */
    fun advance(input: BehavioralInput): BehavioralSnapshot {
        val result =
            session.advance(
                frameDeltaSeconds = CarPhysics.FIXED_DELTA_SECONDS,
                playerInput = input.toPlayerInput(),
            )
        simulationTicks += result.physicalSteps
        return snapshot()
    }

    /** Returns a normalized, rendering-independent observation of the current race state. */
    fun snapshot(): BehavioralSnapshot {
        val positions = session.participantPositions
        val participantSnapshots =
            participants()
                .sortedBy(RaceParticipant::id)
                .map { participant -> participantSnapshot(participant, positions.getValue(participant.id)) }
        val finishResults =
            participants()
                .filter { it.progress.finished }
                .sortedWith(
                    compareBy<RaceParticipant> { it.progress.finishPosition }.thenBy(RaceParticipant::id),
                ).map(::finishResultSnapshot)
        return BehavioralSnapshot(
            schemaVersion = BehavioralSnapshotSchema.VERSION,
            simulationTick = simulationTicks,
            raceState = phaseId(session.raceState.phase),
            countdown = countdownSnapshot(),
            elapsedSimulationTime = simulationTicks * CarPhysics.FIXED_DELTA_SECONDS,
            currentLap = currentLap(session.player),
            currentProgress = progressSnapshot(session.player),
            participants = participantSnapshots,
            ranking =
                participantSnapshots
                    .sortedWith(
                        compareBy<BehavioralParticipantSnapshot> { it.racePosition }
                            .thenBy(BehavioralParticipantSnapshot::id),
                    ).map(BehavioralParticipantSnapshot::id),
            finishedParticipants = finishResults.map(BehavioralFinishResultSnapshot::participantId),
            finishResults = finishResults,
        )
    }

    private fun participants(): List<RaceParticipant> = listOf(session.player) + session.opponents

    private fun participantsById(): Map<String, RaceParticipant> = participants().associateBy { it.id }

    private fun participantSnapshot(
        participant: RaceParticipant,
        racePosition: Int,
    ): BehavioralParticipantSnapshot =
        BehavioralParticipantSnapshot(
            id = participant.id,
            surface = surfaceId(track.surfaceAt(participant.state.x, participant.state.y)),
            x = participant.state.x,
            y = participant.state.y,
            rotation = normalizeRotation(participant.state.rotationDeg),
            velocityX = participant.state.velocityX,
            velocityY = participant.state.velocityY,
            angularVelocity = participant.state.angularVelocity,
            longitudinalSpeed = participant.state.speed,
            lateralSpeed = participant.state.lateralSpeed,
            driftAmount = participant.state.driftAmount,
            checkpoint = participant.progress.currentCheckpointIndex,
            lap = participant.progress.completedLaps,
            racePosition = racePosition,
            finished = participant.progress.finished,
        )

    private fun countdownSnapshot(): BehavioralCountdownSnapshot =
        BehavioralCountdownSnapshot(
            state =
                when (session.raceState.phase) {
                    RacePhase.LOADING, RacePhase.READY -> "not-started"
                    RacePhase.COUNTDOWN -> "active"
                    RacePhase.RACING, RacePhase.PAUSED, RacePhase.FINISHED -> "complete"
                },
            remainingSeconds = session.raceState.countdownRemainingSeconds,
        )

    private fun currentLap(participant: RaceParticipant): Int =
        minOf(participant.progress.completedLaps + 1, session.requiredLaps)

    private fun progressSnapshot(participant: RaceParticipant): BehavioralProgressSnapshot =
        BehavioralProgressSnapshot(
            checkpoint = participant.progress.currentCheckpointIndex,
            completedLaps = participant.progress.completedLaps,
        )

    private fun finishResultSnapshot(participant: RaceParticipant): BehavioralFinishResultSnapshot =
        BehavioralFinishResultSnapshot(
            participantId = participant.id,
            finishPosition = requireNotNull(participant.progress.finishPosition),
            elapsedSimulationTime = participant.progress.totalRaceTime,
            bestLapTime = participant.progress.bestLapTime,
        )

    private fun phaseId(phase: RacePhase): String =
        when (phase) {
            RacePhase.LOADING -> "loading"
            RacePhase.READY -> "ready"
            RacePhase.COUNTDOWN -> "countdown"
            RacePhase.RACING -> "racing"
            RacePhase.PAUSED -> "paused"
            RacePhase.FINISHED -> "finished"
        }

    private fun surfaceId(surface: SurfaceType): String =
        when (surface) {
            SurfaceType.ASPHALT -> "asphalt"
            SurfaceType.PARQUET -> "parquet"
            SurfaceType.TILE -> "tile"
            SurfaceType.GRASS -> "grass"
            SurfaceType.BOOST -> "boost"
            SurfaceType.OIL -> "oil"
        }

    private fun difficultyFromId(id: String): AiDifficulty =
        when (id) {
            "easy", "EASY" -> AiDifficulty.EASY
            "normal", "NORMAL" -> AiDifficulty.NORMAL
            "hard", "HARD" -> AiDifficulty.HARD
            else -> error("Unknown compatibility difficulty ID: $id")
        }

    private fun normalizeRotation(rotation: Float): Float {
        val wrapped = rotation % DEGREES_PER_TURN
        return when {
            wrapped < 0f -> wrapped + DEGREES_PER_TURN
            wrapped == 0f -> 0f
            else -> wrapped
        }
    }

    private companion object {
        const val DEGREES_PER_TURN = 360f
    }
}

/** Stable race options shared by Kotlin's reference runner and a future adapter. */
data class BehavioralRaceConfiguration(
    val seed: Long,
    val trackId: String,
    val playerCar: String,
    val opponentDifficulty: String = "normal",
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
        surfaceSpeedMultiplier?.let {
            require(it in 0f..1f) {
                "Surface speed multiplier must be between 0 and 1"
            }
            participant.surfaceSpeedState.speedMultiplier = it
        }
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
    val schemaVersion: Int,
    val simulationTick: Int,
    val raceState: String,
    val countdown: BehavioralCountdownSnapshot,
    val elapsedSimulationTime: Float,
    val currentLap: Int,
    val currentProgress: BehavioralProgressSnapshot,
    val participants: List<BehavioralParticipantSnapshot>,
    val ranking: List<String>,
    val finishedParticipants: List<String>,
    val finishResults: List<BehavioralFinishResultSnapshot>,
)

/** Rendering-free observation of one race participant. */
data class BehavioralParticipantSnapshot(
    val id: String,
    val surface: String,
    val x: Float,
    val y: Float,
    val rotation: Float,
    val velocityX: Float,
    val velocityY: Float,
    val angularVelocity: Float,
    val longitudinalSpeed: Float,
    val lateralSpeed: Float,
    val driftAmount: Float,
    val checkpoint: Int,
    val lap: Int,
    val racePosition: Int,
    val finished: Boolean,
)

data class BehavioralCountdownSnapshot(
    val state: String,
    val remainingSeconds: Float,
)

data class BehavioralProgressSnapshot(
    val checkpoint: Int,
    val completedLaps: Int,
)

data class BehavioralFinishResultSnapshot(
    val participantId: String,
    val finishPosition: Int,
    val elapsedSimulationTime: Float,
    val bestLapTime: Float?,
)

/** Schema constants shared by the Kotlin reference snapshot and its JSON schema. */
object BehavioralSnapshotSchema {
    const val VERSION = 2
}
