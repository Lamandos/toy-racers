package com.example.toyracers.audio

import org.junit.Assert.assertEquals
import org.junit.Test

class AudioSettingsTest {
    @Test
    fun `master volume scales music and sound effects independently`() {
        val settings = AudioSettings(
            masterVolume = 0.5f,
            musicVolume = 0.4f,
            sfxVolume = 0.8f,
        )

        assertEquals(0.2f, settings.effectiveMusicVolume, TOLERANCE)
        assertEquals(0.4f, settings.effectiveSfxVolume, TOLERANCE)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `volume outside normalized range is rejected`() {
        AudioSettings(masterVolume = 1.1f)
    }

    private companion object {
        const val TOLERANCE = 0.0001f
    }
}
