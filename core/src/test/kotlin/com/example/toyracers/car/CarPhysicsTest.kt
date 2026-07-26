package com.example.toyracers.car

import com.example.toyracers.input.PlayerInput
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs
import kotlin.math.sqrt

class CarPhysicsTest {
    private val physics = CarPhysics()
    private val config = CarConfig()

    @Test
    fun `throttle accelerates the car forward`() {
        val state = CarState()

        simulate(state, PlayerInput(throttle = 1f), seconds = 1f)

        assertTrue(state.speed > 0f)
        assertTrue(state.x > 0f)
        assertEquals(0f, state.y, EPSILON)
    }

    @Test
    fun `forward speed is limited`() {
        val state = CarState()

        simulate(state, PlayerInput(throttle = 1f), seconds = 10f)

        assertEquals(config.maxForwardSpeed, state.speed, EPSILON)
    }

    @Test
    fun `brake reduces forward speed`() {
        val state = CarState(velocityX = 20f, speed = 20f)

        simulate(state, PlayerInput(brake = 1f), seconds = 0.25f)

        assertTrue(state.speed in 0f..<20f)
    }

    @Test
    fun `holding brake from rest engages reverse with a speed limit`() {
        val state = CarState()

        simulate(state, PlayerInput(brake = 1f), seconds = 5f)

        assertEquals(-config.maxReverseSpeed, state.speed, EPSILON)
        assertTrue(state.x < 0f)
    }

    @Test
    fun `zero input leaves a resting car stationary`() {
        val state = CarState(x = 4f, y = -3f, rotationDeg = 45f)

        simulate(state, PlayerInput.NONE, seconds = 2f)

        assertEquals(4f, state.x, EPSILON)
        assertEquals(-3f, state.y, EPSILON)
        assertEquals(0f, state.speed, EPSILON)
        assertEquals(45f, state.rotationDeg, EPSILON)
    }

    @Test
    fun `steering changes heading only while moving`() {
        val stationary = CarState()
        val moving = CarState(velocityX = 12f, speed = 12f)

        physics.update(stationary, config, PlayerInput(steering = 1f), CarPhysics.FIXED_DELTA_SECONDS)
        physics.update(moving, config, PlayerInput(steering = 1f), CarPhysics.FIXED_DELTA_SECONDS)

        assertEquals(0f, stationary.rotationDeg, EPSILON)
        assertTrue(abs(moving.rotationDeg) > EPSILON)
    }

    @Test
    fun `lateral grip reduces sideways velocity`() {
        val state = CarState(velocityY = 10f)

        physics.update(state, config, PlayerInput.NONE, CarPhysics.FIXED_DELTA_SECONDS)

        assertTrue(abs(state.velocityY) < 10f)
    }

    @Test
    fun `steering without engine power does not add kinetic energy`() {
        val noDragConfig = CarConfig(
            lateralFriction = 0f,
            rollingResistance = 0f,
        )
        val state = CarState(velocityX = 12f, speed = 12f)
        val initialVelocity = velocityMagnitude(state)

        physics.update(
            state,
            noDragConfig,
            PlayerInput(steering = 1f),
            CarPhysics.FIXED_DELTA_SECONDS,
        )

        assertEquals(initialVelocity, velocityMagnitude(state), EPSILON)
    }

    @Test
    fun `continuous steering without drag preserves velocity magnitude`() {
        val noDragConfig = CarConfig(
            lateralFriction = 0f,
            rollingResistance = 0f,
        )
        val state = CarState(velocityX = 12f, speed = 12f)
        val initialVelocity = velocityMagnitude(state)

        repeat(600) {
            physics.update(
                state,
                noDragConfig,
                PlayerInput(steering = 1f),
                CarPhysics.FIXED_DELTA_SECONDS,
            )
        }

        assertEquals(initialVelocity, velocityMagnitude(state), EPSILON)
    }

    private fun velocityMagnitude(state: CarState): Float =
        sqrt(state.velocityX * state.velocityX + state.velocityY * state.velocityY)

    private fun simulate(state: CarState, input: PlayerInput, seconds: Float) {
        val steps = (seconds / CarPhysics.FIXED_DELTA_SECONDS).toInt()
        repeat(steps) {
            physics.update(state, config, input, CarPhysics.FIXED_DELTA_SECONDS)
        }
    }

    private companion object {
        const val EPSILON = 0.001f
    }
}
