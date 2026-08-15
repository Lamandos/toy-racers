package com.example.toyracers.collision

/** One world-space circle in the shared capsule approximation of a car body. */
internal data class CarCollisionCircle(
    val x: Float,
    val y: Float,
    val radius: Float,
)
