package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonReader
import com.example.toyracers.compat.BehavioralScenarioLoader.CURRENT_SCENARIO_SCHEMA_VERSION
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BehavioralScenarioVersionTest {
    @Test
    fun `scenario v2 accepts input tweaks`() {
        val scenario = parse(scenarioDocument(schemaVersion = CURRENT_SCENARIO_SCHEMA_VERSION)).single()

        assertEquals(1, scenario.inputTweaks.size)
        assertEquals(0.1f, scenario.inputTweaks.single().steeringDelta, 0.000001f)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `scenario v1 rejects input tweaks`() {
        parse(scenarioDocument(schemaVersion = BehavioralScenarioLoader.SCHEMA_VERSION))
    }

    @Test(expected = IllegalArgumentException::class)
    fun `scenario v2 rejects input tweak Float overflow`() {
        parse(scenarioDocument(schemaVersion = CURRENT_SCENARIO_SCHEMA_VERSION, steeringDelta = "1e100"))
    }

    @Test
    fun `published v2 schema exposes finite Float bounds`() {
        val schema = readSchema()
        val tweakProperties = schema.get("\$defs").get("inputTweak").get("properties")

        assertEquals(CURRENT_SCENARIO_SCHEMA_VERSION, schema.get("properties").get("schemaVersion").getInt("const"))
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

    private fun readSchema() = readResource("compat/scenario-v2.schema.json")

    private fun readLegacySchema() = readResource("compat/scenario.schema.json")

    private fun readResource(path: String) =
        requireNotNull(javaClass.classLoader.getResourceAsStream(path)).bufferedReader().use(JsonReader()::parse)

    private companion object {
        const val MAX_FLOAT_VALUE = 3.4028234663852886E38
        const val MIN_FLOAT_VALUE = -MAX_FLOAT_VALUE
    }
}
