package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonValue

/** Backwards-compatible entry point for the reusable normalized snapshot comparison engine. */
internal object BehavioralTraceComparator {
    fun compare(
        expected: JsonValue,
        actual: JsonValue,
        path: String = "$",
    ): SnapshotComparison = SnapshotComparisonEngine.compare(expected, actual, path)

    fun firstDifference(
        expected: JsonValue,
        actual: JsonValue,
        path: String,
    ): String? = compare(expected, actual, path).firstMismatch?.compactDescription()
}
