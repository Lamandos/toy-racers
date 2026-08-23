package com.example.toyracers.compat

import java.util.Locale

internal data class ComparisonContext(
    val tick: Long? = null,
    val participant: String? = null,
    val sampleIndex: Int? = null,
    val sampleLabel: String? = null,
)

/** One observed contract violation, ordered by trace/sample/field position. */
internal data class SnapshotMismatch(
    val tick: Long?,
    val participant: String?,
    val sampleIndex: Int?,
    val sampleLabel: String?,
    val field: String,
    val expected: String,
    val actual: String,
    val delta: String,
) {
    fun compactDescription(): String = "$field expected $expected but was $actual ($delta)"

    fun location(): String {
        val tickLocation = tick?.let { "tick $it" } ?: "before first sample"
        return sampleLabel?.let { "$tickLocation ($it)" } ?: tickLocation
    }

    fun tableRow(): String =
        String.format(
            Locale.ROOT,
            "%-18s %-14s %-14s %s",
            field,
            expected,
            actual,
            delta,
        )

    fun conciseDescription(): String = "${location()}, participant ${participant ?: "race"}: ${compactDescription()}"
}
