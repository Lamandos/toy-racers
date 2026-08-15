package com.example.toyracers.collision

import com.example.toyracers.car.CarState
import kotlin.math.cos
import kotlin.math.sin

/** Single source of truth for the collision geometry used by simulation and debug rendering. */
internal fun carCollisionCircles(
    state: CarState,
    radius: Float,
    longitudinalOffset: Float,
): List<CarCollisionCircle> {
    require(radius > 0f) { "Collision radius must be positive" }
    require(longitudinalOffset >= 0f) { "Collision offset must not be negative" }
    val radians = Math.toRadians(state.rotationDeg.toDouble())
    val forwardX = cos(radians).toFloat()
    val forwardY = sin(radians).toFloat()
    val offsets = if (longitudinalOffset == 0f) CENTER_OFFSET else CAPSULE_OFFSETS
    return offsets.map { offsetMultiplier ->
        val offset = longitudinalOffset * offsetMultiplier
        CarCollisionCircle(
            x = state.x + forwardX * offset,
            y = state.y + forwardY * offset,
            radius = radius,
        )
    }
}

private val CENTER_OFFSET = listOf(0f)
private val CAPSULE_OFFSETS = listOf(-1f, 0f, 1f)
