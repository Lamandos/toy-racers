package com.example.toyracers.collision

/** Tuning shared by track and car collision response. */
data class CollisionConfig(
    val wallSpeedRetention: Float = 0.65f,
    val carRestitution: Float = 0.15f,
    val maxCarImpulse: Float = 8f,
) {
    init {
        require(wallSpeedRetention in 0f..1f)
        require(carRestitution in 0f..1f)
        require(maxCarImpulse >= 0f)
    }
}
