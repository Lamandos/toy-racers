package com.example.toyracers.compat

import org.junit.Assert.assertEquals
import org.junit.Test

class DifferentialFuzzSmokeTest {
    @Test
    fun `fixed differential suite keeps one hundred unique signed seeds`() {
        assertEquals(DifferentialFuzzSmokeCli.SMOKE_SCENARIO_COUNT, DifferentialFuzzSmokeCli.FIXED_SEEDS.size)
        assertEquals(DifferentialFuzzSmokeCli.FIXED_SEEDS.size, DifferentialFuzzSmokeCli.FIXED_SEEDS.distinct().size)
    }
}
