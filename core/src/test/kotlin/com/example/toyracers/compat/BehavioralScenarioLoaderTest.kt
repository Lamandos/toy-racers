package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonReader
import org.junit.Assert.assertEquals
import org.junit.Test
import java.nio.file.Files

class BehavioralScenarioLoaderTest {
    @Test(expected = IllegalArgumentException::class)
    fun `fixture loader rejects finish position beyond participant count`() {
        BehavioralFixtureLoader.parseScenarioDocument(
            JsonReader().parse(
                """
                {
                  "schemaVersion": 1,
                  "scenarios": [{
                    "id": "invalid-finish-position", "seed": 1, "trackId": "track-01",
                    "playerCar": "red-stripe", "inputOrigin": "keyboard", "tags": [],
                    "ticks": 1, "snapshotIntervalTicks": 1,
                    "inputSegments": [{"fromTick": 1, "toTick": 1}],
                    "initialStates": [{"id": "player", "finished": true, "finishPosition": 7}]
                  }]
                }
                """.trimIndent(),
            ),
        )
    }

    @Test(expected = IllegalArgumentException::class)
    fun `fixture loader rejects duplicate seeded finish positions`() {
        BehavioralFixtureLoader.parseScenarioDocument(
            JsonReader().parse(
                """
                {
                  "schemaVersion": 1,
                  "scenarios": [{
                    "id": "duplicate-finish-position", "seed": 1, "trackId": "track-01",
                    "playerCar": "red-stripe", "inputOrigin": "keyboard", "tags": [],
                    "ticks": 1, "snapshotIntervalTicks": 1,
                    "inputSegments": [{"fromTick": 1, "toTick": 1}],
                    "initialStates": [
                      {"id": "player", "finished": true, "finishPosition": 1},
                      {"id": "ai-0", "finished": true, "finishPosition": 1}
                    ]
                  }]
                }
                """.trimIndent(),
            ),
        )
    }

    @Test(expected = IllegalArgumentException::class)
    fun `fixture loader rejects input tweak tick beyond Int range`() {
        BehavioralFixtureLoader.parseScenarioDocument(
            JsonReader().parse(
                """
                {
                  "schemaVersion": 2,
                  "scenarios": [{
                    "id": "invalid-input-tweak-tick", "seed": 1, "trackId": "track-01",
                    "playerCar": "red-stripe", "inputOrigin": "keyboard", "tags": [],
                    "ticks": 1, "snapshotIntervalTicks": 1,
                    "inputSegments": [{"fromTick": 1, "toTick": 1}],
                    "inputTweaks": [{"tick": 4294967297, "steeringDelta": 0.1}]
                  }]
                }
                """.trimIndent(),
            ),
        )
    }

    @Test(expected = IllegalArgumentException::class)
    fun `fixture loader rejects drift outside normalized range`() {
        BehavioralFixtureLoader.parseScenarioDocument(
            JsonReader().parse(
                """
                {
                  "schemaVersion": 1,
                  "scenarios": [{
                    "id": "invalid-drift", "seed": 1, "trackId": "track-01",
                    "playerCar": "red-stripe", "inputOrigin": "keyboard", "tags": [],
                    "ticks": 1, "snapshotIntervalTicks": 1,
                    "inputSegments": [{"fromTick": 1, "toTick": 1}],
                    "initialStates": [{"id": "player", "driftAmount": 2}]
                  }]
                }
                """.trimIndent(),
            ),
        )
    }

    @Test
    fun `scenario loader normalizes scenario path before resolving input script`() {
        val temporaryDirectory = Files.createTempDirectory("behavioral-scenario")
        try {
            val runnerDirectory = temporaryDirectory.resolve("runner")
            Files.createDirectories(runnerDirectory)
            Files.writeString(runnerDirectory.resolve("scenario.json"), scenarioJson())
            Files.writeString(runnerDirectory.resolve("scripted.json"), scriptJson())

            val scenarioPath = runnerDirectory.resolve("..").resolve("runner").resolve("scenario.json")
            assertEquals("normalized-input-script", BehavioralScenarioLoader.load(scenarioPath).id)
        } finally {
            Files.walk(temporaryDirectory).use { paths ->
                paths.sorted(java.util.Comparator.reverseOrder()).forEach { Files.deleteIfExists(it) }
            }
        }
    }

    @Test
    fun `scenario schema limits finish position to participant count`() {
        val stream = requireNotNull(javaClass.classLoader.getResourceAsStream("compat/scenario.schema.json"))
        val schema = stream.bufferedReader().use(JsonReader()::parse)

        assertEquals(
            6,
            schema
                .get("\$defs")
                .get("initialState")
                .get("properties")
                .get("finishPosition")
                .getInt("maximum"),
        )
    }

    @Test
    fun `scenario schema limits seeded drift to normalized range`() {
        val stream = requireNotNull(javaClass.classLoader.getResourceAsStream("compat/scenario.schema.json"))
        val schema = stream.bufferedReader().use(JsonReader()::parse)
        val drift =
            schema
                .get("\$defs")
                .get("initialState")
                .get("properties")
                .get("driftAmount")

        assertEquals(0, drift.getInt("minimum"))
        assertEquals(1, drift.getInt("maximum"))
    }

    @Test
    fun `scenario loader applies optional input tweaks`() {
        val scenario =
            BehavioralFixtureLoader
                .parseScenarioDocument(
                    JsonReader().parse(
                        """
                        {
                          "schemaVersion": 2,
                          "scenarios": [{
                            "id": "input-tweak", "seed": 1, "trackId": "track-01",
                            "playerCar": "red-stripe", "inputOrigin": "keyboard", "tags": [],
                            "ticks": 2, "snapshotIntervalTicks": 1,
                            "inputSegments": [{"fromTick": 1, "toTick": 2, "throttle": 1}],
                            "inputTweaks": [{"tick": 2, "steeringDelta": 0.005}]
                          }]
                        }
                        """.trimIndent(),
                    ),
                ).single()

        assertEquals(2, scenario.inputTweaks.single().tick)
        assertEquals(0.005f, scenario.inputTweaks.single().steeringDelta, 0.000001f)
    }

    private fun scenarioJson(): String =
        """
        {
          "schemaVersion": 1,
          "scenarios": [{
            "id": "normalized-input-script", "seed": 1, "trackId": "track-01",
            "playerCar": "red-stripe", "inputOrigin": "keyboard", "tags": [],
            "ticks": 1, "snapshotIntervalTicks": 1,
            "inputScript": "scripted.json"
          }]
        }
        """.trimIndent()

    private fun scriptJson(): String =
        """
        {"schemaVersion": 1, "segments": [{"fromTick": 1, "toTick": 1}]}
        """.trimIndent()
}
