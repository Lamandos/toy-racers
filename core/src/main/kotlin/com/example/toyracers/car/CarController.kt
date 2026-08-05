package com.example.toyracers.car

import com.example.toyracers.input.CarInput

/** Explicit controller boundary shared by player and AI commands. */
class CarController(private val physics: CarPhysics = CarPhysics()) {
    fun update(state: CarState, config: CarConfig, input: CarInput, deltaSeconds: Float) {
        physics.update(state, config, input, deltaSeconds)
    }
}
