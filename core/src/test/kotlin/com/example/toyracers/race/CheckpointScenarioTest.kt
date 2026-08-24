package com.example.toyracers.race

import com.example.toyracers.track.Checkpoint
import com.example.toyracers.track.StartLine
import com.example.toyracers.track.TrackId
import com.example.toyracers.track.TrackLoader
import com.example.toyracers.track.TrackPoint
import com.example.toyracers.track.TrackSegment
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.sqrt

class CheckpointScenarioTest {
    private val trackLoader = TrackLoader()

    @Test
    fun `skipped checkpoints do not advance progress on built in tracks`() {
        TrackId.entries.forEach { trackId ->
            val track = trackLoader.load(trackId)
            val rules = RaceRules(track)
            val progress = RaceProgress()

            track.checkpoints.forEachIndexed { index, checkpoint ->
                if (index < track.checkpoints.lastIndex) {
                    crossCheckpoint(rules, progress, track.checkpoints[index + 1])
                    assertEquals(index, progress.currentCheckpointIndex)
                }

                crossCheckpoint(rules, progress, checkpoint)
                assertEquals(index + 1, progress.currentCheckpointIndex)
            }
        }
    }

    @Test
    fun `ordered checkpoints and start line complete a valid lap on built in tracks`() {
        TrackId.entries.forEach { trackId ->
            val track = trackLoader.load(trackId)
            val rules = RaceRules(track, requiredLaps = 1)
            val progress = RaceProgress()

            track.checkpoints.forEach { checkpoint -> crossCheckpoint(rules, progress, checkpoint) }
            crossStartLine(rules, progress, track.startLine)

            assertEquals(1, progress.completedLaps)
            assertEquals(0, progress.currentCheckpointIndex)
            assertTrue(progress.finished)
            assertEquals(1, progress.finishPosition)
            assertTrue(progress.bestLapTime!! > 0f)
        }
    }

    @Test
    fun `invalid start line crossings cannot increment a lap`() {
        TrackId.entries.forEach { trackId ->
            val track = trackLoader.load(trackId)
            val rules = RaceRules(track)
            val progress = RaceProgress()

            crossStartLine(rules, progress, track.startLine)
            assertEquals(0, progress.completedLaps)

            track.checkpoints.forEach { checkpoint -> crossCheckpoint(rules, progress, checkpoint) }
            crossStartLineBackward(rules, progress, track.startLine)

            assertEquals(0, progress.completedLaps)
            assertEquals(track.checkpoints.size, progress.currentCheckpointIndex)
        }
    }

    private fun crossCheckpoint(
        rules: RaceRules,
        progress: RaceProgress,
        checkpoint: Checkpoint,
    ) {
        crossGate(
            rules = rules,
            progress = progress,
            gate = checkpoint.gate,
            forwardX = checkpoint.forwardX,
            forwardY = checkpoint.forwardY,
        )
    }

    private fun crossStartLine(
        rules: RaceRules,
        progress: RaceProgress,
        startLine: StartLine,
    ) {
        val center =
            TrackPoint(
                startLine.bounds.x + startLine.bounds.width / 2f,
                startLine.bounds.y + startLine.bounds.height / 2f,
            )
        crossMovement(
            rules = rules,
            progress = progress,
            center = center,
            forwardX = startLine.forwardX,
            forwardY = startLine.forwardY,
        )
    }

    private fun crossStartLineBackward(
        rules: RaceRules,
        progress: RaceProgress,
        startLine: StartLine,
    ) {
        val center =
            TrackPoint(
                startLine.bounds.x + startLine.bounds.width / 2f,
                startLine.bounds.y + startLine.bounds.height / 2f,
            )
        crossMovement(
            rules = rules,
            progress = progress,
            center = center,
            forwardX = -startLine.forwardX,
            forwardY = -startLine.forwardY,
        )
    }

    private fun crossGate(
        rules: RaceRules,
        progress: RaceProgress,
        gate: TrackSegment,
        forwardX: Float,
        forwardY: Float,
    ) {
        val center =
            TrackPoint(
                (gate.start.x + gate.end.x) / 2f,
                (gate.start.y + gate.end.y) / 2f,
            )
        crossMovement(rules, progress, center, forwardX, forwardY)
    }

    private fun crossMovement(
        rules: RaceRules,
        progress: RaceProgress,
        center: TrackPoint,
        forwardX: Float,
        forwardY: Float,
    ) {
        val length = sqrt(forwardX * forwardX + forwardY * forwardY)
        val before =
            TrackPoint(
                center.x - forwardX / length * CROSSING_DISTANCE,
                center.y - forwardY / length * CROSSING_DISTANCE,
            )
        val after =
            TrackPoint(
                center.x + forwardX / length * CROSSING_DISTANCE,
                center.y + forwardY / length * CROSSING_DISTANCE,
            )

        rules.update(progress, before, after, deltaSeconds = 1f)
    }

    private companion object {
        const val CROSSING_DISTANCE = 1f
    }
}
