package com.example.toyracers.track

/**
 * An ordered gate across the road.
 *
 * The forward vector records the valid crossing direction for the lap rules.
 */
data class Checkpoint(
    val order: Int,
    val gate: TrackSegment,
    val forwardX: Float,
    val forwardY: Float,
) {
    init {
        require(order >= 0) { "Checkpoint order must not be negative" }
        require(forwardX != 0f || forwardY != 0f) {
            "Checkpoint forward direction must not be zero"
        }
    }
}
