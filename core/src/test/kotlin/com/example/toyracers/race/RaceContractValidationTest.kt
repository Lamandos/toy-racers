package com.example.toyracers.race

import com.example.toyracers.track.TrackLoader
import org.junit.Assert.assertThrows
import org.junit.Test

class RaceContractValidationTest {
    @Test
    fun `race state requires a positive countdown`() {
        assertThrows(IllegalArgumentException::class.java) { RaceState(0f) }
    }

    @Test
    fun `race rules require a positive lap count`() {
        assertThrows(IllegalArgumentException::class.java) { RaceRules(TrackLoader().load(), requiredLaps = 0) }
    }
}
