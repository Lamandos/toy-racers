package com.example.toyracers.compat

import com.badlogic.gdx.utils.JsonValue
import java.util.Locale
import kotlin.math.abs
import kotlin.math.max

/** Numerical fields that may differ only by insignificant fixed-timestep rounding. */
internal enum class ApproximateSnapshotField(
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

internal fun shortestSignedAngularDelta(difference: Double): Double {
    val normalized = ((difference % FULL_TURN) + FULL_TURN) % FULL_TURN
    return if (normalized > HALF_TURN) normalized - FULL_TURN else normalized
}

internal fun Double.isNormalizedRotation(): Boolean = this >= 0.0 && this < FULL_TURN

internal fun Double.isNegativeZero(): Boolean = this == 0.0 && toBits() == (-0.0).toBits()

internal fun JsonValue.isNegativeZeroNumber(): Boolean =
    isNumber && (asDouble().isNegativeZero() || (isLong && asString() == NEGATIVE_ZERO_LITERAL))

internal fun angularDelta(difference: Double): String =
    "angular delta ${String.format(Locale.ROOT, "%.6f", abs(difference))}"

internal fun numericDelta(difference: Double): String = String.format(Locale.ROOT, "%+.6f", difference)

private const val FULL_TURN = 360.0
private const val HALF_TURN = FULL_TURN / 2.0
private const val NEGATIVE_ZERO_LITERAL = "-0"
