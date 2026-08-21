package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonValue
import java.util.Locale
import kotlin.math.abs

internal object BehavioralTraceJson {
    const val FLOAT_TOLERANCE = 0.0001

    fun encode(trace: BehavioralTrace): String =
        buildString {
            append('{')
            field("schemaVersion", BehavioralFixtureLoader.SCHEMA_VERSION)
            append(',')
            field("scenarioId", trace.scenarioId)
            append(',')
            field("seed", trace.seed)
            append(",\"samples\":[")
            trace.samples.forEachIndexed { index, sample ->
                if (index > 0) append(',')
                sample(sample)
            }
            append("]}")
        }

    fun encodeGoldens(traces: List<BehavioralTrace>): String =
        buildString {
            append("{\"schemaVersion\":")
            append(BehavioralFixtureLoader.SCHEMA_VERSION)
            append(",\"traces\":{")
            traces.forEachIndexed { index, trace ->
                if (index > 0) append(',')
                appendQuoted(trace.scenarioId)
                append(':')
                append(encode(trace))
            }
            append("}}")
        }

    fun firstDifference(
        expected: JsonValue,
        actual: JsonValue,
        path: String = "$",
    ): String? =
        when {
            expected.isObject || actual.isObject -> {
                if (!expected.isObject || !actual.isObject) {
                    typeDifference(expected, actual, path)
                } else {
                    objectDifference(expected, actual, path)
                }
            }

            expected.isArray || actual.isArray -> {
                if (!expected.isArray || !actual.isArray) {
                    typeDifference(expected, actual, path)
                } else {
                    arrayDifference(expected, actual, path)
                }
            }

            expected.isNumber || actual.isNumber -> {
                if (!expected.isNumber || !actual.isNumber) {
                    typeDifference(expected, actual, path)
                } else {
                    numberDifference(expected, actual, path)
                }
            }

            expected.type() != actual.type() -> {
                typeDifference(expected, actual, path)
            }

            else -> {
                if (expected.asString() != actual.asString()) {
                    "$path expected ${expected.asString()} but was ${actual.asString()}"
                } else {
                    null
                }
            }
        }

    private fun typeDifference(
        expected: JsonValue,
        actual: JsonValue,
        path: String,
    ): String = "$path expected JSON type ${expected.type()} but was ${actual.type()}"

    private fun StringBuilder.sample(sample: BehavioralTraceSample) {
        append('{')
        field("label", sample.label)
        append(',')
        field("tick", sample.tick)
        append(",\"snapshot\":")
        snapshot(sample.snapshot)
        append('}')
    }

    private fun StringBuilder.snapshot(snapshot: BehavioralSnapshot) {
        append('{')
        field("seed", snapshot.seed)
        append(',')
        field("simulationTicks", snapshot.simulationTicks)
        append(',')
        field("phase", snapshot.phase)
        append(',')
        floatField("countdownRemainingSeconds", snapshot.countdownRemainingSeconds)
        append(',')
        field("playerPosition", snapshot.playerPosition)
        append(',')
        field("requiredLaps", snapshot.requiredLaps)
        append(',')
        floatField("lastImpactSpeed", snapshot.lastImpactSpeed)
        append(",\"participants\":[")
        snapshot.participants.forEachIndexed { index, participant ->
            if (index > 0) append(',')
            participant(participant)
        }
        append("]}")
    }

    private fun StringBuilder.participant(participant: BehavioralParticipantSnapshot) {
        append('{')
        field("id", participant.id)
        append(',')
        field("car", participant.car)
        append(',')
        field("surface", participant.surface)
        append(',')
        nullableStringField("aiBehavior", participant.aiBehavior)
        append(',')
        floatField("x", participant.x)
        append(',')
        floatField("y", participant.y)
        append(',')
        floatField("rotationDeg", participant.rotationDeg)
        append(',')
        floatField("speed", participant.speed)
        append(',')
        floatField("velocityX", participant.velocityX)
        append(',')
        floatField("velocityY", participant.velocityY)
        append(',')
        floatField("angularVelocity", participant.angularVelocity)
        append(',')
        floatField("lateralSpeed", participant.lateralSpeed)
        append(',')
        floatField("driftAmount", participant.driftAmount)
        append(',')
        floatField("surfaceSpeedMultiplier", participant.surfaceSpeedMultiplier)
        append(',')
        field("currentCheckpointIndex", participant.currentCheckpointIndex)
        append(',')
        field("completedLaps", participant.completedLaps)
        append(',')
        floatField("totalRaceTime", participant.totalRaceTime)
        append(',')
        nullableFloatField("bestLapTime", participant.bestLapTime)
        append(',')
        field("finished", participant.finished)
        append(',')
        nullableIntField("finishPosition", participant.finishPosition)
        append('}')
    }

    private fun objectDifference(
        expected: JsonValue,
        actual: JsonValue,
        path: String,
    ): String? {
        if (expected.size != actual.size) return "$path object field count differs"
        return expected.children().firstNotNullOfOrNull { expectedChild ->
            val name = checkNotNull(expectedChild.name)
            val actualChild = actual.get(name) ?: return@firstNotNullOfOrNull "$path.$name is missing"
            firstDifference(expectedChild, actualChild, "$path.$name")
        }
    }

    private fun arrayDifference(
        expected: JsonValue,
        actual: JsonValue,
        path: String,
    ): String? {
        if (expected.size != actual.size) return "$path array size differs: ${expected.size} vs ${actual.size}"
        return expected
            .children()
            .zip(actual.children())
            .mapIndexedNotNull { index, pair ->
                firstDifference(pair.first, pair.second, "$path[$index]")
            }.firstOrNull()
    }

    private fun numberDifference(
        expected: JsonValue,
        actual: JsonValue,
        path: String,
    ): String? =
        if (FLOAT_FIELDS.contains(path.substringAfterLast('.'))) {
            floatingPointDifference(expected, actual, path)
        } else {
            integerDifference(expected, actual, path)
        }

    private fun floatingPointDifference(
        expected: JsonValue,
        actual: JsonValue,
        path: String,
    ): String? {
        val expectedValue = expected.asDouble()
        val actualValue = actual.asDouble()
        return if (abs(expectedValue - actualValue) > FLOAT_TOLERANCE) {
            "$path expected $expectedValue but was $actualValue"
        } else {
            null
        }
    }

    private fun integerDifference(
        expected: JsonValue,
        actual: JsonValue,
        path: String,
    ): String? {
        if (!expected.isLong || !actual.isLong) return "$path must contain integer JSON numbers"
        val expectedValue = expected.asLong()
        val actualValue = actual.asLong()
        return if (expectedValue != actualValue) {
            "$path expected $expectedValue but was $actualValue"
        } else {
            null
        }
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

    private fun StringBuilder.field(
        name: String,
        value: Boolean,
    ) {
        appendQuoted(name)
        append(':')
        append(value)
    }

    private fun StringBuilder.floatField(
        name: String,
        value: Float,
    ) {
        appendQuoted(name)
        append(':')
        appendFloat(value)
    }

    private fun StringBuilder.nullableStringField(
        name: String,
        value: String?,
    ) {
        appendQuoted(name)
        append(':')
        if (value == null) append("null") else appendQuoted(value)
    }

    private fun StringBuilder.nullableFloatField(
        name: String,
        value: Float?,
    ) {
        appendQuoted(name)
        append(':')
        if (value == null) append("null") else appendFloat(value)
    }

    private fun StringBuilder.nullableIntField(
        name: String,
        value: Int?,
    ) {
        appendQuoted(name)
        append(':')
        if (value == null) append("null") else append(value)
    }

    private fun StringBuilder.appendFloat(value: Float) {
        append(String.format(Locale.ROOT, "%.6f", value))
    }

    private fun StringBuilder.appendQuoted(value: String) {
        append('"')
        append(value.replace("\\", "\\\\").replace("\"", "\\\""))
        append('"')
    }

    private fun JsonValue.children(): List<JsonValue> = generateSequence(child) { it.next }.toList()

    private val FLOAT_FIELDS =
        setOf(
            "countdownRemainingSeconds",
            "lastImpactSpeed",
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
            "totalRaceTime",
            "bestLapTime",
        )
}
