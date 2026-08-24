package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonReader
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.charset.StandardCharsets.UTF_8
import java.nio.file.Files

class DifferentialFuzzScenarioGeneratorTest {
    @Test
    fun `same seed and tick count produce the same normalized commands`() {
        val first = DifferentialFuzzScenarioGenerator.generate(seed = 104_729L, ticks = 8)
        val second = DifferentialFuzzScenarioGenerator.generate(seed = 104_729L, ticks = 8)

        assertEquals(first, second)
        assertEquals("differential-fuzz-seed-104729", first.id)
        assertEquals(8, first.inputSegments.size)
        assertInput(first.inputSegments[0].input, 0.247569f, 0.723456f, 0.223849f)
        assertInput(first.inputSegments[1].input, 0.077417f, 0.113758f, 0.600200f)
        first.inputSegments.forEachIndexed { index, segment ->
            assertEquals(index + 1, segment.fromTick)
            assertEquals(index + 1, segment.toTick)
            assertNormalized(segment.input)
        }
    }

    @Test
    fun `saved generated JSON can be loaded and replayed without regeneration`() {
        val generated = DifferentialFuzzScenarioGenerator.generate(seed = Long.MIN_VALUE, ticks = 30)
        val output = Files.createTempFile("differential-fuzz-", ".json")

        try {
            val encoded = DifferentialFuzzScenarioJson.encode(generated)
            assertEquals(
                BehavioralScenarioLoader.SCHEMA_VERSION,
                JsonReader().parse(encoded).getInt("schemaVersion"),
            )
            Files.writeString(output, encoded, UTF_8)
            val replay = BehavioralScenarioLoader.load(output)

            assertEquals(generated, replay)
            assertEquals(
                BehavioralTraceJson.encode(BehavioralScenarioRunner().run(generated)),
                BehavioralTraceJson.encode(BehavioralScenarioRunner().run(replay)),
            )
        } finally {
            Files.deleteIfExists(output)
        }
    }

    @Test
    fun `generator supports every signed seed boundary`() {
        listOf(Long.MIN_VALUE, -1L, 0L, 1L, Long.MAX_VALUE).forEach { seed ->
            DifferentialFuzzScenarioGenerator.generate(seed, 12).inputSegments.forEach { segment ->
                assertNormalized(segment.input)
            }
        }
    }

    private fun assertNormalized(input: BehavioralInput) {
        assertTrue(input.throttle in 0f..1f)
        assertTrue(input.brake in 0f..1f)
        assertTrue(input.steering in -1f..1f)
    }

    private fun assertInput(
        input: BehavioralInput,
        throttle: Float,
        brake: Float,
        steering: Float,
    ) {
        assertEquals(throttle, input.throttle, 0f)
        assertEquals(brake, input.brake, 0f)
        assertEquals(steering, input.steering, 0f)
    }
}
