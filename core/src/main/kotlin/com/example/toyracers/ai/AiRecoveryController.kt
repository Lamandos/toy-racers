package com.example.toyracers.ai

import com.example.toyracers.car.CarState
import kotlin.math.abs

/** Detects stalled and wrong-way cars and owns the timed reverse recovery state. */
class AiRecoveryController(private val config: AiConfig) {
    private var stuckTime = 0f
    private var wrongWayTime = 0f
    private var recoveryTimeRemaining = 0f

    val recovering: Boolean
        get() = recoveryTimeRemaining > 0f

    fun reset() {
        stuckTime = 0f
        wrongWayTime = 0f
        recoveryTimeRemaining = 0f
    }

    fun update(carState: CarState, headingErrorDegrees: Float, deltaSeconds: Float): Boolean {
        if (recovering) {
            recoveryTimeRemaining = (recoveryTimeRemaining - deltaSeconds).coerceAtLeast(0f)
            return true
        }

        stuckTime = if (abs(carState.speed) < config.stuckSpeed) stuckTime + deltaSeconds else 0f
        wrongWayTime = if (abs(headingErrorDegrees) > config.wrongWayAngleDeg) {
            wrongWayTime + deltaSeconds
        } else {
            0f
        }
        if (
            stuckTime >= config.stuckDurationSeconds ||
            wrongWayTime >= config.wrongWayDurationSeconds
        ) {
            stuckTime = 0f
            wrongWayTime = 0f
            recoveryTimeRemaining = config.recoveryDurationSeconds
            return true
        }
        return false
    }
}
