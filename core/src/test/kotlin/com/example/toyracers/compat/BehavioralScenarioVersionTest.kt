package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonReader
import com.example.toyracers.compat.BehavioralScenarioLoader.CURRENT_SCENARIO_SCHEMA_VERSION
import com.example.toyracers.compat.BehavioralScenarioLoader.INPUT_TWEAKS_SCHEMA_VERSION
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.file.Files
import java.nio.file.Path

class BehavioralScenarioVersionTest {
    @Test
    fun `scenario v2 accepts input tweaks`() {
        val scenario = parse(scenarioDocument(schemaVersion = INPUT_TWEAKS_SCHEMA_VERSION)).single()

        assertEquals(1, scenario.inputTweaks.size)
        assertEquals(0.1f, scenario.inputTweaks.single().steeringDelta, 0.000001f)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `scenario v1 rejects input tweaks`() {
        parse(scenarioDocument(schemaVersion = BehavioralScenarioLoader.SCHEMA_VERSION))
    }

    @Test(expected = IllegalArgumentException::class)
    fun `scenario v2 rejects input tweak Float overflow`() {
        parse(scenarioDocument(schemaVersion = INPUT_TWEAKS_SCHEMA_VERSION, steeringDelta = "1e100"))
    }

    @Test
    fun `published v2 schema exposes finite Float bounds`() {
        val schema = readSchema()
        val tweakProperties = schema.get("\$defs").get("inputTweak").get("properties")

        assertEquals(INPUT_TWEAKS_SCHEMA_VERSION, schema.get("properties").get("schemaVersion").getInt("const"))
        listOf("throttleDelta", "brakeDelta", "steeringDelta").forEach { field ->
            assertEquals(MIN_FLOAT_VALUE, tweakProperties.get(field).getDouble("minimum"), 0.0)
            assertEquals(MAX_FLOAT_VALUE, tweakProperties.get(field).getDouble("maximum"), 0.0)
        }
        val legacyProperties =
            readLegacySchema()
                .get("\$defs")
                .get("scenario")
                .get("properties")
        assertTrue(legacyProperties.has("fullRace"))
        assertFalse(legacyProperties.has("inputTweaks"))
    }

    @Test
    fun `scenario v3 accepts lap timer seeds`() {
        val scenario = parse(timerScenarioDocument(CURRENT_SCENARIO_SCHEMA_VERSION)).single()
        val initialState = scenario.initialStates.single()

        assertEquals(30f, initialState.lapStartTime ?: -1f, 0f)
        assertEquals(30f, initialState.totalRaceTime ?: -1f, 0f)
        assertEquals(10f, initialState.bestLapTime ?: -1f, 0f)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `scenario v2 rejects lap timer seeds`() {
        parse(timerScenarioDocument(INPUT_TWEAKS_SCHEMA_VERSION))
    }

    @Test(expected = IllegalArgumentException::class)
    fun `scenario v3 rejects lap start after total race time`() {
        parse(timerScenarioDocument(CURRENT_SCENARIO_SCHEMA_VERSION, lapStartTime = "31"))
    }

    @Test
    fun `published v3 schema exposes lap timer seeds`() {
        val timerProperties = readTimerSchema().get("\$defs").get("initialState").get("properties")
        val v2Properties = readSchema().get("\$defs").get("initialState").get("properties")

        assertTrue(timerProperties.has("lapStartTime"))
        assertTrue(timerProperties.has("bestLapTime"))
        assertFalse(v2Properties.has("lapStartTime"))
        assertFalse(v2Properties.has("bestLapTime"))
    }

    @Test
    fun `published scenario schemas match loader contracts`() {
        listOf("scenario.schema.json", "scenario-v2.schema.json", "scenario-v3.schema.json").forEach { fileName ->
            assertEquals(readResourceText("compat/$fileName"), Files.readString(publishedSchema(fileName)))
        }
    }

    private fun parse(document: String): List<BehavioralScenario> =
        BehavioralScenarioLoader.parseScenarioDocument(JsonReader().parse(document)) {
            error("Input scripts are not used by this test")
        }

    private fun scenarioDocument(
        schemaVersion: Int,
        steeringDelta: String = "0.1",
    ): String =
        """
        {
          "schemaVersion": $schemaVersion,
          "scenarios": [{
            "id": "versioned-scenario",
            "seed": 1,
            "trackId": "track-01",
            "playerCar": "red-stripe",
            "inputOrigin": "keyboard",
            "tags": [],
            "ticks": 1,
            "snapshotIntervalTicks": 1,
            "inputSegments": [{"fromTick": 1, "toTick": 1}],
            "inputTweaks": [{"tick": 1, "steeringDelta": $steeringDelta}]
          }]
        }
        """.trimIndent()

    private fun timerScenarioDocument(
        schemaVersion: Int,
        lapStartTime: String = "30",
    ): String =
        """
        {
          "schemaVersion": $schemaVersion,
          "scenarios": [{
            "id": "timer-seeded-scenario",
            "seed": 1,
            "trackId": "track-01",
            "playerCar": "red-stripe",
            "inputOrigin": "keyboard",
            "tags": [],
            "ticks": 1,
            "snapshotIntervalTicks": 1,
            "inputSegments": [{"fromTick": 1, "toTick": 1}],
            "initialStates": [{
              "id": "player",
              "lapStartTime": $lapStartTime,
              "totalRaceTime": 30,
              "bestLapTime": 10
            }]
          }]
        }
        """.trimIndent()

    private fun readSchema() = readResource("compat/scenario-v2.schema.json")

    private fun readTimerSchema() = readResource("compat/scenario-v3.schema.json")

    private fun readLegacySchema() = readResource("compat/scenario.schema.json")

    private fun readResource(path: String) =
        requireNotNull(javaClass.classLoader.getResourceAsStream(path)).bufferedReader().use(JsonReader()::parse)

    private fun readResourceText(path: String): String =
        requireNotNull(javaClass.classLoader.getResourceAsStream(path)).bufferedReader().use { it.readText() }

    private fun publishedSchema(fileName: String): Path =
        Path.of(requireNotNull(System.getProperty("compatibilityDirectory")), "schemas", fileName)

    private companion object {
        const val MAX_FLOAT_VALUE = 3.4028234663852886E38
        const val MIN_FLOAT_VALUE = -MAX_FLOAT_VALUE
    }
}
