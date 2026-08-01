package com.example.toyracers.ui

import org.junit.Assert.assertEquals
import org.junit.Test

class CarSelectionStageTest {
    @Test
    fun `performance scale maps eighty to one square and one hundred ten to five`() {
        assertEquals(1, performanceSquareCount(0.80f))
        assertEquals(3, performanceSquareCount(0.95f))
        assertEquals(5, performanceSquareCount(1.10f))
    }
}
