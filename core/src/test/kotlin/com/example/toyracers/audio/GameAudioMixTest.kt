package com.example.toyracers.audio

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class GameAudioMixTest {
    @Test
    fun `drift follows actual slip rather than steering`() {
        val turningWithoutSlip = mix(driftAmount = 0f)
        val slidingWithoutSteering = mix(driftAmount = 0.5f)

        assertEquals(0f, turningWithoutSlip.driftVolume, TOLERANCE)
        assertTrue(slidingWithoutSteering.driftVolume > 0f)
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
        val quiet = mix(sfxVolume = 0.2f, throttle = 1f, driftAmount = 1f, offRoad = true)
        val loud = mix(sfxVolume = 0.8f, throttle = 1f, driftAmount = 1f, offRoad = true)

        assertTrue(loud.engineVolume > quiet.engineVolume)
        assertTrue(loud.driftVolume > quiet.driftVolume)
        assertTrue(loud.wheelspinVolume > quiet.wheelspinVolume)
    }

    private fun mix(
        speed: Float = 8f,
        throttle: Float = 0f,
        brake: Float = 0f,
        driftAmount: Float = 0f,
        offRoad: Boolean = false,
        sfxVolume: Float = 0.8f,
    ): RaceAudioMix =
        calculateRaceAudioMix(
            speed = speed,
            maxSpeed = 16f,
            throttle = throttle,
            brake = brake,
            driftAmount = driftAmount,
            racing = true,
            offRoad = offRoad,
            paused = false,
            sfxVolume = sfxVolume,
        )

    private companion object {
        const val TOLERANCE = 0.0001f
    }
}
