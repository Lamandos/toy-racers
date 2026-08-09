package com.example.toyracers.debug

import org.junit.Assert.assertEquals
import org.junit.Test

class FrameTelemetryTest {
    @Test
    fun `reports rolling frame time percentiles`() {
        val telemetry = FrameTelemetry(sampleCapacity = 4)

        listOf(10L, 20L, 30L, 40L).forEach { durationMs ->
            telemetry.record(sample(durationMs))
        }

        val snapshot = telemetry.record(sample(50L))

        assertEquals(50f, snapshot.frameTimeMs, EPSILON)
        assertEquals(30f, snapshot.p50FrameTimeMs, EPSILON)
        assertEquals(50f, snapshot.p95FrameTimeMs, EPSILON)
        assertEquals(50f, snapshot.p99FrameTimeMs, EPSILON)
    }

    private fun sample(frameDurationMs: Long) = FrameTelemetrySample(
        frameDurationNanos = frameDurationMs * NANOSECONDS_PER_MILLISECOND,
        simulationDurationNanos = 2 * NANOSECONDS_PER_MILLISECOND,
        collisionDurationNanos = NANOSECONDS_PER_MILLISECOND,
        worldRenderDurationNanos = 3 * NANOSECONDS_PER_MILLISECOND,
        interfaceDurationNanos = 4 * NANOSECONDS_PER_MILLISECOND,
        audioDurationNanos = 5 * NANOSECONDS_PER_MILLISECOND,
        physicalSteps = 1,
        worldDrawCalls = 2,
        carFlushes = 1,
        framesPerSecond = 60,
        refreshRateHz = 60,
    )

    private companion object {
        const val NANOSECONDS_PER_MILLISECOND = 1_000_000L
        const val EPSILON = 0.0001f
    }
}
