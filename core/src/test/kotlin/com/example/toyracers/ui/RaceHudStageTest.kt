package com.example.toyracers.ui

import org.junit.Assert.assertEquals
import org.junit.Test

class RaceHudStageTest {
    @Test
    fun `race time uses minutes seconds and milliseconds`() {
        assertEquals("02:05.678", formatRaceTime(125.678f))
    }

    @Test
    fun `negative race time is displayed as zero`() {
        assertEquals("00:00.000", formatRaceTime(-1f))
    }
}
