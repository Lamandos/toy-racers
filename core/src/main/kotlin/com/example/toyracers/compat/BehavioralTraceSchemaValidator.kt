package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonValue

/** Validates complete trace documents before the structural comparison begins. */
internal object BehavioralTraceSchemaValidator {
    fun validateIfTrace(value: JsonValue): List<TraceSchemaViolation> {
        if (!value.isObject || !looksLikeTraceEnvelope(value)) return emptyList()
        val violations = mutableListOf<TraceSchemaViolation>()
        validateTrace(value, ROOT_PATH, violations)
        return violations
    }

    private fun looksLikeTraceEnvelope(value: JsonValue): Boolean =
        value.has(SCHEMA_VERSION_FIELD) || value.has(SCENARIO_ID_FIELD) || value.has(SEED_FIELD)

    private fun validateTrace(
        value: JsonValue,
        path: String,
        violations: MutableList<TraceSchemaViolation>,
    ) {
        if (!validateObject(value, path, TRACE_PROPERTIES, TRACE_REQUIRED, violations)) return
        requireInteger(value.get(SCHEMA_VERSION_FIELD), "$path.schemaVersion", violations, expected = TRACE_VERSION)
        requireString(value.get(SCENARIO_ID_FIELD), "$path.scenarioId", violations, nonEmpty = true)
        requireInteger(value.get(SEED_FIELD), "$path.seed", violations)
        value.get(SAMPLES_FIELD)?.let { samples ->
            validateArray(samples, "$path.samples", violations, minItems = 1) { sample, samplePath ->
                validateSample(sample, samplePath, violations)
            }
        }
    }

    private fun validateSample(
        value: JsonValue,
        path: String,
        violations: MutableList<TraceSchemaViolation>,
    ) {
        if (!validateObject(value, path, SAMPLE_PROPERTIES, SAMPLE_REQUIRED, violations)) return
        requireString(value.get(LABEL_FIELD), "$path.label", violations, allowed = SAMPLE_LABELS)
        requireInteger(value.get(TICK_FIELD), "$path.tick", violations, minimum = 0)
        value.get(SNAPSHOT_FIELD)?.let { snapshot ->
            validateSnapshot(snapshot, "$path.snapshot", violations)
        }
    }

    private fun validateSnapshot(
        value: JsonValue,
        path: String,
        violations: MutableList<TraceSchemaViolation>,
    ) {
        if (!validateObject(value, path, SNAPSHOT_PROPERTIES, SNAPSHOT_REQUIRED, violations)) return
        requireInteger(value.get(SCHEMA_VERSION_FIELD), "$path.schemaVersion", violations, expected = SNAPSHOT_VERSION)
        requireInteger(value.get(SIMULATION_TICK_FIELD), "$path.simulationTick", violations, minimum = 0)
        requireString(value.get(RACE_STATE_FIELD), "$path.raceState", violations, allowed = RACE_STATES)
        value.get(COUNTDOWN_FIELD)?.let { countdown ->
            validateCountdown(countdown, "$path.countdown", violations)
        }
        requireNumber(value.get(ELAPSED_TIME_FIELD), "$path.elapsedSimulationTime", violations, minimum = 0.0)
        requireInteger(value.get(CURRENT_LAP_FIELD), "$path.currentLap", violations, minimum = 1)
        value.get(CURRENT_PROGRESS_FIELD)?.let { progress ->
            validateProgress(progress, "$path.currentProgress", violations)
        }
        value.get(PARTICIPANTS_FIELD)?.let { participants ->
            validateArray(
                participants,
                "$path.participants",
                violations,
                minItems = 1,
            ) { participant, participantPath ->
                validateParticipant(participant, participantPath, violations)
            }
        }
        value.get(RANKING_FIELD)?.let { ranking ->
            validateStringArray(ranking, "$path.ranking", violations, minItems = 1)
        }
        value.get(FINISHED_PARTICIPANTS_FIELD)?.let { finished ->
            validateStringArray(finished, "$path.finishedParticipants", violations)
        }
        value.get(FINISH_RESULTS_FIELD)?.let { results ->
            validateArray(results, "$path.finishResults", violations) { result, resultPath ->
                validateFinishResult(result, resultPath, violations)
            }
        }
    }

    private fun validateCountdown(
        value: JsonValue,
        path: String,
        violations: MutableList<TraceSchemaViolation>,
    ) {
        if (!validateObject(value, path, COUNTDOWN_PROPERTIES, COUNTDOWN_REQUIRED, violations)) return
        requireString(value.get(STATE_FIELD), "$path.state", violations, allowed = COUNTDOWN_STATES)
        requireNumber(value.get(REMAINING_SECONDS_FIELD), "$path.remainingSeconds", violations, minimum = 0.0)
    }

    private fun validateProgress(
        value: JsonValue,
        path: String,
        violations: MutableList<TraceSchemaViolation>,
    ) {
        if (!validateObject(value, path, PROGRESS_PROPERTIES, PROGRESS_REQUIRED, violations)) return
        requireInteger(value.get(CHECKPOINT_FIELD), "$path.checkpoint", violations, minimum = 0)
        requireInteger(value.get(COMPLETED_LAPS_FIELD), "$path.completedLaps", violations, minimum = 0)
    }

    private fun validateParticipant(
        value: JsonValue,
        path: String,
        violations: MutableList<TraceSchemaViolation>,
    ) {
        if (!validateObject(value, path, PARTICIPANT_PROPERTIES, PARTICIPANT_REQUIRED, violations)) return
        requireString(value.get(ID_FIELD), "$path.id", violations, nonEmpty = true)
        requireNumber(value.get(X_FIELD), "$path.x", violations)
        requireNumber(value.get(Y_FIELD), "$path.y", violations)
        requireNumber(value.get(VELOCITY_X_FIELD), "$path.velocityX", violations)
        requireNumber(value.get(VELOCITY_Y_FIELD), "$path.velocityY", violations)
        requireNumber(value.get(ROTATION_FIELD), "$path.rotation", violations, minimum = 0.0, exclusiveMaximum = 360.0)
        requireNumber(value.get(ANGULAR_VELOCITY_FIELD), "$path.angularVelocity", violations)
        requireNumber(value.get(LONGITUDINAL_SPEED_FIELD), "$path.longitudinalSpeed", violations)
        requireNumber(value.get(LATERAL_SPEED_FIELD), "$path.lateralSpeed", violations)
        requireNumber(value.get(DRIFT_AMOUNT_FIELD), "$path.driftAmount", violations, minimum = 0.0, maximum = 1.0)
        requireString(value.get(SURFACE_FIELD), "$path.surface", violations, allowed = SURFACES)
        requireInteger(value.get(CHECKPOINT_FIELD), "$path.checkpoint", violations, minimum = 0)
        requireInteger(value.get(LAP_FIELD), "$path.lap", violations, minimum = 0)
        requireInteger(value.get(RACE_POSITION_FIELD), "$path.racePosition", violations, minimum = 1)
        requireBoolean(value.get(FINISHED_FIELD), "$path.finished", violations)
    }

    private fun validateFinishResult(
        value: JsonValue,
        path: String,
        violations: MutableList<TraceSchemaViolation>,
    ) {
        if (!validateObject(value, path, FINISH_RESULT_PROPERTIES, FINISH_RESULT_REQUIRED, violations)) return
        requireString(value.get(PARTICIPANT_ID_FIELD), "$path.participantId", violations, nonEmpty = true)
        requireInteger(value.get(FINISH_POSITION_FIELD), "$path.finishPosition", violations, minimum = 1)
        requireNumber(value.get(ELAPSED_TIME_FIELD), "$path.elapsedSimulationTime", violations, minimum = 0.0)
        value.get(BEST_LAP_TIME_FIELD)?.let { bestLapTime ->
            if (!bestLapTime.isNull) {
                requireNumber(bestLapTime, "$path.bestLapTime", violations, minimum = 0.0)
            }
        }
    }

    private fun validateStringArray(
        value: JsonValue,
        path: String,
        violations: MutableList<TraceSchemaViolation>,
        minItems: Int = 0,
    ) {
        validateArray(value, path, violations, minItems) { item, itemPath ->
            requireString(item, itemPath, violations, nonEmpty = true)
        }
    }

    private fun validateArray(
        value: JsonValue,
        path: String,
        violations: MutableList<TraceSchemaViolation>,
        minItems: Int = 0,
        validateItem: (JsonValue, String) -> Unit,
    ) {
        if (!value.isArray) {
            violations += TraceSchemaViolation(path, "must be an array")
            return
        }
        if (value.size < minItems) {
            violations += TraceSchemaViolation(path, "must contain at least $minItems item(s)")
        }
        value.children().forEachIndexed { index, item ->
            validateItem(item, "$path[$index]")
        }
    }

    private fun validateObject(
        value: JsonValue,
        path: String,
        allowedProperties: Set<String>,
        requiredProperties: Set<String>,
        violations: MutableList<TraceSchemaViolation>,
    ): Boolean {
        if (!value.isObject) {
            violations += TraceSchemaViolation(path, "must be an object")
            return false
        }
        val names = mutableSetOf<String>()
        value.children().forEach { property ->
            val name = property.name
            if (name == null) {
                violations += TraceSchemaViolation(path, "contains an unnamed property")
            } else if (!allowedProperties.contains(name)) {
                violations += TraceSchemaViolation("$path.$name", "unexpected property")
            } else if (!names.add(name)) {
                violations += TraceSchemaViolation("$path.$name", "duplicate property")
            }
        }
        requiredProperties.filter { !value.has(it) }.forEach { name ->
            violations += TraceSchemaViolation("$path.$name", "required property is missing")
        }
        return true
    }

    private fun requireString(
        value: JsonValue?,
        path: String,
        violations: MutableList<TraceSchemaViolation>,
        nonEmpty: Boolean = false,
        allowed: Set<String> = emptySet(),
    ) {
        if (value == null || !value.isString) {
            violations += TraceSchemaViolation(path, "must be a string")
            return
        }
        if (nonEmpty && value.asString().isEmpty()) {
            violations += TraceSchemaViolation(path, "must not be empty")
        }
        if (allowed.isNotEmpty() && value.asString() !in allowed) {
            violations += TraceSchemaViolation(path, "has an unsupported value")
        }
    }

    private fun requireBoolean(
        value: JsonValue?,
        path: String,
        violations: MutableList<TraceSchemaViolation>,
    ) {
        if (value == null || !value.isBoolean) {
            violations += TraceSchemaViolation(path, "must be a boolean")
        }
    }

    private fun requireInteger(
        value: JsonValue?,
        path: String,
        violations: MutableList<TraceSchemaViolation>,
        minimum: Long? = null,
        expected: Int? = null,
    ) {
        if (value == null || !value.isLong) {
            violations += TraceSchemaViolation(path, "must be a JSON integer")
            return
        }
        val number = value.asLong()
        minimum?.takeIf { number < it }?.let {
            violations += TraceSchemaViolation(path, "must be at least $it")
        }
        expected?.takeIf { number != it.toLong() }?.let {
            violations += TraceSchemaViolation(path, "must equal $it")
        }
    }

    private fun requireNumber(
        value: JsonValue?,
        path: String,
        violations: MutableList<TraceSchemaViolation>,
        minimum: Double? = null,
        maximum: Double? = null,
        exclusiveMaximum: Double? = null,
    ) {
        if (value == null || !value.isNumber) {
            violations += TraceSchemaViolation(path, "must be a JSON number")
            return
        }
        val number = value.asDouble()
        when {
            !number.isFinite() -> {
                violations += TraceSchemaViolation(path, "must be finite")
            }

            java.lang.Double.doubleToRawLongBits(number) ==
                java.lang.Double.doubleToRawLongBits(-0.0) -> {
                violations += TraceSchemaViolation(path, "must not be negative zero")
            }

            minimum != null && number < minimum -> {
                violations += TraceSchemaViolation(path, "must be at least $minimum")
            }

            maximum != null && number > maximum -> {
                violations += TraceSchemaViolation(path, "must be at most $maximum")
            }

            exclusiveMaximum != null && number >= exclusiveMaximum -> {
                violations += TraceSchemaViolation(path, "must be less than $exclusiveMaximum")
            }
        }
    }

    private fun JsonValue.children(): List<JsonValue> = generateSequence(child) { it.next }.toList()

    private const val ROOT_PATH = "$"
    private const val TRACE_VERSION = 3
    private const val SNAPSHOT_VERSION = 2
    private const val SCHEMA_VERSION_FIELD = "schemaVersion"
    private const val SCENARIO_ID_FIELD = "scenarioId"
    private const val SEED_FIELD = "seed"
    private const val SAMPLES_FIELD = "samples"
    private const val LABEL_FIELD = "label"
    private const val TICK_FIELD = "tick"
    private const val SNAPSHOT_FIELD = "snapshot"
    private const val SIMULATION_TICK_FIELD = "simulationTick"
    private const val RACE_STATE_FIELD = "raceState"
    private const val COUNTDOWN_FIELD = "countdown"
    private const val ELAPSED_TIME_FIELD = "elapsedSimulationTime"
    private const val CURRENT_LAP_FIELD = "currentLap"
    private const val CURRENT_PROGRESS_FIELD = "currentProgress"
    private const val PARTICIPANTS_FIELD = "participants"
    private const val RANKING_FIELD = "ranking"
    private const val FINISHED_PARTICIPANTS_FIELD = "finishedParticipants"
    private const val FINISH_RESULTS_FIELD = "finishResults"
    private const val STATE_FIELD = "state"
    private const val REMAINING_SECONDS_FIELD = "remainingSeconds"
    private const val CHECKPOINT_FIELD = "checkpoint"
    private const val COMPLETED_LAPS_FIELD = "completedLaps"
    private const val ID_FIELD = "id"
    private const val X_FIELD = "x"
    private const val Y_FIELD = "y"
    private const val ROTATION_FIELD = "rotation"
    private const val VELOCITY_X_FIELD = "velocityX"
    private const val VELOCITY_Y_FIELD = "velocityY"
    private const val ANGULAR_VELOCITY_FIELD = "angularVelocity"
    private const val LONGITUDINAL_SPEED_FIELD = "longitudinalSpeed"
    private const val LATERAL_SPEED_FIELD = "lateralSpeed"
    private const val DRIFT_AMOUNT_FIELD = "driftAmount"
    private const val SURFACE_FIELD = "surface"
    private const val LAP_FIELD = "lap"
    private const val RACE_POSITION_FIELD = "racePosition"
    private const val FINISHED_FIELD = "finished"
    private const val PARTICIPANT_ID_FIELD = "participantId"
    private const val FINISH_POSITION_FIELD = "finishPosition"
    private const val BEST_LAP_TIME_FIELD = "bestLapTime"
    private val TRACE_PROPERTIES = setOf(SCHEMA_VERSION_FIELD, SCENARIO_ID_FIELD, SEED_FIELD, SAMPLES_FIELD)
    private val TRACE_REQUIRED = TRACE_PROPERTIES
    private val SAMPLE_PROPERTIES = setOf(LABEL_FIELD, TICK_FIELD, SNAPSHOT_FIELD)
    private val SAMPLE_REQUIRED = SAMPLE_PROPERTIES
    private val SNAPSHOT_PROPERTIES =
        setOf(
            SCHEMA_VERSION_FIELD,
            SIMULATION_TICK_FIELD,
            RACE_STATE_FIELD,
            COUNTDOWN_FIELD,
            ELAPSED_TIME_FIELD,
            CURRENT_LAP_FIELD,
            CURRENT_PROGRESS_FIELD,
            PARTICIPANTS_FIELD,
            RANKING_FIELD,
            FINISHED_PARTICIPANTS_FIELD,
            FINISH_RESULTS_FIELD,
        )
    private val SNAPSHOT_REQUIRED = SNAPSHOT_PROPERTIES
    private val COUNTDOWN_PROPERTIES = setOf(STATE_FIELD, REMAINING_SECONDS_FIELD)
    private val COUNTDOWN_REQUIRED = COUNTDOWN_PROPERTIES
    private val PROGRESS_PROPERTIES = setOf(CHECKPOINT_FIELD, COMPLETED_LAPS_FIELD)
    private val PROGRESS_REQUIRED = PROGRESS_PROPERTIES
    private val PARTICIPANT_PROPERTIES =
        setOf(
            ID_FIELD,
            SURFACE_FIELD,
            X_FIELD,
            Y_FIELD,
            ROTATION_FIELD,
            VELOCITY_X_FIELD,
            VELOCITY_Y_FIELD,
            ANGULAR_VELOCITY_FIELD,
            LONGITUDINAL_SPEED_FIELD,
            LATERAL_SPEED_FIELD,
            DRIFT_AMOUNT_FIELD,
            CHECKPOINT_FIELD,
            LAP_FIELD,
            RACE_POSITION_FIELD,
            FINISHED_FIELD,
        )
    private val PARTICIPANT_REQUIRED = PARTICIPANT_PROPERTIES
    private val FINISH_RESULT_PROPERTIES =
        setOf(PARTICIPANT_ID_FIELD, FINISH_POSITION_FIELD, ELAPSED_TIME_FIELD, BEST_LAP_TIME_FIELD)
    private val FINISH_RESULT_REQUIRED = FINISH_RESULT_PROPERTIES
    private val SAMPLE_LABELS =
        setOf("loading", "ready", "countdown", "racing", "simulation", "checkpoint", "lap", "finish")
    private val RACE_STATES = setOf("loading", "ready", "countdown", "racing", "paused", "finished")
    private val COUNTDOWN_STATES = setOf("not-started", "active", "complete")
    private val SURFACES = setOf("asphalt", "parquet", "tile", "grass", "boost", "oil")
}

internal data class TraceSchemaViolation(
    val path: String,
    val message: String,
)
