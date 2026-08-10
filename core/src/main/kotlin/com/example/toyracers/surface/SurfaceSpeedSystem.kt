package com.example.toyracers.surface

import com.example.toyracers.car.CarConfig
import com.example.toyracers.car.CarState
import com.example.toyracers.track.SurfaceType
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/**
 * Gradually lowers a car's speed limit off road and restores it on road.
 *
 * This system runs after physics and collision response during each fixed step.
 */
class SurfaceSpeedSystem(
    private val config: SurfaceSpeedConfig = SurfaceSpeedConfig(),
) {
    fun update(
        carState: CarState,
        carConfig: CarConfig,
        surfaceState: SurfaceSpeedState,
        surface: SurfaceType,
        deltaSeconds: Float,
    ) {
        require(deltaSeconds >= 0f) { "deltaSeconds must not be negative" }
        if (deltaSeconds == 0f) return

        val targetMultiplier =
            if (surface.isRoad) 1f else config.offRoadSpeedMultiplier
        val changePerSecond = (1f - config.offRoadSpeedMultiplier) / config.transitionSeconds
        surfaceState.speedMultiplier = moveToward(
            surfaceState.speedMultiplier,
            targetMultiplier,
            changePerSecond * deltaSeconds,
        )
        applySpeedLimit(carState, carConfig, surfaceState.speedMultiplier)
    }

    private fun applySpeedLimit(
        state: CarState,
        carConfig: CarConfig,
        speedMultiplier: Float,
    ) {
        val radians = Math.toRadians(state.rotationDeg.toDouble())
        val forwardX = cos(radians).toFloat()
        val forwardY = sin(radians).toFloat()
        val rightX = -forwardY
        val rightY = forwardX
        val longitudinalSpeed = state.velocityX * forwardX + state.velocityY * forwardY
        val lateralSpeed = state.velocityX * rightX + state.velocityY * rightY
        val limitedLongitudinalSpeed = longitudinalSpeed.coerceIn(
            -carConfig.maxReverseSpeed * speedMultiplier,
            carConfig.maxForwardSpeed * speedMultiplier,
        )
        val lateralSpeedLimit = carConfig.maxForwardSpeed * speedMultiplier
        val limitedLateralSpeed = lateralSpeed.coerceIn(-lateralSpeedLimit, lateralSpeedLimit)

        state.velocityX =
            forwardX * limitedLongitudinalSpeed + rightX * limitedLateralSpeed
        state.velocityY =
            forwardY * limitedLongitudinalSpeed + rightY * limitedLateralSpeed
        state.speed = limitedLongitudinalSpeed
        state.lateralSpeed = limitedLateralSpeed
    }

    private fun moveToward(
        value: Float,
        target: Float,
        amount: Float,
    ): Float = when {
        value < target -> min(value + amount, target)
        value > target -> max(value - amount, target)
        else -> target
    }
}
