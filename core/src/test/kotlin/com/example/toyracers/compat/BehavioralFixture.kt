package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonReader
import com.badlogic.gdx.utils.JsonValue

internal data class BehavioralScenario(
    val id: String,
    val seed: Long,
    val trackId: String,
    val playerCar: String,
    val inputOrigin: String,
    val tags: Set<String>,
    val ticks: Int,
    val snapshotIntervalTicks: Int,
    val inputSegments: List<BehavioralInputSegment>,
    val initialStates: List<BehavioralInitialState>,
    val fullRace: Boolean,
)

internal data class BehavioralInputSegment(
    val fromTick: Int,
    val toTick: Int,
    val input: BehavioralInput,
) {
    fun contains(tick: Int): Boolean = tick in fromTick..toTick
}

internal object BehavioralFixtureLoader {
    const val SCHEMA_VERSION = 1
    const val FIXTURE_RESOURCE = "compat/scenarios.json"
    const val GOLDEN_RESOURCE = "compat/goldens.json"

    fun scenarios(): List<BehavioralScenario> {
        val root = readJson(FIXTURE_RESOURCE)
        require(root.getInt("schemaVersion") == SCHEMA_VERSION) {
            "Unsupported scenario schema version"
        }
        return root.get("scenarios").children().map(::scenario)
    }

    fun goldens(): JsonValue {
        val root = readJson(GOLDEN_RESOURCE)
        require(root.getInt("schemaVersion") == SCHEMA_VERSION) {
            "Unsupported golden schema version"
        }
        return root
    }

    private fun scenario(value: JsonValue): BehavioralScenario =
        BehavioralScenario(
            id = value.getString("id"),
            seed = value.getLong("seed"),
            trackId = value.getString("trackId"),
            playerCar = value.getString("playerCar"),
            inputOrigin = value.getString("inputOrigin"),
            tags =
                value
                    .get("tags")
                    .children()
                    .map(JsonValue::asString)
                    .toSet(),
            ticks = value.getInt("ticks"),
            snapshotIntervalTicks = value.getInt("snapshotIntervalTicks"),
            inputSegments = inputSegments(value),
            initialStates =
                value
                    .get("initialStates")
                    ?.children()
                    ?.map(::initialState)
                    .orEmpty(),
            fullRace = value.getBoolean("fullRace", false),
        ).also(::validateScenario)

    private fun inputSegment(value: JsonValue): BehavioralInputSegment =
        BehavioralInputSegment(
            fromTick = value.getInt("fromTick"),
            toTick = value.getInt("toTick"),
            input =
                BehavioralInput(
                    throttle = value.getFloat("throttle", 0f),
                    brake = value.getFloat("brake", 0f),
                    steering = value.getFloat("steering", 0f),
                ),
        )

    private fun inputSegments(value: JsonValue): List<BehavioralInputSegment> =
        value.get("inputSegments")?.children()?.map(::inputSegment)
            ?: scriptedInputSegments(value)

    private fun scriptedInputSegments(value: JsonValue): List<BehavioralInputSegment> {
        val script =
            requireNotNull(value.get("inputScript")) {
                "Scenario ${value.getString("id")} needs inputSegments or inputScript"
            }.asString()
        val root = readJson("compat/$script")
        require(root.getInt("schemaVersion") == SCHEMA_VERSION) {
            "Unsupported input script schema version"
        }
        return root.get("segments").children().map(::inputSegment)
    }

    private fun initialState(value: JsonValue): BehavioralInitialState =
        BehavioralInitialState(
            id = value.getString("id"),
            x = value.floatOrNull("x"),
            y = value.floatOrNull("y"),
            rotationDeg = value.floatOrNull("rotationDeg"),
            speed = value.floatOrNull("speed"),
            velocityX = value.floatOrNull("velocityX"),
            velocityY = value.floatOrNull("velocityY"),
            angularVelocity = value.floatOrNull("angularVelocity"),
            lateralSpeed = value.floatOrNull("lateralSpeed"),
            driftAmount = value.floatOrNull("driftAmount"),
            surfaceSpeedMultiplier = value.floatOrNull("surfaceSpeedMultiplier"),
            currentCheckpointIndex = value.intOrNull("currentCheckpointIndex"),
            completedLaps = value.intOrNull("completedLaps"),
            totalRaceTime = value.floatOrNull("totalRaceTime"),
            finished = value.booleanOrNull("finished"),
            finishPosition = value.intOrNull("finishPosition"),
        )

    private fun readJson(resource: String): JsonValue {
        val stream =
            requireNotNull(javaClass.classLoader.getResourceAsStream(resource)) {
                "Missing behavioral fixture resource: $resource"
            }
        return stream.bufferedReader().use(JsonReader()::parse)
    }

    private fun JsonValue.floatOrNull(name: String): Float? = get(name)?.asFloat()

    private fun JsonValue.intOrNull(name: String): Int? = get(name)?.asInt()

    private fun JsonValue.booleanOrNull(name: String): Boolean? = get(name)?.asBoolean()

    private fun JsonValue.children(): List<JsonValue> = generateSequence(child) { it.next }.toList()

    private fun validateScenario(scenario: BehavioralScenario) {
        require(SCENARIO_ID.matches(scenario.id)) { "Invalid scenario ID: ${scenario.id}" }
        require(scenario.inputOrigin in INPUT_ORIGINS) { "Unknown input origin: ${scenario.inputOrigin}" }
        require(scenario.ticks > 0) { "Scenario ${scenario.id} must have positive ticks" }
        require(scenario.snapshotIntervalTicks > 0) {
            "Scenario ${scenario.id} must have a positive snapshot interval"
        }
        require(scenario.inputSegments.isNotEmpty()) { "Scenario ${scenario.id} has no input segments" }
        scenario.inputSegments.forEach { segment ->
            require(segment.fromTick in 1..scenario.ticks && segment.toTick in segment.fromTick..scenario.ticks) {
                "Scenario ${scenario.id} has an invalid input range ${segment.fromTick}..${segment.toTick}"
            }
        }
        require(scenario.inputSegments.zipWithNext().all { (first, second) -> first.toTick < second.fromTick }) {
            "Scenario ${scenario.id} has overlapping or unordered input ranges"
        }
    }

    private val SCENARIO_ID = Regex("[a-z0-9]+(?:-[a-z0-9]+)*")
    private val INPUT_ORIGINS = setOf("keyboard", "touch")
}
