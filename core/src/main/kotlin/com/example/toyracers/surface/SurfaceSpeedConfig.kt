package com.example.toyracers.surface

/** Gradual speed-limit transition between road and off-road surfaces. */
data class SurfaceSpeedConfig(
    val offRoadSpeedMultiplier: Float = 0.3f,
    val transitionSeconds: Float = 3f,
) {
    init {
        require(offRoadSpeedMultiplier in 0f..1f)
        require(transitionSeconds > 0f)
    }
}
