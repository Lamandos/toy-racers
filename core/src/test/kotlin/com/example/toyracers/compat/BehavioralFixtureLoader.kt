package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonReader
import com.badlogic.gdx.utils.JsonValue

/** Test-fixture access kept separate from the production scenario-file loader. */
internal object BehavioralFixtureLoader {
    const val SCHEMA_VERSION = BehavioralScenarioLoader.SCHEMA_VERSION
    const val GOLDEN_SCHEMA_VERSION = BehavioralTraceJson.SCHEMA_VERSION
    private const val FIXTURE_RESOURCE = "compat/scenarios.json"
    private const val GOLDEN_RESOURCE = "compat/goldens.json"

    fun scenarios(): List<BehavioralScenario> =
        BehavioralScenarioLoader.parseScenarioDocument(readJson(FIXTURE_RESOURCE), ::readInputScript)

    fun goldens(): JsonValue {
        val root = readJson(GOLDEN_RESOURCE)
        require(root.getInt("schemaVersion") == GOLDEN_SCHEMA_VERSION) {
            "Unsupported golden schema version"
        }
        return root
    }

    fun parseScenarioDocument(root: JsonValue): List<BehavioralScenario> =
        BehavioralScenarioLoader.parseScenarioDocument(root, ::readInputScript)

    private fun readInputScript(script: String): JsonValue = readJson("compat/$script")

    private fun readJson(resource: String): JsonValue {
        val stream =
            requireNotNull(javaClass.classLoader.getResourceAsStream(resource)) {
                "Missing behavioral fixture resource: $resource"
            }
        return stream.bufferedReader().use(JsonReader()::parse)
    }
}
