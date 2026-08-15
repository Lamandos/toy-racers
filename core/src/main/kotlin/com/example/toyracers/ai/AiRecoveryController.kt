package com.example.toyracers.ai

import com.example.toyracers.car.CarState
import kotlin.math.abs

/** Detects stalled, wrong-way and off-track cars, then escalates reverse recovery to respawn. */
class AiRecoveryController(
    private val config: AiConfig,
) {
    private var stuckTime = 0f
    private var wrongWayTime = 0f
    private var offTrackTime = 0f
    private var recoveryTimeRemaining = 0f

    fun reset() {
        stuckTime = 0f
        wrongWayTime = 0f
        offTrackTime = 0f
        recoveryTimeRemaining = 0f
    }

    fun update(
        carState: CarState,
        headingErrorDegrees: Float,
        isOnTrack: Boolean,
        deltaSeconds: Float,
    ): AiRecoveryAction {
        if (recoveryTimeRemaining > 0f) {
            recoveryTimeRemaining -= deltaSeconds
            return if (recoveryTimeRemaining > 0f) {
                AiRecoveryAction.REVERSE
            } else {
                val recovered =
                    abs(carState.speed) >= config.stuckSpeed &&
                        abs(headingErrorDegrees) <= config.wrongWayAngleDeg &&
                        isOnTrack
                reset()
                if (recovered) AiRecoveryAction.NONE else AiRecoveryAction.RESPAWN
            }
        }

        stuckTime = if (abs(carState.speed) < config.stuckSpeed) stuckTime + deltaSeconds else 0f
        wrongWayTime = if (abs(headingErrorDegrees) > config.wrongWayAngleDeg) wrongWayTime + deltaSeconds else 0f
        offTrackTime = if (!isOnTrack) offTrackTime + deltaSeconds else 0f
        if (offTrackTime >= config.offTrackDurationSeconds) {
            reset()
            return AiRecoveryAction.RESPAWN
        }
        if (
            stuckTime >= config.stuckDurationSeconds ||
            wrongWayTime >= config.wrongWayDurationSeconds
        ) {
            recoveryTimeRemaining = config.recoveryDurationSeconds
            return AiRecoveryAction.REVERSE
        }
        return AiRecoveryAction.NONE
    }
}

enum class AiRecoveryAction { NONE, REVERSE, RESPAWN }
