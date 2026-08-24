package com.example.toyracers.compat

import java.util.Locale

/** Serializes generated fuzz scenarios as self-contained behavioral scenario documents. */
internal object DifferentialFuzzScenarioJson {
    fun encode(scenario: BehavioralScenario): String {
        require(DIFFERENTIAL_FUZZ_TAG in scenario.tags) { "Scenario is not a differential fuzz scenario" }
        require(scenario.inputTweaks.isEmpty()) { "Differential fuzz inputs must be materialized in segments" }
        require(scenario.initialStates.isEmpty()) { "Differential fuzz scenarios use the default initial state" }
        require(!scenario.fullRace) { "Differential fuzz scenarios must not enable full race mode" }

        return buildString {
            append('{')
            field("schemaVersion", BehavioralScenarioLoader.SCHEMA_VERSION)
            append(",\"scenarios\":[{")
            field("id", scenario.id)
            append(',')
            field("seed", scenario.seed)
            append(',')
            field("trackId", scenario.trackId)
            append(',')
            field("playerCar", scenario.playerCar)
            append(',')
            field("inputOrigin", scenario.inputOrigin)
            append(",\"tags\":[")
            scenario.tags.sorted().forEachIndexed { index, tag ->
                if (index > 0) append(',')
                appendQuoted(tag)
            }
            append("]")
            append(',')
            field("ticks", scenario.ticks)
            append(',')
            field("snapshotIntervalTicks", scenario.snapshotIntervalTicks)
            append(",\"inputSegments\":[")
            scenario.inputSegments.forEachIndexed { index, segment ->
                if (index > 0) append(',')
                inputSegment(segment)
            }
            append("]}]}")
        }
    }

    private fun StringBuilder.inputSegment(segment: BehavioralInputSegment) {
        require(segment.input.throttle in NORMALIZED_CONTROL_RANGE) { "Generated throttle is out of range" }
        require(segment.input.brake in NORMALIZED_CONTROL_RANGE) { "Generated brake is out of range" }
        require(segment.input.steering in NORMALIZED_STEERING_RANGE) { "Generated steering is out of range" }
        append('{')
        field("fromTick", segment.fromTick)
        append(',')
        field("toTick", segment.toTick)
        append(",\"throttle\":")
        appendControl(segment.input.throttle)
        append(",\"brake\":")
        appendControl(segment.input.brake)
        append(",\"steering\":")
        appendControl(segment.input.steering)
        append('}')
    }

    private fun StringBuilder.field(
        name: String,
        value: String,
    ) {
        appendQuoted(name)
        append(':')
        appendQuoted(value)
    }

    private fun StringBuilder.field(
        name: String,
        value: Int,
    ) {
        appendQuoted(name)
        append(':')
        append(value)
    }

    private fun StringBuilder.field(
        name: String,
        value: Long,
    ) {
        appendQuoted(name)
        append(':')
        append(value)
    }

    private fun StringBuilder.appendControl(value: Float) {
        require(value.isFinite()) { "Generated controls must be finite" }
        append(String.format(Locale.ROOT, "%.6f", value))
    }

    private fun StringBuilder.appendQuoted(value: String) {
        append('"')
        append(value.replace("\\", "\\\\").replace("\"", "\\\""))
        append('"')
    }

    private const val DIFFERENTIAL_FUZZ_TAG = "differential-fuzz"
    private val NORMALIZED_CONTROL_RANGE = 0f..1f
    private val NORMALIZED_STEERING_RANGE = -1f..1f
}
