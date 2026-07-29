package com.example.toyracers.audio

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class GameAudioMixTest {
    @Test
    fun `drift follows steering while the car is moving`() {
        val straight = mix(steering = 0f)
        val turning = mix(steering = 0.5f)

        assertEquals(0f, straight.driftVolume, TOLERANCE)
        assertTrue(turning.driftVolume > 0f)
    }

    @Test
    fun `braking is silent when stopped or reversing`() {
        assertTrue(mix(speed = 8f, brake = 1f).brakingVolume > 0f)
        assertEquals(0f, mix(speed = 0f, brake = 1f).brakingVolume, TOLERANCE)
        assertEquals(0f, mix(speed = -8f, brake = 1f).brakingVolume, TOLERANCE)
    }

    @Test
    fun `wheelspin is only mixed off road`() {
        assertEquals(0f, mix(throttle = 1f, offRoad = false).wheelspinVolume, TOLERANCE)
        assertTrue(mix(throttle = 1f, offRoad = true).wheelspinVolume > 0f)
    }

    @Test
    fun `race sounds use only the sfx volume`() {
        val quiet = mix(sfxVolume = 0.2f, throttle = 1f, steering = 1f, offRoad = true)
        val loud = mix(sfxVolume = 0.8f, throttle = 1f, steering = 1f, offRoad = true)

        assertTrue(loud.engineVolume > quiet.engineVolume)
        assertTrue(loud.driftVolume > quiet.driftVolume)
        assertTrue(loud.wheelspinVolume > quiet.wheelspinVolume)
    }

    private fun mix(
        speed: Float = 8f,
        throttle: Float = 0f,
        brake: Float = 0f,
        steering: Float = 0f,
        offRoad: Boolean = false,
        sfxVolume: Float = 0.8f,
    ): RaceAudioMix = calculateRaceAudioMix(
        speed = speed,
        maxSpeed = 16f,
        throttle = throttle,
        brake = brake,
        steering = steering,
        racing = true,
        offRoad = offRoad,
        paused = false,
        sfxVolume = sfxVolume,
    )

    private companion object {
        const val TOLERANCE = 0.0001f
    }
}
