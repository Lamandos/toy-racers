package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonValue
import kotlin.math.abs

/**
 * Compares normalized behavioral traces from the Kotlin reference or another runtime.
 *
 * Discrete contract values must match exactly. Simulation values use the per-field tolerances in
 * [ApproximateSnapshotField]; no relative tolerance is currently enabled.
 */
internal object SnapshotComparisonEngine {
    const val ABSOLUTE_TOLERANCE = 0.0001
    private const val ROOT_PATH = "$"
    private const val MAX_REPORTED_SCHEMA_VIOLATIONS = 8
    private const val SCHEMA_VALIDATION_FAILURE = "schema validation"

    fun compare(
        expected: JsonValue,
        actual: JsonValue,
        rootPath: String = ROOT_PATH,
        validateSchema: Boolean = true,
    ): SnapshotComparison {
        if (validateSchema) schemaComparison(expected, actual, rootPath)?.let { return it }
        val collector = MismatchCollector()
        compareValue(expected, actual, rootPath, ComparisonContext(), collector)
        return collector.result()
    }

    private fun schemaComparison(
        expected: JsonValue,
        actual: JsonValue,
        rootPath: String,
    ): SnapshotComparison? {
        val violations =
            listOf("expected" to expected, "actual" to actual)
                .flatMap { (source, value) ->
                    BehavioralTraceSchemaValidator
                        .validateIfTrace(value)
                        .map { violation -> source to violation }
                }
        if (violations.isEmpty()) return null
        val reported = violations.take(MAX_REPORTED_SCHEMA_VIOLATIONS)
        return SnapshotComparison(
            mismatches =
                reported.map { (source, violation) ->
                    SnapshotMismatch(
                        tick = null,
                        participant = null,
                        sampleIndex = null,
                        sampleLabel = null,
                        field = "$rootPath.${violation.path}".displayField(),
                        expected = "schema-valid",
                        actual = "$source: ${violation.message}",
                        delta = SCHEMA_VALIDATION_FAILURE,
                    )
                },
            hasOmittedMismatches = violations.size > MAX_REPORTED_SCHEMA_VIOLATIONS,
        )
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
            collector.typeMismatch(context.withObjectIdentifiers(expected, actual), path, expected, actual)
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
                compareValue(
                    pair.first,
                    pair.second,
                    "$path[$index]",
                    context.withSampleIdentity(index, pair.first, pair.second),
                    collector,
                )
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
        if (expectedValue.isNegativeZero() || actualValue.isNegativeZero()) {
            collector.negativeZero(context, path, expected, actual)
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

    private fun ComparisonContext.withObjectIdentifiers(
        expected: JsonValue,
        actual: JsonValue,
    ): ComparisonContext =
        when {
            expected.isObject -> withIdentifiers(expected)
            actual.isObject -> withIdentifiers(actual)
            else -> this
        }

    private fun ComparisonContext.withSampleIdentity(
        index: Int,
        expected: JsonValue,
        actual: JsonValue,
    ): ComparisonContext =
        copy(
            sampleIndex = index,
            sampleLabel =
                expected.get("label").stringValueOrNull()
                    ?: actual.get("label").stringValueOrNull()
                    ?: sampleLabel,
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
        if (!path.endsWith(".participants") && !path.endsWith(".finishResults")) return this
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
                    mismatch.tick == first.tick &&
                        mismatch.participant == first.participant &&
                        mismatch.sampleIndex == first.sampleIndex &&
                        mismatch.sampleLabel == first.sampleLabel
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

    fun negativeZero(
        context: ComparisonContext,
        path: String,
        expected: JsonValue,
        actual: JsonValue,
    ) = add(context, path, expected.displayValue(), actual.displayValue(), NEGATIVE_ZERO)

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
                sampleIndex = context.sampleIndex,
                sampleLabel = context.sampleLabel,
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
        const val NEGATIVE_ZERO = "negative zero"
        const val UNIQUE_KEY = "unique key"
        const val DUPLICATE_KEY = "duplicate key"
    }
}

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
