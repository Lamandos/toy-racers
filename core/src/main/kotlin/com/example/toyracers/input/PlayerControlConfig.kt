package com.example.toyracers.input

/** Player-specific input tuning kept separate from vehicle physics. */
data class PlayerControlConfig(
    val steeringSensitivity: Float = 0.85f,
) {
    init {
        require(steeringSensitivity in 0f..1f)
    }

    fun applyTo(input: PlayerInput): PlayerInput = input.copy(steering = input.steering * steeringSensitivity)
}
