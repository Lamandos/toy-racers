package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonValue
import kotlin.math.abs

/** Compares normalized traces while allowing only the documented floating-point tolerance. */
internal object BehavioralTraceComparator {
    fun firstDifference(
        expected: JsonValue,
        actual: JsonValue,
        path: String,
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

            expected.asString() != actual.asString() -> {
                "$path expected ${expected.asString()} but was ${actual.asString()}"
            }

            else -> {
                null
            }
        }

    private fun typeDifference(
        expected: JsonValue,
        actual: JsonValue,
        path: String,
    ): String = "$path expected JSON type ${expected.type()} but was ${actual.type()}"

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
        if (path.substringAfterLast('.') in FLOAT_FIELDS) {
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
        return if (abs(expectedValue - actualValue) > BehavioralTraceJson.FLOAT_TOLERANCE) {
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
        return if (expectedValue != actualValue) "$path expected $expectedValue but was $actualValue" else null
    }

    private fun JsonValue.children(): List<JsonValue> = generateSequence(child) { it.next }.toList()

    private val FLOAT_FIELDS =
        setOf(
            "remainingSeconds",
            "elapsedSimulationTime",
            "x",
            "y",
            "rotation",
            "velocityX",
            "velocityY",
            "angularVelocity",
            "longitudinalSpeed",
            "lateralSpeed",
            "driftAmount",
            "bestLapTime",
        )
}
