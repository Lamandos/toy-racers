package com.example.toyracers.debug

import kotlin.math.ceil

/** One debug-only timing sample collected after a complete race frame. */
data class FrameTelemetrySample(
    val frameDurationNanos: Long,
    val simulationDurationNanos: Long,
    val collisionDurationNanos: Long,
    val worldRenderDurationNanos: Long,
    val interfaceDurationNanos: Long,
    val audioDurationNanos: Long,
    val physicalSteps: Int,
    val worldDrawCalls: Int,
    val carFlushes: Int,
    val framesPerSecond: Int,
    val refreshRateHz: Int?,
)

data class FrameTelemetrySnapshot(
    val frameTimeMs: Float,
    val p50FrameTimeMs: Float,
    val p95FrameTimeMs: Float,
    val p99FrameTimeMs: Float,
    val simulationTimeMs: Float,
    val collisionTimeMs: Float,
    val worldRenderTimeMs: Float,
    val interfaceTimeMs: Float,
    val audioTimeMs: Float,
    val physicalSteps: Int,
    val worldDrawCalls: Int,
    val carFlushes: Int,
    val framesPerSecond: Int,
    val refreshRateHz: Int?,
)

/**
 * Keeps a bounded rolling frame-time window for the optional performance overlay.
 *
 * This class does not read platform state and is only updated while the overlay is enabled.
 */
class FrameTelemetry(
    private val sampleCapacity: Int = DEFAULT_SAMPLE_CAPACITY,
) {
    private val frameTimesMs = FloatArray(sampleCapacity)
    private var sampleCount = 0
    private var nextSampleIndex = 0

    init {
        require(sampleCapacity > 0) { "Sample capacity must be positive" }
    }

    fun record(sample: FrameTelemetrySample): FrameTelemetrySnapshot {
        val frameTimeMs = sample.frameDurationNanos.toMilliseconds()
        frameTimesMs[nextSampleIndex] = frameTimeMs
        nextSampleIndex = (nextSampleIndex + 1) % sampleCapacity
        sampleCount = (sampleCount + 1).coerceAtMost(sampleCapacity)

        return FrameTelemetrySnapshot(
            frameTimeMs = frameTimeMs,
            p50FrameTimeMs = percentile(0.50f),
            p95FrameTimeMs = percentile(0.95f),
            p99FrameTimeMs = percentile(0.99f),
            simulationTimeMs = sample.simulationDurationNanos.toMilliseconds(),
            collisionTimeMs = sample.collisionDurationNanos.toMilliseconds(),
            worldRenderTimeMs = sample.worldRenderDurationNanos.toMilliseconds(),
            interfaceTimeMs = sample.interfaceDurationNanos.toMilliseconds(),
            audioTimeMs = sample.audioDurationNanos.toMilliseconds(),
            physicalSteps = sample.physicalSteps,
            worldDrawCalls = sample.worldDrawCalls,
            carFlushes = sample.carFlushes,
            framesPerSecond = sample.framesPerSecond,
            refreshRateHz = sample.refreshRateHz,
        )
    }

    fun clear() {
        sampleCount = 0
        nextSampleIndex = 0
    }

    private fun percentile(percentile: Float): Float {
        check(sampleCount > 0) { "Cannot calculate a percentile without samples" }
        val sorted = frameTimesMs.copyOf(sampleCount).sortedArray()
        val index = ceil((sampleCount - 1) * percentile.coerceIn(0f, 1f)).toInt()
        return sorted[index]
    }

    private fun Long.toMilliseconds(): Float = this / NANOSECONDS_PER_MILLISECOND

    private companion object {
        const val DEFAULT_SAMPLE_CAPACITY = 240
        const val NANOSECONDS_PER_MILLISECOND = 1_000_000f
    }
}
