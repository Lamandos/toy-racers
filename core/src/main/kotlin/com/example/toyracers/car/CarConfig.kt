package com.example.toyracers.car

/** Tunable arcade handling values in world units and seconds. */
data class CarConfig(
    val acceleration: Float = 26f,
    val brakeForce: Float = 38f,
    val reverseAcceleration: Float = 15f,
    val maxForwardSpeed: Float = 34f,
    val maxReverseSpeed: Float = 13f,
    val steeringSpeed: Float = 145f,
    val grip: Float = 1f,
    val lateralFriction: Float = 7f,
    val rollingResistance: Float = 4f,
    val collisionRadius: Float = 0.81f,
    val collisionLongitudinalOffset: Float = 0.81f,
    val width: Float = 1.8f,
    val length: Float = 3.4f,
) {
    init {
        require(acceleration >= 0f)
        require(brakeForce >= 0f)
        require(reverseAcceleration >= 0f)
        require(maxForwardSpeed > 0f)
        require(maxReverseSpeed > 0f)
        require(steeringSpeed >= 0f)
        require(grip >= 0f)
        require(lateralFriction >= 0f)
        require(rollingResistance >= 0f)
        require(collisionRadius > 0f)
        require(collisionLongitudinalOffset >= 0f)
        require(width > 0f)
        require(length > 0f)
        require(collisionRadius * 2f <= width) {
            "Collision shape must fit inside car width"
        }
        require(collisionLongitudinalOffset + collisionRadius <= length / 2f) {
            "Collision shape must fit inside car length"
        }
    }
}
