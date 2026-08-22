package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonReader
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.file.Files
import java.nio.file.Path

class BehaviorScenarioCliTest {
    @Test
    fun `runner replays file scenario and writes a normalized trace`() {
        val outputDirectory = Files.createTempDirectory("behavior-scenario-")
        val output = outputDirectory.resolve("actual.json")

        try {
            BehaviorScenarioCli.execute(
                arrayOf(
                    "--scenario",
                    resourcePath("compat/runner/scripted-acceleration.json").toString(),
                    "--output",
                    output.toString(),
                ),
            )

            val trace = Files.newBufferedReader(output).use(JsonReader()::parse)
            assertEquals(BehavioralTraceJson.SCHEMA_VERSION, trace.getInt("schemaVersion"))
            assertEquals("scripted-acceleration", trace.getString("scenarioId"))
            assertEquals(42L, trace.getLong("seed"))
            assertEquals(3, trace.get("samples").get(4).getInt("tick"))
            val player =
                trace
                    .get("samples")
                    .get(4)
                    .get("snapshot")
                    .get("participants")
                    .get(5)
            assertTrue(player.getFloat("longitudinalSpeed") > 0f)
        } finally {
            Files.deleteIfExists(output)
            Files.deleteIfExists(outputDirectory)
        }
    }

    @Test(expected = IllegalArgumentException::class)
    fun `runner requires both command options`() {
        BehaviorScenarioCli.execute(arrayOf("--scenario", "scenario.json"))
    }

    @Test
    fun `runner records the requested final tick after a race finish`() {
        val scenario =
            BehavioralFixtureLoader.scenarios().single { it.id == "track-living-room-finish" }

        val trace = BehavioralScenarioRunner(continueAfterFinish = true).run(scenario)

        assertTrue(trace.samples.any { it.snapshot.raceState == "finished" })
        assertEquals(scenario.ticks, trace.samples.last().tick)
    }

    private fun resourcePath(resource: String): Path =
        Path.of(requireNotNull(javaClass.classLoader.getResource(resource)).toURI())
}
