package com.example.toyracers.car

/** Mutable simulation state for one car, expressed in world units. */
data class CarState(
    var x: Float = 0f,
    var y: Float = 0f,
    var rotationDeg: Float = 0f,
    var speed: Float = 0f,
    var velocityX: Float = 0f,
    var velocityY: Float = 0f,
    var angularVelocity: Float = 0f,
    var lateralSpeed: Float = 0f,
    var driftAmount: Float = 0f,
)
