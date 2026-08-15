package com.example.toyracers.race

import com.example.toyracers.track.TrackLoader
import com.example.toyracers.track.TrackPoint
import org.junit.Assert.assertEquals
import org.junit.Test

class PositionTrackerTest {
    private val tracker = PositionTracker(TrackLoader().load())

    @Test
    fun `completed checkpoints and laps determine running order`() {
        val positions =
            tracker.positions(
                listOf(
                    competitor("near-next", laps = 0, checkpoint = 1, x = 20f, y = 18f),
                    competitor("lap-leader", laps = 1, checkpoint = 0, x = 35f, y = 11f),
                    competitor("far-next", laps = 0, checkpoint = 1, x = 30f, y = 18f),
                    competitor("behind", laps = 0, checkpoint = 0, x = 35f, y = 11f),
                ),
            )

        assertEquals(1, positions["lap-leader"])
        assertEquals(2, positions["near-next"])
        assertEquals(3, positions["far-next"])
        assertEquals(4, positions["behind"])
    }

    @Test
    fun `finished cars retain their assigned finish order`() {
        val positions =
            tracker.positions(
                listOf(
                    competitor("running", laps = 8, checkpoint = 3, x = 20f, y = 6f),
                    competitor("second", finished = true, finishPosition = 2),
                    competitor("first", finished = true, finishPosition = 1),
                ),
            )

        assertEquals(1, positions["first"])
        assertEquals(2, positions["second"])
        assertEquals(3, positions["running"])
    }

    @Test(expected = IllegalArgumentException::class)
    fun `duplicate competitor ids are rejected`() {
        tracker.positions(listOf(competitor("same"), competitor("same")))
    }

    private fun competitor(
        id: String,
        laps: Int = 0,
        checkpoint: Int = 0,
        x: Float = 0f,
        y: Float = 0f,
        finished: Boolean = false,
        finishPosition: Int? = null,
    ) = RaceCompetitor(
        id = id,
        progress =
            RaceProgress(
                completedLaps = laps,
                currentCheckpointIndex = checkpoint,
                finished = finished,
                finishPosition = finishPosition,
            ),
        position = TrackPoint(x * TrackLoader.MAP_SCALE, y * TrackLoader.MAP_SCALE),
    )
}
