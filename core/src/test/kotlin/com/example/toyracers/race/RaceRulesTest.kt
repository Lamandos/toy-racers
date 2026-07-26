package com.example.toyracers.race

import com.example.toyracers.track.TrackLoader
import com.example.toyracers.track.TrackPoint
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RaceRulesTest {
    private val track = TrackLoader().load()

    @Test
    fun `checkpoints only count in order`() {
        val rules = RaceRules(track)
        val progress = RaceProgress()

        crossCheckpoint(rules, progress, 1)
        assertEquals(0, progress.currentCheckpointIndex)

        crossCheckpoint(rules, progress, 0)
        assertEquals(1, progress.currentCheckpointIndex)
        crossCheckpoint(rules, progress, 2)
        assertEquals(1, progress.currentCheckpointIndex)
        crossCheckpoint(rules, progress, 1)
        assertEquals(2, progress.currentCheckpointIndex)
    }

    @Test
    fun `backward crossing and repeated gate do not advance progress`() {
        val rules = RaceRules(track)
        val progress = RaceProgress()

        rules.update(
            progress,
            previousPosition = point(35f, 13f),
            currentPosition = point(35f, 11f),
            deltaSeconds = 0f,
        )
        assertEquals(0, progress.currentCheckpointIndex)

        crossCheckpoint(rules, progress, 0)
        crossCheckpoint(rules, progress, 0)
        assertEquals(1, progress.currentCheckpointIndex)
    }

    @Test
    fun `finish line requires every checkpoint and valid direction`() {
        val rules = RaceRules(track)
        val progress = RaceProgress()

        crossFinish(rules, progress)
        assertEquals(0, progress.completedLaps)

        completeCheckpoints(rules, progress)
        crossFinishBackward(rules, progress)
        assertEquals(0, progress.completedLaps)
        crossFinish(rules, progress)

        assertEquals(1, progress.completedLaps)
        assertEquals(0, progress.currentCheckpointIndex)
    }

    @Test
    fun `three laps finish race and record deterministic timing`() {
        val rules = RaceRules(track, requiredLaps = 3)
        val progress = RaceProgress()

        advanceTime(rules, progress, 12f)
        completeLap(rules, progress)
        advanceTime(rules, progress, 10f)
        completeLap(rules, progress)
        advanceTime(rules, progress, 14f)
        completeLap(rules, progress)

        assertTrue(progress.finished)
        assertEquals(3, progress.completedLaps)
        assertEquals(36f, progress.totalRaceTime, TOLERANCE)
        assertEquals(10f, progress.bestLapTime ?: -1f, TOLERANCE)
        assertEquals(1, progress.finishPosition)

        advanceTime(rules, progress, 5f)
        assertEquals(36f, progress.totalRaceTime, TOLERANCE)
    }

    @Test
    fun `respawn movement cannot count a checkpoint`() {
        val rules = RaceRules(track)
        val progress = RaceProgress()

        rules.update(
            progress,
            previousPosition = point(35f, 11f),
            currentPosition = point(35f, 13f),
            deltaSeconds = 1f,
            allowProgress = false,
        )

        assertEquals(0, progress.currentCheckpointIndex)
        assertEquals(1f, progress.totalRaceTime, TOLERANCE)
        assertFalse(progress.finished)
        assertNull(progress.finishPosition)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `negative simulation time is rejected`() {
        RaceRules(track).update(
            RaceProgress(),
            previousPosition = point(0f, 0f),
            currentPosition = point(0f, 0f),
            deltaSeconds = -0.1f,
        )
    }

    private fun completeLap(
        rules: RaceRules,
        progress: RaceProgress,
    ) {
        completeCheckpoints(rules, progress)
        crossFinish(rules, progress)
    }

    private fun completeCheckpoints(
        rules: RaceRules,
        progress: RaceProgress,
    ) {
        track.checkpoints.indices.forEach { crossCheckpoint(rules, progress, it) }
    }

    private fun crossCheckpoint(
        rules: RaceRules,
        progress: RaceProgress,
        index: Int,
    ) {
        when (index) {
            0 -> rules.update(progress, point(35f, 11f), point(35f, 13f), 0f)
            1 -> rules.update(progress, point(22f, 18f), point(19f, 18f), 0f)
            2 -> rules.update(progress, point(7f, 13f), point(7f, 11f), 0f)
        }
    }

    private fun crossFinish(
        rules: RaceRules,
        progress: RaceProgress,
    ) {
        rules.update(progress, point(19f, 6f), point(22f, 6f), 0f)
    }

    private fun crossFinishBackward(
        rules: RaceRules,
        progress: RaceProgress,
    ) {
        rules.update(progress, point(22f, 6f), point(19f, 6f), 0f)
    }

    private fun advanceTime(
        rules: RaceRules,
        progress: RaceProgress,
        seconds: Float,
    ) {
        rules.update(progress, point(6f, 6f), point(6f, 6f), seconds)
    }

    private fun point(
        x: Float,
        y: Float,
    ) = TrackPoint(x, y)

    private companion object {
        const val TOLERANCE = 0.001f
    }
}
