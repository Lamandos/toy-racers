package com.example.toyracers.race

import com.example.toyracers.ai.AiConfig
import com.example.toyracers.ai.AiDriver
import com.example.toyracers.car.CarConfig
import com.example.toyracers.car.CarPhysics
import com.example.toyracers.car.CarState
import com.example.toyracers.collision.CollisionSystem
import com.example.toyracers.input.PlayerInput
import com.example.toyracers.surface.SurfaceSpeedState
import com.example.toyracers.surface.SurfaceSpeedSystem
import com.example.toyracers.track.StartGridPosition
import com.example.toyracers.track.Track
import com.example.toyracers.track.TrackPoint

/**
 * Owns the mutable state and deterministic simulation pipeline for one race.
 *
 * Presentation concerns such as input devices, rendering, audio, and screen navigation remain with
 * the race screen.
 */
internal class RaceSession(
    private val track: Track,
    val carConfig: CarConfig = CarConfig(),
    private val carPhysics: CarPhysics = CarPhysics(),
    private val collisionSystem: CollisionSystem = CollisionSystem(),
    private val surfaceSpeedSystem: SurfaceSpeedSystem = SurfaceSpeedSystem(),
) {
    val player = RaceParticipant(
        id = PLAYER_ID,
        start = track.startGrid.first(),
    )
    val opponents: List<RaceParticipant> = track.startGrid.drop(1).mapIndexed { index, start ->
        RaceParticipant(
            id = "ai-$index",
            start = start,
            driver = AiDriver(
                track.racingLine,
                start.position,
                AiConfig(waypointRadius = track.racingLineWaypointRadius),
            ),
        )
    }
    val raceState = RaceState()
    val requiredLaps: Int
        get() = raceRules.requiredLaps

    private val participants = listOf(player) + opponents
    private val positionTracker = PositionTracker(track)
    private val raceRules = RaceRules(track)
    private var accumulator = 0f

    val playerPosition: Int
        get() = positionTracker.positions(
            participants.map { participant ->
                RaceCompetitor(
                    id = participant.id,
                    progress = participant.progress,
                    position = participant.state.position(),
                )
            },
        ).getValue(player.id)

    fun start() {
        raceState.markReady()
        raceState.startCountdown()
    }

    fun pause() {
        raceState.pause()
    }

    fun resume() {
        raceState.resume()
    }

    fun advance(
        frameDeltaSeconds: Float,
        playerInput: PlayerInput,
    ): RaceStepResult {
        val phaseBeforeAdvance = raceState.phase
        val simulationDelta = raceState.advance(frameDeltaSeconds)
        var playerCheckpointPassed = false
        var maxImpactSpeed = 0f

        if (simulationDelta > 0f) {
            accumulator += simulationDelta
            while (accumulator >= CarPhysics.FIXED_DELTA_SECONDS) {
                participants.forEach { participant ->
                    val input = participant.driver?.update(
                        participant.state,
                        CarPhysics.FIXED_DELTA_SECONDS,
                    ) ?: playerInput.copy(
                        steering = playerInput.steering * carConfig.playerSteeringSensitivity,
                    )
                    val stepResult = updateParticipant(participant, input)
                    if (participant === player) {
                        maxImpactSpeed = maxOf(maxImpactSpeed, stepResult.impactSpeed)
                        if (stepResult.checkpointPassed) {
                            playerCheckpointPassed = true
                        }
                    }
                }

                maxImpactSpeed = maxOf(maxImpactSpeed, resolveCarCollisions())
                accumulator -= CarPhysics.FIXED_DELTA_SECONDS
                if (player.progress.finished) {
                    raceState.finish()
                    accumulator = 0f
                    break
                }
            }
        }

        return RaceStepResult(
            phaseBeforeAdvance = phaseBeforeAdvance,
            playerCheckpointPassed = playerCheckpointPassed,
            maxImpactSpeed = maxImpactSpeed,
        )
    }

    private fun updateParticipant(
        participant: RaceParticipant,
        input: PlayerInput,
    ): ParticipantStepResult {
        val previousPosition = participant.state.position()
        carPhysics.update(
            state = participant.state,
            config = carConfig,
            rawInput = input,
            deltaSeconds = CarPhysics.FIXED_DELTA_SECONDS,
        )
        val collision = collisionSystem.resolveTrackCollision(
            state = participant.state,
            radius = carConfig.collisionRadius,
            track = track,
        )
        surfaceSpeedSystem.update(
            carState = participant.state,
            carConfig = carConfig,
            surfaceState = participant.surfaceSpeedState,
            surface = track.surfaceAt(participant.state.x, participant.state.y),
            deltaSeconds = CarPhysics.FIXED_DELTA_SECONDS,
        )
        val checkpointBefore = participant.progress.currentCheckpointIndex
        raceRules.update(
            progress = participant.progress,
            previousPosition = previousPosition,
            currentPosition = participant.state.position(),
            deltaSeconds = CarPhysics.FIXED_DELTA_SECONDS,
        )
        return ParticipantStepResult(
            checkpointPassed = participant.progress.currentCheckpointIndex > checkpointBefore,
            impactSpeed = collision.maxImpactSpeed,
        )
    }

    private fun resolveCarCollisions(): Float {
        var maxImpactSpeed = 0f
        participants.indices.forEach { firstIndex ->
            for (secondIndex in firstIndex + 1..<participants.size) {
                val result = collisionSystem.resolveCarCollision(
                    first = participants[firstIndex].state,
                    firstRadius = carConfig.collisionRadius,
                    second = participants[secondIndex].state,
                    secondRadius = carConfig.collisionRadius,
                )
                maxImpactSpeed = maxOf(maxImpactSpeed, result.maxImpactSpeed)
            }
        }
        return maxImpactSpeed
    }

    private fun CarState.position(): TrackPoint = TrackPoint(x, y)

    private data class ParticipantStepResult(
        val checkpointPassed: Boolean,
        val impactSpeed: Float,
    )

    private companion object {
        const val PLAYER_ID = "player"
    }
}

internal class RaceParticipant(
    val id: String,
    start: StartGridPosition,
    val driver: AiDriver? = null,
) {
    val state = CarState(
        x = start.position.x,
        y = start.position.y,
        rotationDeg = start.rotationDeg,
    )
    val surfaceSpeedState = SurfaceSpeedState()
    val progress = RaceProgress()
}

internal data class RaceStepResult(
    val phaseBeforeAdvance: RacePhase,
    val playerCheckpointPassed: Boolean,
    val maxImpactSpeed: Float,
)
