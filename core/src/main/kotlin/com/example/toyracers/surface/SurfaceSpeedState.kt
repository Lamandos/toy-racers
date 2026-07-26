package com.example.toyracers.surface

/** Per-car state so surface transitions remain deterministic and independent. */
data class SurfaceSpeedState(
    var speedMultiplier: Float = 1f,
) {
    init {
        require(speedMultiplier in 0f..1f)
    }
}
