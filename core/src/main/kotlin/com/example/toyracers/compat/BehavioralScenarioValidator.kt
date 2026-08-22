package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonValue
import com.example.toyracers.car.CarModel
import com.example.toyracers.race.RaceRules
import com.example.toyracers.track.TrackId
import com.example.toyracers.track.TrackLoader

/** Validates the portable scenario contract before the simulation begins. */
internal object BehavioralScenarioValidator {
    fun validateDocument(root: JsonValue) {
        require(root.isObject) { "Scenario document must be an object" }
        root.requireProperties(ROOT_PROPERTIES, "$")
        val schemaVersion = root.required(SCHEMA_VERSION_FIELD, "$")
        requireInteger(schemaVersion, "$.schemaVersion")
        require(schemaVersion.asLong() == BehavioralScenarioLoader.SCHEMA_VERSION.toLong()) {
            "Unsupported scenario schema version"
        }
        val scenarios = root.required(SCENARIOS_FIELD, "$")
        require(scenarios.isArray && scenarios.size > 0) { "$.scenarios must be a non-empty array" }
        scenarios.children().forEachIndexed { index, scenario ->
            validateScenarioJson(scenario, "$.scenarios[$index]")
        }
    }

    fun validateInputScript(
        root: JsonValue,
        path: String,
    ) {
        require(root.isObject) { "$path must be an object" }
        root.requireProperties(INPUT_SCRIPT_PROPERTIES, path)
        requireInteger(root.required(SCHEMA_VERSION_FIELD, path), "$path.$SCHEMA_VERSION_FIELD")
        require(root.getLong(SCHEMA_VERSION_FIELD) == BehavioralScenarioLoader.SCHEMA_VERSION.toLong()) {
            "Unsupported input script schema version"
        }
        validateInputSegments(root.required(SEGMENTS_FIELD, path), "$path.$SEGMENTS_FIELD")
    }

    fun validate(scenario: BehavioralScenario) {
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

    private fun validateScenarioJson(
        value: JsonValue,
        path: String,
    ) {
        require(value.isObject) { "$path must be an object" }
        value.requireProperties(SCENARIO_PROPERTIES, path)
        val id = value.required(ID_FIELD, path)
        requireString(id, "$path.$ID_FIELD")
        require(SCENARIO_ID.matches(id.asString())) { "$path.$ID_FIELD has an invalid format" }
        requireEnum(value.required(TRACK_ID_FIELD, path), "$path.$TRACK_ID_FIELD", TRACK_IDS)
        requireEnum(value.required(PLAYER_CAR_FIELD, path), "$path.$PLAYER_CAR_FIELD", PLAYER_CARS)
        requireEnum(value.required(INPUT_ORIGIN_FIELD, path), "$path.$INPUT_ORIGIN_FIELD", INPUT_ORIGINS)
        requireInteger(value.required(SEED_FIELD, path), "$path.$SEED_FIELD", Long.MIN_VALUE, Long.MAX_VALUE)
        requireInteger(value.required(TICKS_FIELD, path), "$path.$TICKS_FIELD", 1, MAX_INT_VALUE)
        requireInteger(
            value.required(SNAPSHOT_INTERVAL_TICKS_FIELD, path),
            "$path.$SNAPSHOT_INTERVAL_TICKS_FIELD",
            1,
            MAX_INT_VALUE,
        )
        validateTags(value.required(TAGS_FIELD, path), "$path.$TAGS_FIELD")

        val hasSegments = value.has(INPUT_SEGMENTS_FIELD)
        val hasScript = value.has(INPUT_SCRIPT_FIELD)
        require(hasSegments xor hasScript) {
            "$path must contain exactly one of $INPUT_SEGMENTS_FIELD or $INPUT_SCRIPT_FIELD"
        }
        if (hasSegments) {
            validateInputSegments(
                value.required(INPUT_SEGMENTS_FIELD, path),
                "$path.$INPUT_SEGMENTS_FIELD",
            )
        } else {
            val script = value.required(INPUT_SCRIPT_FIELD, path)
            requireString(script, "$path.$INPUT_SCRIPT_FIELD")
            require(INPUT_SCRIPT.matches(script.asString())) {
                "$path.$INPUT_SCRIPT_FIELD has an invalid file name"
            }
        }

        value.get(INITIAL_STATES_FIELD)?.let {
            validateInitialStates(it, "$path.$INITIAL_STATES_FIELD", value.getString(TRACK_ID_FIELD))
        }
        value.get(FULL_RACE_FIELD)?.let { requireBoolean(it, "$path.$FULL_RACE_FIELD") }
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
                segment.required(FROM_TICK_FIELD, segmentPath),
                "$segmentPath.$FROM_TICK_FIELD",
                1,
                MAX_INT_VALUE,
            )
            requireInteger(
                segment.required(TO_TICK_FIELD, segmentPath),
                "$segmentPath.$TO_TICK_FIELD",
                1,
                MAX_INT_VALUE,
            )
            INPUT_FIELDS.forEach { name ->
                segment.get(name)?.let { requireNumber(it, "$segmentPath.$name") }
            }
        }
    }

    private fun validateInitialStates(
        value: JsonValue,
        path: String,
        trackId: String,
    ) {
        require(value.isArray) { "$path must be an array" }
        val maxCheckpointIndex = TRACK_CHECKPOINT_COUNTS.getValue(trackId).toLong()
        value.children().forEachIndexed { index, initialState ->
            val statePath = "$path[$index]"
            require(initialState.isObject) { "$statePath must be an object" }
            initialState.requireProperties(INITIAL_STATE_PROPERTIES, statePath)
            requireEnum(initialState.required(ID_FIELD, statePath), "$statePath.$ID_FIELD", INITIAL_STATE_IDS)
            FLOAT_INITIAL_STATE_FIELDS.forEach { name ->
                initialState.get(name)?.let { requireFloat(it, "$statePath.$name") }
            }
            initialState.get(SURFACE_SPEED_MULTIPLIER_FIELD)?.let {
                requireFloat(it, "$statePath.$SURFACE_SPEED_MULTIPLIER_FIELD", 0.0, 1.0)
            }
            initialState.get(TOTAL_RACE_TIME_FIELD)?.let {
                requireFloat(it, "$statePath.$TOTAL_RACE_TIME_FIELD", 0.0)
            }
            initialState.get(CURRENT_CHECKPOINT_INDEX_FIELD)?.let {
                requireInteger(it, "$statePath.$CURRENT_CHECKPOINT_INDEX_FIELD", 0, maxCheckpointIndex)
            }
            initialState.get(COMPLETED_LAPS_FIELD)?.let {
                requireInteger(it, "$statePath.$COMPLETED_LAPS_FIELD", 0, RaceRules.DEFAULT_LAP_COUNT.toLong())
            }
            initialState.get(FINISH_POSITION_FIELD)?.let {
                requireInteger(it, "$statePath.$FINISH_POSITION_FIELD", 1, MAX_INT_VALUE)
            }
            initialState.get(FINISHED_FIELD)?.let { requireBoolean(it, "$statePath.$FINISHED_FIELD") }
            val finished = initialState.get(FINISHED_FIELD)?.asBoolean() ?: false
            val hasFinishPosition = initialState.get(FINISH_POSITION_FIELD) != null
            require(!finished || hasFinishPosition) {
                "$statePath.$FINISH_POSITION_FIELD is required when $FINISHED_FIELD is true"
            }
            require(!hasFinishPosition || finished) {
                "$statePath.$FINISHED_FIELD must be true when $FINISH_POSITION_FIELD is provided"
            }
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
        val number = numericValue(value, path)
        minimum?.let { require(number >= it) { "$path must be at least $it" } }
        maximum?.let { require(number <= it) { "$path must be at most $it" } }
    }

    private fun requireFloat(
        value: JsonValue,
        path: String,
        minimum: Double? = null,
        maximum: Double? = null,
    ) {
        val number = numericValue(value, path)
        require(number in -MAX_FLOAT_VALUE..MAX_FLOAT_VALUE) { "$path must fit in a finite Float" }
        minimum?.let { require(number >= it) { "$path must be at least $it" } }
        maximum?.let { require(number <= it) { "$path must be at most $it" } }
    }

    private fun numericValue(
        value: JsonValue,
        path: String,
    ): Double {
        require(value.isNumber) { "$path must be a number" }
        val number = value.asDouble()
        require(number.isFinite()) { "$path must be finite" }
        return number
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
        val integer =
            if (value.isLong) {
                value.asLong()
            } else {
                val number = numericValue(value, path)
                require(number % 1.0 == 0.0) { "$path must be an integer" }
                require(number >= MIN_LONG_AS_DOUBLE && number < POSITIVE_LONG_LIMIT) {
                    "$path must fit in a signed 64-bit integer"
                }
                number.toLong()
            }
        minimum?.let { require(integer >= it) { "$path must be at least $it" } }
        maximum?.let { require(integer <= it) { "$path must be at most $it" } }
    }

    private fun requireBoolean(
        value: JsonValue,
        path: String,
    ) {
        require(value.isBoolean) { "$path must be a boolean" }
    }

    private fun JsonValue.children(): List<JsonValue> = generateSequence(child) { it.next }.toList()

    private const val MAX_INT_VALUE = 2147483647L
    private const val MAX_FLOAT_VALUE = 3.4028234663852886E38
    private const val MIN_LONG_AS_DOUBLE = -9.223372036854776E18
    private const val POSITIVE_LONG_LIMIT = 9.223372036854776E18
    private const val SCHEMA_VERSION_FIELD = "schemaVersion"
    private const val SCENARIOS_FIELD = "scenarios"
    private const val ID_FIELD = "id"
    private const val TRACK_ID_FIELD = "trackId"
    private const val PLAYER_CAR_FIELD = "playerCar"
    private const val INPUT_ORIGIN_FIELD = "inputOrigin"
    private const val SEED_FIELD = "seed"
    private const val TICKS_FIELD = "ticks"
    private const val SNAPSHOT_INTERVAL_TICKS_FIELD = "snapshotIntervalTicks"
    private const val TAGS_FIELD = "tags"
    private const val INPUT_SEGMENTS_FIELD = "inputSegments"
    private const val INPUT_SCRIPT_FIELD = "inputScript"
    private const val INITIAL_STATES_FIELD = "initialStates"
    private const val FULL_RACE_FIELD = "fullRace"
    private const val SEGMENTS_FIELD = "segments"
    private const val FROM_TICK_FIELD = "fromTick"
    private const val TO_TICK_FIELD = "toTick"
    private const val SURFACE_SPEED_MULTIPLIER_FIELD = "surfaceSpeedMultiplier"
    private const val TOTAL_RACE_TIME_FIELD = "totalRaceTime"
    private const val CURRENT_CHECKPOINT_INDEX_FIELD = "currentCheckpointIndex"
    private const val COMPLETED_LAPS_FIELD = "completedLaps"
    private const val FINISH_POSITION_FIELD = "finishPosition"
    private const val FINISHED_FIELD = "finished"
    private val SCENARIO_ID = Regex("[a-z0-9]+(?:-[a-z0-9]+)*")
    private val INPUT_SCRIPT = Regex("[a-z0-9][a-z0-9-]*\\.json")
    private val TRACK_IDS = TrackId.entries.map(TrackId::value).toSet()
    private val PLAYER_CARS = CarModel.entries.map(CarModel::scenarioId).toSet()
    private val INPUT_ORIGINS = setOf("keyboard", "touch")
    private val INITIAL_STATE_IDS = setOf("player", "ai-0", "ai-1", "ai-2", "ai-3", "ai-4")
    private val TRACK_CHECKPOINT_COUNTS =
        TrackId.entries.associate { trackId -> trackId.value to TrackLoader().load(trackId).checkpoints.size }
    private val ROOT_PROPERTIES = setOf(SCHEMA_VERSION_FIELD, SCENARIOS_FIELD)
    private val INPUT_SCRIPT_PROPERTIES = setOf(SCHEMA_VERSION_FIELD, SEGMENTS_FIELD)
    private val INPUT_FIELDS = setOf("throttle", "brake", "steering")
    private val INPUT_SEGMENT_PROPERTIES = setOf(FROM_TICK_FIELD, TO_TICK_FIELD) + INPUT_FIELDS
    private val FLOAT_INITIAL_STATE_FIELDS =
        setOf(
            "x",
            "y",
            "rotationDeg",
            "speed",
            "velocityX",
            "velocityY",
            "angularVelocity",
            "lateralSpeed",
            "driftAmount",
        )
    private val INITIAL_STATE_PROPERTIES =
        setOf(ID_FIELD) + FLOAT_INITIAL_STATE_FIELDS +
            setOf(
                SURFACE_SPEED_MULTIPLIER_FIELD,
                CURRENT_CHECKPOINT_INDEX_FIELD,
                COMPLETED_LAPS_FIELD,
                TOTAL_RACE_TIME_FIELD,
                FINISHED_FIELD,
                FINISH_POSITION_FIELD,
            )
    private val SCENARIO_PROPERTIES =
        setOf(
            ID_FIELD,
            SEED_FIELD,
            TRACK_ID_FIELD,
            PLAYER_CAR_FIELD,
            INPUT_ORIGIN_FIELD,
            TAGS_FIELD,
            TICKS_FIELD,
            SNAPSHOT_INTERVAL_TICKS_FIELD,
            INPUT_SEGMENTS_FIELD,
            INPUT_SCRIPT_FIELD,
            INITIAL_STATES_FIELD,
            FULL_RACE_FIELD,
        )
}
