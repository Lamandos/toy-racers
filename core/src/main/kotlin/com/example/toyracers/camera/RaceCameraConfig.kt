package com.example.toyracers.camera

/** Tuning values for the player-following race camera. */
data class RaceCameraConfig(
    val followSpeed: Float = 6f,
    val lookAheadDistance: Float = 4f,
    val zoom: Float = 1f,
    val shakeDecaySpeed: Float = 12f,
) {
    init {
        require(followSpeed > 0f) { "followSpeed must be positive" }
        require(lookAheadDistance >= 0f) { "lookAheadDistance must not be negative" }
        require(zoom > 0f) { "zoom must be positive" }
        require(shakeDecaySpeed > 0f) { "shakeDecaySpeed must be positive" }
    }
}
