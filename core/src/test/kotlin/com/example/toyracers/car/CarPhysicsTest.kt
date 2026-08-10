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
        assertEquals(state.velocityY, state.lateralSpeed, EPSILON)
    }

    @Test
    fun `strong steering below drift entry speed does not activate drift`() {
        val state = CarState(
            velocityX = config.driftEntrySpeed - 0.1f,
            speed = config.driftEntrySpeed - 0.1f,
        )

        simulate(state, PlayerInput(steering = 1f), seconds = 0.5f)

        assertEquals(0f, state.driftAmount, EPSILON)
    }

    @Test
    fun `drift preserves more lateral speed than normal grip`() {
        val drifting = CarState(velocityX = 24f, speed = 24f)
        val normalGrip = drifting.copy()
        val driftConfig = config.copy(rollingResistance = 0f, driftDrag = 0f)
        val noDriftConfig = driftConfig.copy(driftEntrySpeed = 100f)

        physics.update(
            drifting,
            driftConfig,
            PlayerInput(steering = 1f),
            CarPhysics.FIXED_DELTA_SECONDS,
        )
        physics.update(
            normalGrip,
            noDriftConfig,
            PlayerInput(steering = 1f),
            CarPhysics.FIXED_DELTA_SECONDS,
        )

        assertTrue(drifting.driftAmount > 0f)
        assertTrue(abs(drifting.lateralSpeed) > abs(normalGrip.lateralSpeed))
    }

    @Test
    fun `drift entry and release are smooth`() {
        val state = CarState(velocityX = 24f, speed = 24f)

        repeat(3) {
            physics.update(state, config, PlayerInput(steering = 1f), CarPhysics.FIXED_DELTA_SECONDS)
        }
        val driftBeforeRelease = state.driftAmount

        physics.update(state, config, PlayerInput.NONE, CarPhysics.FIXED_DELTA_SECONDS)

        assertTrue(driftBeforeRelease in 0f..<1f)
        assertTrue(state.driftAmount in 0f..<driftBeforeRelease)

        simulate(state, PlayerInput.NONE, seconds = 1f)
        assertEquals(0f, state.driftAmount, EPSILON)
    }

    @Test
    fun `throttle sustains drift through a turn`() {
        val state = CarState(velocityX = 20f, speed = 20f)

        simulate(state, PlayerInput(throttle = 1f, steering = 1f), seconds = 1f)

        assertTrue(state.driftAmount > 0f)
        assertTrue(state.speed > config.driftEntrySpeed)
    }

    @Test
    fun `countersteering ends drift`() {
        val state = CarState(velocityX = 24f, speed = 24f)

        simulate(state, PlayerInput(steering = 1f), seconds = 0.4f)
        val driftBeforeCountersteer = state.driftAmount
        repeat(4) {
            physics.update(state, config, PlayerInput(steering = -1f), CarPhysics.FIXED_DELTA_SECONDS)
        }

        assertTrue(driftBeforeCountersteer > 0f)
        assertTrue(state.driftAmount < driftBeforeCountersteer)
        simulate(state, PlayerInput.NONE, seconds = 1f)
        assertEquals(0f, state.driftAmount, EPSILON)
    }

    @Test
    fun `drift does not add kinetic energy without engine force`() {
        val state = CarState(velocityX = 24f, speed = 24f)
        val initialVelocity = velocityMagnitude(state)

        simulate(state, PlayerInput(steering = 1f), seconds = 2f)

        assertTrue(velocityMagnitude(state) <= initialVelocity + EPSILON)
    }

    @Test
    fun `reverse steering does not activate drift`() {
        val state = CarState(velocityX = -20f, speed = -20f)

        simulate(state, PlayerInput(steering = 1f), seconds = 0.5f)

        assertEquals(0f, state.driftAmount, EPSILON)
    }

    @Test
    fun `fixed step drift simulation is deterministic`() {
        val first = CarState(velocityX = 24f, speed = 24f)
        val second = first.copy()
        val inputs = List(60) { PlayerInput(throttle = 0.8f, steering = 1f) } +
            List(60) { PlayerInput(throttle = 0.6f, steering = -0.8f) }

        inputs.forEach { input ->
            physics.update(first, config, input, CarPhysics.FIXED_DELTA_SECONDS)
            physics.update(second, config, input, CarPhysics.FIXED_DELTA_SECONDS)
        }

        assertEquals(first, second)
    }

    @Test
    fun `steering without engine power does not add kinetic energy`() {
        val noDragConfig = CarConfig(
            lateralFriction = 0f,
            rollingResistance = 0f,
            driftDrag = 0f,
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
            driftDrag = 0f,
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
