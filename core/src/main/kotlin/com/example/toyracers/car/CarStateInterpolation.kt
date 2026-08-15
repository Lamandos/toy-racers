package com.example.toyracers.car

/**
 * Builds a display-only state between two fixed simulation steps.
 *
 * The returned instance is deliberately separate from both simulation states, so rendering cannot
 * feed fractional positions or rotations back into deterministic physics.
 */
internal fun interpolateCarState(
    previous: CarState,
    current: CarState,
    alpha: Float,
): CarState {
    val clampedAlpha = alpha.coerceIn(0f, 1f)
    return CarState(
        x = interpolate(previous.x, current.x, clampedAlpha),
        y = interpolate(previous.y, current.y, clampedAlpha),
        rotationDeg =
            interpolateRotationDegrees(
                previous.rotationDeg,
                current.rotationDeg,
                clampedAlpha,
            ),
        speed = interpolate(previous.speed, current.speed, clampedAlpha),
        velocityX = interpolate(previous.velocityX, current.velocityX, clampedAlpha),
        velocityY = interpolate(previous.velocityY, current.velocityY, clampedAlpha),
        angularVelocity =
            interpolate(
                previous.angularVelocity,
                current.angularVelocity,
                clampedAlpha,
            ),
    )
}

/** Interpolates degrees around the shortest arc, including the 0°/360° boundary. */
internal fun interpolateRotationDegrees(
    previousDegrees: Float,
    currentDegrees: Float,
    alpha: Float,
): Float {
    val shortestDelta = normalizeDegrees(currentDegrees - previousDegrees + 180f) - 180f
    return normalizeDegrees(previousDegrees + shortestDelta * alpha.coerceIn(0f, 1f))
}

private fun interpolate(
    previous: Float,
    current: Float,
    alpha: Float,
): Float = previous + (current - previous) * alpha

private fun normalizeDegrees(degrees: Float): Float {
    val wrapped = degrees % FULL_CIRCLE_DEGREES
    return if (wrapped < 0f) wrapped + FULL_CIRCLE_DEGREES else wrapped
}

private const val FULL_CIRCLE_DEGREES = 360f
