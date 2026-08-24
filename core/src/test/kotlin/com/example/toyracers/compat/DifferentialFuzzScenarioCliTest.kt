package com.example.toyracers.compat

import org.junit.Assert.assertEquals
import org.junit.Test
import java.nio.file.Files

class DifferentialFuzzScenarioCliTest {
    @Test
    fun `CLI writes a generated scenario for the requested seed and tick count`() {
        val outputDirectory = Files.createTempDirectory("differential-fuzz-cli-")
        val output = outputDirectory.resolve("generated/scenario.json")

        try {
            DifferentialFuzzScenarioCli.execute(
                arrayOf(
                    "--seed",
                    "-104729",
                    "--ticks",
                    "3",
                    "--output",
                    output.toString(),
                ),
            )

            val scenario = BehavioralScenarioLoader.load(output)
            assertEquals(-104_729L, scenario.seed)
            assertEquals(3, scenario.ticks)
            assertEquals(3, scenario.inputSegments.size)
        } finally {
            Files.deleteIfExists(output)
            Files.deleteIfExists(output.parent)
            Files.deleteIfExists(outputDirectory)
        }
    }

    @Test(expected = IllegalArgumentException::class)
    fun `CLI rejects a non-positive tick count`() {
        DifferentialFuzzScenarioCli.execute(arrayOf("--seed", "1", "--ticks", "0"))
    }
}
