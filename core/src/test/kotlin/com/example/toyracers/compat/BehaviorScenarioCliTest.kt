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

    @Test
    fun `state machine scenario samples lifecycle before physical ticks`() {
        val scenario =
            BehavioralScenario(
                id = "race-state-machine-lifecycle",
                seed = 10001L,
                trackId = "track-01",
                playerCar = "red-stripe",
                inputOrigin = "keyboard",
                tags = setOf("state-machine"),
                ticks = 30,
                snapshotIntervalTicks = 10,
                inputSegments =
                    listOf(
                        BehavioralInputSegment(
                            fromTick = 1,
                            toTick = 30,
                            input = BehavioralInput(throttle = 1f),
                        ),
                    ),
                initialStates = emptyList(),
                fullRace = false,
            )

        val preRaceSamples =
            BehavioralScenarioRunner()
                .run(scenario)
                .samples
                .takeWhile { it.snapshot.simulationTick == 0 }

        assertEquals(
            listOf("loading", "ready", "countdown", "countdown", "countdown", "countdown", "racing"),
            preRaceSamples.map { it.snapshot.raceState },
        )
        assertEquals(3f, preRaceSamples[2].snapshot.countdown.remainingSeconds, 0.000001f)
        assertEquals(2f, preRaceSamples[3].snapshot.countdown.remainingSeconds, 0.000001f)
        assertEquals(1f, preRaceSamples[4].snapshot.countdown.remainingSeconds, 0.000001f)
        assertTrue(preRaceSamples[5].snapshot.countdown.remainingSeconds < 1f)
        val goSnapshot = preRaceSamples.last().snapshot
        assertEquals(0f, goSnapshot.countdown.remainingSeconds, 0.000001f)
    }

    private fun resourcePath(resource: String): Path =
        Path.of(requireNotNull(javaClass.classLoader.getResource(resource)).toURI())
}
