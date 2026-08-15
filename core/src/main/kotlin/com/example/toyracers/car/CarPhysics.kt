package com.example.toyracers.car

import com.example.toyracers.input.PlayerInput
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/** Deterministic arcade car simulation without platform or rendering dependencies. */
class CarPhysics {
    fun update(
        state: CarState,
        config: CarConfig,
        rawInput: PlayerInput,
        deltaSeconds: Float,
    ) {
        require(deltaSeconds >= 0f) { "deltaSeconds must not be negative" }
        if (deltaSeconds == 0f) return

        val input = rawInput.normalized()
        var basis = Basis.fromDegrees(state.rotationDeg)

        // Engine force always follows the car's forward direction.
        state.velocityX += basis.forwardX * config.acceleration * input.throttle * deltaSeconds
        state.velocityY += basis.forwardY * config.acceleration * input.throttle * deltaSeconds

        var longitudinalSpeed = basis.forwardDot(state.velocityX, state.velocityY)
        val lateralSpeedBeforeSteering = basis.rightDot(state.velocityX, state.velocityY)
        if (input.brake > 0f) {
            if (longitudinalSpeed > STOP_EPSILON) {
                longitudinalSpeed =
                    moveToward(
                        longitudinalSpeed,
                        0f,
                        config.brakeForce * input.brake * deltaSeconds,
                    )
            } else {
                longitudinalSpeed -= config.reverseAcceleration * input.brake * deltaSeconds
            }
        }

        longitudinalSpeed =
            moveToward(
                longitudinalSpeed,
                0f,
                config.rollingResistance * deltaSeconds,
            ).coerceIn(-config.maxReverseSpeed, config.maxForwardSpeed)

        val targetDriftAmount =
            targetDriftAmount(
                longitudinalSpeed = longitudinalSpeed,
                lateralSpeed = lateralSpeedBeforeSteering,
                steering = input.steering,
                config = config,
            )
        state.driftAmount =
            moveToward(
                state.driftAmount,
                targetDriftAmount,
                if (targetDriftAmount > state.driftAmount) {
                    config.driftEntryResponse * deltaSeconds
                } else {
                    config.driftExitResponse * deltaSeconds
                },
            )

        val velocityBeforeSteeringX =
            basis.forwardX * longitudinalSpeed + basis.rightX * lateralSpeedBeforeSteering
        val velocityBeforeSteeringY =
            basis.forwardY * longitudinalSpeed + basis.rightY * lateralSpeedBeforeSteering

        // Steering authority rises with speed and reverses naturally while backing up.
        val steeringAuthority = min(abs(longitudinalSpeed) / STEERING_REFERENCE_SPEED, 1f)
        state.angularVelocity = -input.steering *
            config.steeringSpeed *
            interpolate(1f, config.driftSteeringMultiplier, state.driftAmount) *
            steeringAuthority *
            signOrZero(longitudinalSpeed)
        state.rotationDeg = normalizeDegrees(state.rotationDeg + state.angularVelocity * deltaSeconds)

        // Re-project both velocity components after rotating the car, then remove side slip.
        basis = Basis.fromDegrees(state.rotationDeg)
        longitudinalSpeed = basis.forwardDot(velocityBeforeSteeringX, velocityBeforeSteeringY)
        var lateralSpeed = basis.rightDot(velocityBeforeSteeringX, velocityBeforeSteeringY)
        val effectiveGrip =
            config.grip *
                interpolate(
                    1f,
                    config.driftGripMultiplier,
                    state.driftAmount,
                )
        lateralSpeed *= max(0f, 1f - config.lateralFriction * effectiveGrip * deltaSeconds)
        longitudinalSpeed =
            moveToward(
                longitudinalSpeed,
                0f,
                config.driftDrag * state.driftAmount * abs(lateralSpeed) * deltaSeconds,
            )

        longitudinalSpeed = longitudinalSpeed.coerceIn(-config.maxReverseSpeed, config.maxForwardSpeed)
        state.velocityX = basis.forwardX * longitudinalSpeed + basis.rightX * lateralSpeed
        state.velocityY = basis.forwardY * longitudinalSpeed + basis.rightY * lateralSpeed
        state.speed = longitudinalSpeed
        state.lateralSpeed = lateralSpeed
        state.x += state.velocityX * deltaSeconds
        state.y += state.velocityY * deltaSeconds
    }

    private fun targetDriftAmount(
        longitudinalSpeed: Float,
        lateralSpeed: Float,
        steering: Float,
        config: CarConfig,
    ): Float {
        if (
            longitudinalSpeed < config.driftEntrySpeed ||
            steering * lateralSpeed < 0f
        ) {
            return 0f
        }

        val speedRatio =
            (
                (longitudinalSpeed - config.driftEntrySpeed) / config.driftEntrySpeed
            ).coerceIn(0f, 1f)
        val steeringRatio =
            (
                (abs(steering) - config.driftSteeringThreshold) /
                    (1f - config.driftSteeringThreshold)
            ).coerceIn(0f, 1f)
        return speedRatio * steeringRatio
    }

    private fun interpolate(
        from: Float,
        to: Float,
        amount: Float,
    ): Float = from + (to - from) * amount

    private fun moveToward(
        value: Float,
        target: Float,
        amount: Float,
    ): Float =
        when {
            value < target -> min(value + amount, target)
            value > target -> max(value - amount, target)
            else -> target
        }

    private fun signOrZero(value: Float): Float =
        when {
            value > STOP_EPSILON -> 1f
            value < -STOP_EPSILON -> -1f
            else -> 0f
        }

    private fun normalizeDegrees(degrees: Float): Float {
        val wrapped = degrees % 360f
        return if (wrapped < 0f) wrapped + 360f else wrapped
    }

    private data class Basis(
        val forwardX: Float,
        val forwardY: Float,
        val rightX: Float,
        val rightY: Float,
    ) {
        fun forwardDot(
            x: Float,
            y: Float,
        ): Float = x * forwardX + y * forwardY

        fun rightDot(
            x: Float,
            y: Float,
        ): Float = x * rightX + y * rightY

        companion object {
            fun fromDegrees(rotationDeg: Float): Basis {
                val radians = Math.toRadians(rotationDeg.toDouble())
                val forwardX = cos(radians).toFloat()
                val forwardY = sin(radians).toFloat()
                return Basis(
                    forwardX = forwardX,
                    forwardY = forwardY,
                    rightX = -forwardY,
                    rightY = forwardX,
                )
            }
        }
    }

    companion object {
        const val FIXED_DELTA_SECONDS = 1f / 60f
        const val MAX_FRAME_DELTA_SECONDS = 0.25f
        private const val STEERING_REFERENCE_SPEED = 12f
        private const val STOP_EPSILON = 0.01f
    }
}
