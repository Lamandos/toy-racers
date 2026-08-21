package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonReader
import com.badlogic.gdx.utils.JsonValue
import com.example.toyracers.car.CarModel
import com.example.toyracers.track.TrackId

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
        validateScenarioDocument(root)
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
        validateInputScript(root, "compat/$script")
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

    private fun validateScenarioDocument(root: JsonValue) {
        require(root.isObject) { "Scenario document must be an object" }
        root.requireProperties(ROOT_PROPERTIES, "$")
        val schemaVersion = root.required("schemaVersion", "$")
        requireInteger(schemaVersion, "$.schemaVersion")
        require(schemaVersion.asLong() == SCHEMA_VERSION.toLong()) {
            "Unsupported scenario schema version"
        }
        val scenarios = root.required("scenarios", "$")
        require(scenarios.isArray && scenarios.size > 0) {
            "$.scenarios must be a non-empty array"
        }
        scenarios.children().forEachIndexed { index, scenario ->
            validateScenarioJson(scenario, "$.scenarios[$index]")
        }
    }

    private fun validateScenarioJson(
        value: JsonValue,
        path: String,
    ) {
        require(value.isObject) { "$path must be an object" }
        value.requireProperties(SCENARIO_PROPERTIES, path)
        val id = value.required("id", path)
        requireString(id, "$path.id")
        require(SCENARIO_ID.matches(id.asString())) { "$path.id has an invalid format" }
        requireEnum(value.required("trackId", path), "$path.trackId", TRACK_IDS)
        requireEnum(value.required("playerCar", path), "$path.playerCar", PLAYER_CARS)
        requireEnum(value.required("inputOrigin", path), "$path.inputOrigin", INPUT_ORIGINS)
        requireInteger(
            value.required("seed", path),
            "$path.seed",
            minimum = Long.MIN_VALUE,
            maximum = Long.MAX_VALUE,
        )
        requireInteger(
            value.required("ticks", path),
            "$path.ticks",
            minimum = 1,
            maximum = MAX_INT_VALUE,
        )
        requireInteger(
            value.required("snapshotIntervalTicks", path),
            "$path.snapshotIntervalTicks",
            minimum = 1,
            maximum = MAX_INT_VALUE,
        )
        validateTags(value.required("tags", path), "$path.tags")

        val hasSegments = value.has("inputSegments")
        val hasScript = value.has("inputScript")
        require(hasSegments xor hasScript) {
            "$path must contain exactly one of inputSegments or inputScript"
        }
        if (hasSegments) {
            validateInputSegments(value.required("inputSegments", path), "$path.inputSegments")
        } else {
            val script = value.required("inputScript", path)
            requireString(script, "$path.inputScript")
            require(INPUT_SCRIPT.matches(script.asString())) {
                "$path.inputScript has an invalid file name"
            }
        }

        value.get("initialStates")?.let { validateInitialStates(it, "$path.initialStates") }
        value.get("fullRace")?.let { requireBoolean(it, "$path.fullRace") }
    }

    private fun validateInputScript(
        root: JsonValue,
        path: String,
    ) {
        require(root.isObject) { "$path must be an object" }
        root.requireProperties(INPUT_SCRIPT_PROPERTIES, path)
        requireInteger(root.required("schemaVersion", path), "$path.schemaVersion")
        require(root.getLong("schemaVersion") == SCHEMA_VERSION.toLong()) {
            "Unsupported input script schema version"
        }
        validateInputSegments(root.required("segments", path), "$path.segments")
    }

    private fun validateInputSegments(
        value: JsonValue,
        path: String,
    ) {
        require(value.isArray && value.size > 0) { "$path must be a non-empty array" }
        value.children().forEachIndexed { index, segment ->
            val segmentPath = "$path[$index]"
            require(segment.isObject) { "$segmentPath must be an object" }
            segment.requireProperties(INPUT_SEGMENT_PROPERTIES, segmentPath)
            requireInteger(
                segment.required("fromTick", segmentPath),
                "$segmentPath.fromTick",
                minimum = 1,
                maximum = MAX_INT_VALUE,
            )
            requireInteger(
                segment.required("toTick", segmentPath),
                "$segmentPath.toTick",
                minimum = 1,
                maximum = MAX_INT_VALUE,
            )
            listOf("throttle", "brake", "steering").forEach { name ->
                segment.get(name)?.let { requireNumber(it, "$segmentPath.$name") }
            }
        }
    }

    private fun validateInitialStates(
        value: JsonValue,
        path: String,
    ) {
        require(value.isArray) { "$path must be an array" }
        value.children().forEachIndexed { index, initialState ->
            val statePath = "$path[$index]"
            require(initialState.isObject) { "$statePath must be an object" }
            initialState.requireProperties(INITIAL_STATE_PROPERTIES, statePath)
            requireEnum(initialState.required("id", statePath), "$statePath.id", INITIAL_STATE_IDS)
            listOf(
                "x",
                "y",
                "rotationDeg",
                "speed",
                "velocityX",
                "velocityY",
                "angularVelocity",
                "lateralSpeed",
                "driftAmount",
            ).forEach { name ->
                initialState.get(name)?.let { requireNumber(it, "$statePath.$name") }
            }
            initialState.get("surfaceSpeedMultiplier")?.let {
                requireNumber(it, "$statePath.surfaceSpeedMultiplier", minimum = 0.0, maximum = 1.0)
            }
            initialState.get("totalRaceTime")?.let {
                requireNumber(it, "$statePath.totalRaceTime", minimum = 0.0)
            }
            initialState.get("currentCheckpointIndex")?.let {
                requireInteger(
                    it,
                    "$statePath.currentCheckpointIndex",
                    minimum = 0,
                    maximum = MAX_INT_VALUE,
                )
            }
            initialState.get("completedLaps")?.let {
                requireInteger(
                    it,
                    "$statePath.completedLaps",
                    minimum = 0,
                    maximum = MAX_INT_VALUE,
                )
            }
            initialState.get("finishPosition")?.let {
                requireInteger(
                    it,
                    "$statePath.finishPosition",
                    minimum = 1,
                    maximum = MAX_INT_VALUE,
                )
            }
            initialState.get("finished")?.let { requireBoolean(it, "$statePath.finished") }
        }
    }

    private fun validateTags(
        value: JsonValue,
        path: String,
    ) {
        require(value.isArray) { "$path must be an array" }
        val tags =
            value.children().mapIndexed { index, tag ->
                requireString(tag, "$path[$index]")
                tag.asString()
            }
        require(tags.size == tags.toSet().size) { "$path must not contain duplicate tags" }
    }

    private fun JsonValue.requireProperties(
        allowed: Set<String>,
        path: String,
    ) {
        children().forEach { property ->
            val name = requireNotNull(property.name) { "$path contains an unnamed property" }
            require(name in allowed) { "$path.$name is not allowed by the scenario schema" }
        }
    }

    private fun JsonValue.required(
        name: String,
        path: String,
    ): JsonValue = requireNotNull(get(name)) { "$path.$name is required" }

    private fun requireString(
        value: JsonValue,
        path: String,
    ) {
        require(value.isString) { "$path must be a string" }
    }

    private fun requireNumber(
        value: JsonValue,
        path: String,
        minimum: Double? = null,
        maximum: Double? = null,
    ) {
        require(value.isNumber) { "$path must be a number" }
        val number = value.asDouble()
        minimum?.let { require(number >= it) { "$path must be at least $it" } }
        maximum?.let { require(number <= it) { "$path must be at most $it" } }
    }

    private fun requireEnum(
        value: JsonValue,
        path: String,
        allowed: Set<String>,
    ) {
        requireString(value, path)
        require(value.asString() in allowed) { "$path has an unsupported value: ${value.asString()}" }
    }

    private fun requireInteger(
        value: JsonValue,
        path: String,
        minimum: Long? = null,
        maximum: Long? = null,
    ) {
        require(value.isLong) { "$path must be an integer" }
        minimum?.let { require(value.asLong() >= it) { "$path must be at least $it" } }
        maximum?.let { require(value.asLong() <= it) { "$path must be at most $it" } }
    }

    private fun requireBoolean(
        value: JsonValue,
        path: String,
    ) {
        require(value.isBoolean) { "$path must be a boolean" }
    }

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

    private const val MAX_INT_VALUE = 2147483647L
    private val SCENARIO_ID = Regex("[a-z0-9]+(?:-[a-z0-9]+)*")
    private val INPUT_SCRIPT = Regex("[a-z0-9][a-z0-9-]*\\.json")
    private val TRACK_IDS = TrackId.entries.map(TrackId::value).toSet()
    private val PLAYER_CARS = CarModel.entries.map(CarModel::scenarioId).toSet()
    private val INPUT_ORIGINS = setOf("keyboard", "touch")
    private val INITIAL_STATE_IDS = setOf("player", "ai-0", "ai-1", "ai-2", "ai-3", "ai-4")
    private val ROOT_PROPERTIES = setOf("schemaVersion", "scenarios")
    private val INPUT_SCRIPT_PROPERTIES = setOf("schemaVersion", "segments")
    private val INPUT_SEGMENT_PROPERTIES = setOf("fromTick", "toTick", "throttle", "brake", "steering")
    private val INITIAL_STATE_PROPERTIES =
        setOf(
            "id",
            "x",
            "y",
            "rotationDeg",
            "speed",
            "velocityX",
            "velocityY",
            "angularVelocity",
            "lateralSpeed",
            "driftAmount",
            "surfaceSpeedMultiplier",
            "currentCheckpointIndex",
            "completedLaps",
            "totalRaceTime",
            "finished",
            "finishPosition",
        )
    private val SCENARIO_PROPERTIES =
        setOf(
            "id",
            "seed",
            "trackId",
            "playerCar",
            "inputOrigin",
            "tags",
            "ticks",
            "snapshotIntervalTicks",
            "inputSegments",
            "inputScript",
            "initialStates",
            "fullRace",
        )
}
