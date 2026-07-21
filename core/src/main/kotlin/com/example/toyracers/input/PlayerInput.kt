package com.example.toyracers.input

/** Portable command produced by keyboard, touch, or an AI controller. */
data class PlayerInput(
    val throttle: Float = 0f,
    val brake: Float = 0f,
    val steering: Float = 0f,
) {
    fun normalized(): PlayerInput = PlayerInput(
        throttle = throttle.coerceIn(0f, 1f),
        brake = brake.coerceIn(0f, 1f),
        steering = steering.coerceIn(-1f, 1f),
    )

    fun combinedWith(other: PlayerInput): PlayerInput = PlayerInput(
        throttle = maxOf(throttle, other.throttle),
        brake = maxOf(brake, other.brake),
        steering = (steering + other.steering).coerceIn(-1f, 1f),
    ).normalized()

    companion object {
        val NONE = PlayerInput()
    }
}
