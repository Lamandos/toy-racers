package com.example.toyracers.screen

import com.example.toyracers.ai.AiDebugSnapshot
import com.example.toyracers.debug.FrameTelemetry
import com.example.toyracers.debug.FrameTelemetrySample
import com.example.toyracers.debug.FrameTelemetrySnapshot
import com.example.toyracers.race.RaceParticipant
import com.example.toyracers.race.RaceSession
import com.example.toyracers.track.TrackPoint
import com.example.toyracers.ui.MinimapParticipantRole
import com.example.toyracers.ui.MinimapParticipantSnapshot
import com.example.toyracers.ui.RaceMinimapSnapshot

internal const val CAMERA_VIEW_WIDTH = 24f
internal const val CAMERA_VIEW_HEIGHT = CAMERA_VIEW_WIDTH * 9f / 16f
internal const val MIN_SHAKE_IMPACT_SPEED = 3f
internal const val SHAKE_PER_IMPACT_SPEED = 0.025f
internal const val COUNTDOWN_START_NUMBER = 3
internal const val TRACK_DRAW_CALLS = 1

internal enum class RaceUiAction {
    PAUSE,
    RESUME,
    RESTART,
    QUIT_TO_MENU,
}

internal data class RaceUpdateMetrics(
    val simulationDurationNanos: Long,
    val collisionDurationNanos: Long,
    val audioDurationNanos: Long,
    val physicalSteps: Int,
)

internal data class WorldRenderMetrics(
    val drawCalls: Int,
    val carFlushes: Int,
)

internal class RaceTelemetryRecorder {
    private val telemetry = FrameTelemetry()
    private var previousFrameStartNanos: Long? = null
    var pendingSample: FrameTelemetrySample? = null

    fun recordCompletedFrame(frameStartNanos: Long): FrameTelemetrySnapshot? {
        val previousStart = previousFrameStartNanos
        previousFrameStartNanos = frameStartNanos
        val sample = pendingSample ?: return null
        val duration = previousStart?.let { frameStartNanos - it } ?: return null
        return telemetry.record(sample.copy(frameDurationNanos = duration))
    }

    fun reset() {
        telemetry.clear()
        previousFrameStartNanos = null
        pendingSample = null
    }
}

/** Moves AI diagnostics with the interpolated car while retaining the physical sensor sample. */
internal fun displayAiDebugSnapshot(
    raceSession: RaceSession,
    participant: RaceParticipant,
): AiDebugSnapshot? {
    val snapshot = participant.driver?.debugSnapshot ?: return null
    val renderedState = raceSession.renderStateOf(participant)
    val offsetX = renderedState.x - snapshot.position.x
    val offsetY = renderedState.y - snapshot.position.y
    return snapshot.copy(
        position = TrackPoint(renderedState.x, renderedState.y),
        sensorRays =
            snapshot.sensorRays.map { ray ->
                ray.copy(
                    start = TrackPoint(ray.start.x + offsetX, ray.start.y + offsetY),
                    end = TrackPoint(ray.end.x + offsetX, ray.end.y + offsetY),
                )
            },
    )
}

internal fun RaceSession.createMinimapSnapshot(): RaceMinimapSnapshot =
    RaceMinimapSnapshot(
        participants =
            buildList(opponents.size + 1) {
                opponents.forEach {
                    add(toMinimapSnapshot(it, MinimapParticipantRole.OPPONENT))
                }
                add(toMinimapSnapshot(player, MinimapParticipantRole.PLAYER))
            },
    )

private fun RaceSession.toMinimapSnapshot(
    participant: RaceParticipant,
    role: MinimapParticipantRole,
): MinimapParticipantSnapshot {
    val state = renderStateOf(participant)
    return MinimapParticipantSnapshot(
        x = state.x,
        y = state.y,
        rotationDeg = state.rotationDeg,
        role = role,
    )
}
