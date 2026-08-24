package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonReader
import com.badlogic.gdx.utils.JsonValue
import java.nio.file.Files
import java.nio.file.Path
import kotlin.io.path.name

/** Reads and validates schema-versioned scenario documents for the headless runner. */
internal object BehavioralScenarioLoader {
    const val SCHEMA_VERSION = 1

    fun load(path: Path): BehavioralScenario {
        val scenarioPath = path.toAbsolutePath().normalize()
        require(Files.isRegularFile(scenarioPath)) { "Scenario file does not exist: $path" }
        val directory = scenarioPath.parent
        val scenarios =
            parseScenarioDocument(readJson(scenarioPath)) { script ->
                val scriptPath = directory.resolve(script).normalize()
                require(scriptPath.parent == directory) {
                    "Scenario input script must be next to ${scenarioPath.name}: $script"
                }
                require(Files.isRegularFile(scriptPath)) { "Input script does not exist: $scriptPath" }
                readJson(scriptPath)
            }
        require(scenarios.size == 1) {
            "Scenario file must contain exactly one scenario, but ${path.name} contains ${scenarios.size}"
        }
        return scenarios.single()
    }

    internal fun parseScenarioDocument(
        root: JsonValue,
        inputScriptReader: (String) -> JsonValue,
    ): List<BehavioralScenario> {
        BehavioralScenarioValidator.validateDocument(root)
        return root.get("scenarios").children().map { scenario(it, inputScriptReader) }
    }

    private fun scenario(
        value: JsonValue,
        inputScriptReader: (String) -> JsonValue,
    ): BehavioralScenario =
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
            inputSegments = inputSegments(value, inputScriptReader),
            inputTweaks =
                value
                    .get("inputTweaks")
                    ?.children()
                    ?.map(::inputTweak)
                    .orEmpty(),
            initialStates =
                value
                    .get("initialStates")
                    ?.children()
                    ?.map(::initialState)
                    .orEmpty(),
            fullRace = value.getBoolean("fullRace", false),
        ).also(BehavioralScenarioValidator::validate)

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

    private fun inputTweak(value: JsonValue): BehavioralInputTweak =
        BehavioralInputTweak(
            tick = value.getInt("tick"),
            throttleDelta = value.getFloat("throttleDelta", 0f),
            brakeDelta = value.getFloat("brakeDelta", 0f),
            steeringDelta = value.getFloat("steeringDelta", 0f),
        )

    private fun inputSegments(
        value: JsonValue,
        inputScriptReader: (String) -> JsonValue,
    ): List<BehavioralInputSegment> =
        value.get("inputSegments")?.children()?.map(::inputSegment)
            ?: scriptedInputSegments(value, inputScriptReader)

    private fun scriptedInputSegments(
        value: JsonValue,
        inputScriptReader: (String) -> JsonValue,
    ): List<BehavioralInputSegment> {
        val script =
            requireNotNull(value.get("inputScript")) {
                "Scenario ${value.getString("id")} needs inputSegments or inputScript"
            }.asString()
        val root = inputScriptReader(script)
        BehavioralScenarioValidator.validateInputScript(root, "compat/$script")
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

    private fun readJson(path: Path): JsonValue = Files.newBufferedReader(path).use(JsonReader()::parse)

    private fun JsonValue.floatOrNull(name: String): Float? = get(name)?.asFloat()

    private fun JsonValue.intOrNull(name: String): Int? = get(name)?.asInt()

    private fun JsonValue.booleanOrNull(name: String): Boolean? = get(name)?.asBoolean()

    private fun JsonValue.children(): List<JsonValue> = generateSequence(child) { it.next }.toList()
}
