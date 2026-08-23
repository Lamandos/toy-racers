package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonValue
import java.util.Locale
import kotlin.math.abs
import kotlin.math.max

/**
 * Compares normalized behavioral traces from the Kotlin reference or another runtime.
 *
 * Discrete contract values must match exactly. Simulation values use the per-field tolerances in
 * [ApproximateSnapshotField]; no relative tolerance is currently enabled.
 */
internal object SnapshotComparisonEngine {
    const val ABSOLUTE_TOLERANCE = 0.0001
    private const val ROOT_PATH = "$"

    fun compare(
        expected: JsonValue,
        actual: JsonValue,
        rootPath: String = ROOT_PATH,
    ): SnapshotComparison {
        val collector = MismatchCollector()
        compareValue(expected, actual, rootPath, ComparisonContext(), collector)
        return collector.result()
    }

    private fun compareValue(
        expected: JsonValue,
        actual: JsonValue,
        path: String,
        context: ComparisonContext,
        collector: MismatchCollector,
    ) {
        when {
            expected.isObject || actual.isObject -> {
                compareObject(expected, actual, path, context, collector)
            }

            expected.isArray || actual.isArray -> {
                compareArray(expected, actual, path, context, collector)
            }

            expected.isNumber || actual.isNumber -> {
                compareNumber(expected, actual, path, context, collector)
            }

            expected.type() != actual.type() -> {
                collector.typeMismatch(context, path, expected, actual)
            }

            expected.displayValue() != actual.displayValue() -> {
                collector.exactMismatch(context, path, expected, actual)
            }
        }
    }

    private fun compareObject(
        expected: JsonValue,
        actual: JsonValue,
        path: String,
        context: ComparisonContext,
        collector: MismatchCollector,
    ) {
        if (!expected.isObject || !actual.isObject) {
            collector.typeMismatch(context, path, expected, actual)
            return
        }
        val objectContext = context.withIdentifiers(expected)
        val expectedChildren = expected.children()
        val actualChildren = actual.children()
        reportDuplicateObjectFields(expectedChildren, objectContext, path, "expected", collector)
        reportDuplicateObjectFields(actualChildren, objectContext, path, "actual", collector)
        expectedChildren.forEach { expectedChild ->
            val name = checkNotNull(expectedChild.name)
            val actualChild = actual.get(name)
            if (actualChild == null) {
                collector.missingField(objectContext, "$path.$name", expectedChild)
            } else {
                compareValue(expectedChild, actualChild, "$path.$name", objectContext, collector)
            }
        }
        actualChildren.filter { actualChild -> expected.get(actualChild.name) == null }.forEach { actualChild ->
            collector.unexpectedField(objectContext, "$path.${actualChild.name}", actualChild)
        }
    }

    private fun compareArray(
        expected: JsonValue,
        actual: JsonValue,
        path: String,
        context: ComparisonContext,
        collector: MismatchCollector,
    ) {
        if (!expected.isArray || !actual.isArray) {
            collector.typeMismatch(context, path, expected, actual)
            return
        }
        val values = expected.children().zip(actual.children())
        if (path.isSampleArray()) {
            values.forEachIndexed { index, pair ->
                compareValue(pair.first, pair.second, "$path[$index]", context, collector)
            }
            if (expected.size != actual.size) {
                collector.arraySizeMismatch(
                    context.withSampleTick(expected, actual),
                    path,
                    expected.size,
                    actual.size,
                )
            }
        } else {
            if (expected.size != actual.size) {
                val mismatchContext = context.withUnmatchedParticipant(expected, actual, path)
                collector.arraySizeMismatch(mismatchContext, path, expected.size, actual.size)
            }
            values.forEachIndexed { index, pair ->
                compareValue(pair.first, pair.second, "$path[$index]", context, collector)
            }
        }
    }

    private fun compareNumber(
        expected: JsonValue,
        actual: JsonValue,
        path: String,
        context: ComparisonContext,
        collector: MismatchCollector,
    ) {
        if (!expected.isNumber || !actual.isNumber) {
            collector.typeMismatch(context, path, expected, actual)
            return
        }
        if (!expected.asDouble().isFinite() || !actual.asDouble().isFinite()) {
            collector.nonFiniteNumber(context, path, expected.asDouble(), actual.asDouble())
            return
        }
        val field = ApproximateSnapshotField.forPath(path)
        if (field == null) {
            compareExactInteger(expected, actual, path, context, collector)
        } else {
            compareApproximateNumber(expected, actual, path, context, collector, field)
        }
    }

    private fun compareExactInteger(
        expected: JsonValue,
        actual: JsonValue,
        path: String,
        context: ComparisonContext,
        collector: MismatchCollector,
    ) {
        if (!expected.isLong || !actual.isLong) {
            collector.integerTypeMismatch(context, path, expected, actual)
        } else if (expected.asLong() != actual.asLong()) {
            collector.exactMismatch(context, path, expected, actual)
        }
    }

    private fun compareApproximateNumber(
        expected: JsonValue,
        actual: JsonValue,
        path: String,
        context: ComparisonContext,
        collector: MismatchCollector,
        field: ApproximateSnapshotField,
    ) {
        val expectedValue = expected.asDouble()
        val actualValue = actual.asDouble()
        if (!expectedValue.isFinite() || !actualValue.isFinite()) {
            collector.nonFiniteNumber(context, path, expectedValue, actualValue)
            return
        }
        if (field.isAngle && (!expectedValue.isNormalizedRotation() || !actualValue.isNormalizedRotation())) {
            collector.invalidRotation(context, path, expected, actual)
            return
        }
        val delta = field.delta(expectedValue, actualValue)
        if (abs(delta) > field.allowedTolerance(expectedValue, actualValue)) {
            collector.approximateMismatch(context, path, expected, actual, delta, field.isAngle)
        }
    }

    private fun ComparisonContext.withIdentifiers(value: JsonValue): ComparisonContext =
        copy(
            tick = value.get("tick").integerValueOrNull() ?: tick,
            participant =
                value.get("id").stringValueOrNull()
                    ?: value.get("participantId").stringValueOrNull() ?: participant,
        )

    private fun JsonValue?.integerValueOrNull(): Long? = takeIf { it?.isLong == true }?.asLong()

    private fun JsonValue?.stringValueOrNull(): String? = takeIf { it?.isString == true }?.asString()

    private fun ComparisonContext.withSampleTick(
        expected: JsonValue,
        actual: JsonValue,
    ): ComparisonContext {
        val unmatchedSample = expected.get(actual.size) ?: actual.get(expected.size)
        return copy(tick = unmatchedSample?.get("tick").integerValueOrNull() ?: tick)
    }

    private fun ComparisonContext.withUnmatchedParticipant(
        expected: JsonValue,
        actual: JsonValue,
        path: String,
    ): ComparisonContext {
        if (!path.endsWith(".participants")) return this
        val unmatchedParticipant = expected.get(actual.size) ?: actual.get(expected.size)
        return unmatchedParticipant?.let { withIdentifiers(it) } ?: this
    }

    private fun reportDuplicateObjectFields(
        children: List<JsonValue>,
        context: ComparisonContext,
        path: String,
        source: String,
        collector: MismatchCollector,
    ) {
        val names = mutableSetOf<String>()
        children.forEach { child ->
            val name = checkNotNull(child.name)
            if (!names.add(name)) collector.duplicateObjectField(context, "$path.$name", source)
        }
    }

    private fun String.isSampleArray(): Boolean = endsWith(".samples")

    private fun JsonValue.children(): List<JsonValue> = generateSequence(child) { it.next }.toList()
}

private data class ComparisonContext(
    val tick: Long? = null,
    val participant: String? = null,
)

/** The result is reusable by golden tests and future external-runtime trace-file checks. */
internal data class SnapshotComparison(
    val mismatches: List<SnapshotMismatch>,
    val hasOmittedMismatches: Boolean,
) {
    val firstMismatch: SnapshotMismatch?
        get() = mismatches.firstOrNull()

    fun failureReport(scenarioId: String): String? {
        val first = firstMismatch ?: return null
        return buildString {
            appendLine("Scenario: $scenarioId")
            appendLine("First mismatch: ${first.location()}")
            appendLine("Participant: ${first.participant ?: RACE_PARTICIPANT}")
            appendLine()
            appendLine(TABLE_HEADER)
            val primaryMismatches =
                mismatches.takeWhile { mismatch ->
                    mismatch.tick == first.tick && mismatch.participant == first.participant
                }
            primaryMismatches.forEach { appendLine(it.tableRow()) }
            val following = mismatches.drop(primaryMismatches.size)
            if (following.isNotEmpty()) {
                appendLine()
                appendLine("Following differences:")
                following.forEach { appendLine(it.conciseDescription()) }
            }
            if (hasOmittedMismatches) append("Additional differences omitted.")
        }
    }

    private companion object {
        const val RACE_PARTICIPANT = "race"
        const val TABLE_HEADER = "field              expected       actual         delta"
    }
}

/** One observed contract violation, ordered by trace/sample/field position. */
internal data class SnapshotMismatch(
    val tick: Long?,
    val participant: String?,
    val field: String,
    val expected: String,
    val actual: String,
    val delta: String,
) {
    fun compactDescription(): String = "$field expected $expected but was $actual ($delta)"

    fun location(): String = tick?.let { "tick $it" } ?: "before first sample"

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

private class MismatchCollector {
    private val mismatches = mutableListOf<SnapshotMismatch>()
    private var omitted = false

    fun result(): SnapshotComparison = SnapshotComparison(mismatches.toList(), omitted)

    fun typeMismatch(
        context: ComparisonContext,
        path: String,
        expected: JsonValue,
        actual: JsonValue,
    ) = add(context, path, expected.typeName(), actual.typeName(), EXACT_MISMATCH)

    fun integerTypeMismatch(
        context: ComparisonContext,
        path: String,
        expected: JsonValue,
        actual: JsonValue,
    ) = add(context, path, expected.typeName(), actual.typeName(), INTEGER_REQUIRED)

    fun exactMismatch(
        context: ComparisonContext,
        path: String,
        expected: JsonValue,
        actual: JsonValue,
    ) = add(context, path, expected.displayValue(), actual.displayValue(), EXACT_MISMATCH)

    fun missingField(
        context: ComparisonContext,
        path: String,
        expected: JsonValue,
    ) = add(context, path, expected.displayValue(), MISSING_VALUE, EXACT_MISMATCH)

    fun unexpectedField(
        context: ComparisonContext,
        path: String,
        actual: JsonValue,
    ) = add(context, path, MISSING_VALUE, actual.displayValue(), EXACT_MISMATCH)

    fun arraySizeMismatch(
        context: ComparisonContext,
        path: String,
        expectedSize: Int,
        actualSize: Int,
    ) = add(context, "$path.size", expectedSize.toString(), actualSize.toString(), EXACT_MISMATCH)

    fun nonFiniteNumber(
        context: ComparisonContext,
        path: String,
        expected: Double,
        actual: Double,
    ) = add(context, path, expected.describeNumber(), actual.describeNumber(), NON_FINITE_VALUE)

    fun invalidRotation(
        context: ComparisonContext,
        path: String,
        expected: JsonValue,
        actual: JsonValue,
    ) = add(context, path, expected.displayValue(), actual.displayValue(), ROTATION_RANGE)

    fun duplicateObjectField(
        context: ComparisonContext,
        path: String,
        source: String,
    ) = add(context, path, UNIQUE_KEY, "duplicate $source key", DUPLICATE_KEY)

    fun approximateMismatch(
        context: ComparisonContext,
        path: String,
        expected: JsonValue,
        actual: JsonValue,
        difference: Double,
        isAngle: Boolean,
    ) {
        val delta = if (isAngle) angularDelta(difference) else numericDelta(difference)
        add(context, path, expected.displayValue(), actual.displayValue(), delta)
    }

    private fun add(
        context: ComparisonContext,
        path: String,
        expected: String,
        actual: String,
        delta: String,
    ) {
        if (mismatches.size == MAX_REPORTED_MISMATCHES) {
            omitted = true
            return
        }
        mismatches +=
            SnapshotMismatch(
                tick = context.tick,
                participant = context.participant,
                field = path.displayField(),
                expected = expected,
                actual = actual,
                delta = delta,
            )
    }

    private companion object {
        const val MAX_REPORTED_MISMATCHES = 8
        const val MISSING_VALUE = "<missing>"
        const val EXACT_MISMATCH = "exact"
        const val INTEGER_REQUIRED = "integer required"
        const val NON_FINITE_VALUE = "non-finite value"
        const val ROTATION_RANGE = "outside [0, 360)"
        const val UNIQUE_KEY = "unique key"
        const val DUPLICATE_KEY = "duplicate key"
    }
}

/** Numerical fields that may differ only by insignificant fixed-timestep rounding. */
private enum class ApproximateSnapshotField(
    private val fieldNames: Set<String>,
    private val absoluteTolerance: Double,
    private val relativeTolerance: Double?,
    val isAngle: Boolean = false,
) {
    POSITION(setOf("x", "y"), SnapshotComparisonEngine.ABSOLUTE_TOLERANCE, null),
    VELOCITY(setOf("velocityX", "velocityY"), SnapshotComparisonEngine.ABSOLUTE_TOLERANCE, null),
    ROTATION(setOf("rotation"), SnapshotComparisonEngine.ABSOLUTE_TOLERANCE, null, isAngle = true),
    ANGULAR_VELOCITY(setOf("angularVelocity"), SnapshotComparisonEngine.ABSOLUTE_TOLERANCE, null),
    SPEED(
        setOf("longitudinalSpeed", "lateralSpeed"),
        SnapshotComparisonEngine.ABSOLUTE_TOLERANCE,
        null,
    ),
    DRIFT(setOf("driftAmount"), SnapshotComparisonEngine.ABSOLUTE_TOLERANCE, null),
    TIME(
        setOf("remainingSeconds", "elapsedSimulationTime", "bestLapTime"),
        SnapshotComparisonEngine.ABSOLUTE_TOLERANCE,
        null,
    ),
    ;

    fun delta(
        expected: Double,
        actual: Double,
    ): Double =
        if (isAngle) {
            shortestSignedAngularDelta(actual - expected)
        } else {
            actual - expected
        }

    fun allowedTolerance(
        expected: Double,
        actual: Double,
    ): Double =
        relativeTolerance?.let { max(absoluteTolerance, it * max(abs(expected), abs(actual))) }
            ?: absoluteTolerance

    companion object {
        fun forPath(path: String): ApproximateSnapshotField? {
            val name = path.substringAfterLast('.')
            return entries.firstOrNull { name in it.fieldNames }
        }
    }
}

private fun shortestSignedAngularDelta(difference: Double): Double {
    val normalized = ((difference % FULL_TURN) + FULL_TURN) % FULL_TURN
    return if (normalized > HALF_TURN) normalized - FULL_TURN else normalized
}

private fun Double.isNormalizedRotation(): Boolean = this >= 0.0 && this < FULL_TURN

private fun angularDelta(difference: Double): String =
    "angular delta ${String.format(Locale.ROOT, "%.6f", abs(difference))}"

private fun numericDelta(difference: Double): String = String.format(Locale.ROOT, "%+.6f", difference)

private fun JsonValue.displayValue(): String =
    when {
        isString -> asString()
        isLong -> asLong().toString()
        isNumber -> asDouble().describeNumber()
        else -> toString().replace('\n', ' ')
    }

private fun JsonValue.typeName(): String = "JSON ${type()}"

private fun String.displayField(): String =
    substringAfterLast('.').let { name ->
        if (name == "size") "${substringBeforeLast('.').substringAfterLast('.')}.size" else name
    }

private fun Double.describeNumber(): String =
    when {
        isNaN() -> "NaN"
        this == Double.POSITIVE_INFINITY -> "Infinity"
        this == Double.NEGATIVE_INFINITY -> "-Infinity"
        else -> toString()
    }

private const val FULL_TURN = 360.0
private const val HALF_TURN = FULL_TURN / 2.0
