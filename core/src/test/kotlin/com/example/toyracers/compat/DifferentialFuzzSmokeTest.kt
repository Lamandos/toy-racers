package com.example.toyracers.compat

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DifferentialFuzzSmokeTest {
    @Test
    fun `one hundred fixed-seed scenarios run through the reference simulation`() {
        assertEquals(SMOKE_SCENARIO_COUNT, FIXED_CI_SEEDS.size)
        val runner = BehavioralScenarioRunner()

        FIXED_CI_SEEDS.forEach { seed ->
            val scenario = DifferentialFuzzScenarioGenerator.generate(seed, SMOKE_TICKS)
            val trace = runner.run(scenario)

            assertEquals(scenario.id, trace.scenarioId)
            assertEquals(seed, trace.seed)
            assertEquals(SMOKE_TICKS, trace.samples.last().tick)
            scenario.inputSegments.forEach { segment -> assertNormalized(segment.input) }
        }
    }

    private fun assertNormalized(input: BehavioralInput) {
        assertTrue(input.throttle in 0f..1f)
        assertTrue(input.brake in 0f..1f)
        assertTrue(input.steering in -1f..1f)
    }

    private companion object {
        const val SMOKE_SCENARIO_COUNT = 100
        const val SMOKE_TICKS = 120
        const val SEED_STEP = 104_729L
        private val FIXED_CI_SEEDS =
            listOf(Long.MIN_VALUE, -1L, 0L, 1L, Long.MAX_VALUE) +
                (1L..95L).map { index -> index * SEED_STEP }
    }
}
