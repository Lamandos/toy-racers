package com.example.toyracers.race

import com.example.toyracers.car.CarPhysics
import com.example.toyracers.input.PlayerInput
import com.example.toyracers.track.TrackLoader
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RaceStateScenarioTest {
    private val track = TrackLoader().load().copy(collisionShapes = emptyList())

    @Test
    fun `pre-race countdown GO and racing only simulate after countdown completes`() {
        val session = RaceSession(track)
        val initialX = session.player.state.x

        val preRaceStep = session.advance(CarPhysics.FIXED_DELTA_SECONDS, PlayerInput(throttle = 1f))

        assertEquals(RacePhase.LOADING, session.raceState.phase)
        assertEquals(0, preRaceStep.physicalSteps)
        assertEquals(initialX, session.player.state.x, TOLERANCE)

        session.start()
        val countdownStep =
            session.advance(
                session.raceState.countdownDurationSeconds - CarPhysics.FIXED_DELTA_SECONDS,
                PlayerInput(throttle = 1f),
            )

        assertEquals(RacePhase.COUNTDOWN, session.raceState.phase)
        assertEquals(0, countdownStep.physicalSteps)
        assertEquals(initialX, session.player.state.x, TOLERANCE)

        val goStep = session.advance(CarPhysics.FIXED_DELTA_SECONDS * 2f, PlayerInput(throttle = 1f))

        assertEquals(RacePhase.RACING, session.raceState.phase)
        assertEquals(1, goStep.physicalSteps)
        assertTrue(session.player.state.x > initialX)
        assertEquals(CarPhysics.FIXED_DELTA_SECONDS, session.player.progress.totalRaceTime, TOLERANCE)
    }

    @Test
    fun `checkpoint progression advances only the next required checkpoint`() {
        val session = racingSession()
        session.player.state.x = 90f
        session.player.state.y = 35.9f
        session.player.state.rotationDeg = 90f
        session.player.state.speed = FINISH_SPEED
        session.player.state.velocityY = FINISH_SPEED

        val step = session.advance(CarPhysics.FIXED_DELTA_SECONDS, PlayerInput.NONE)

        assertTrue(step.playerCheckpointPassed)
        assertEquals(1, session.player.progress.currentCheckpointIndex)
        assertEquals(0, session.player.progress.completedLaps)
    }

    @Test
    fun `lap progression enters final lap before the finish`() {
        val session = racingSession()
        configureStartLineCrossing(session.player, completedLaps = 1, y = START_LINE_CENTER_Y)

        session.advance(CarPhysics.FIXED_DELTA_SECONDS, PlayerInput.NONE)

        assertEquals(2, session.player.progress.completedLaps)
        assertEquals(0, session.player.progress.currentCheckpointIndex)
        assertFalse(session.player.progress.finished)
        assertEquals(RacePhase.RACING, session.raceState.phase)
    }

    @Test
    fun `near-simultaneous finishes produce stable results and participant ranking`() {
        val session = racingSession()
        configureStartLineCrossing(session.player, completedLaps = 2, y = START_LINE_CENTER_Y)
        configureStartLineCrossing(session.opponents[0], completedLaps = 2, y = 13f)
        configureStartLineCrossing(session.opponents[1], completedLaps = 2, y = 19f)

        session.advance(CarPhysics.FIXED_DELTA_SECONDS, PlayerInput.NONE)

        val finishers = listOf(session.player, session.opponents[0], session.opponents[1])
        assertEquals(RacePhase.FINISHED, session.raceState.phase)
        assertTrue(finishers.all { it.progress.finished })
        assertEquals(
            listOf(PLAYER_ID, "ai-0", "ai-1"),
            finishers.sortedBy { it.progress.finishPosition }.map { it.id },
        )
        assertEquals(listOf(1, 2, 3), finishers.map { it.progress.finishPosition })
        assertEquals(1, session.playerPosition)
        assertEquals(2, session.participantPositions.getValue("ai-0"))
        assertEquals(3, session.participantPositions.getValue("ai-1"))

        val afterFinishStep = session.advance(CarPhysics.FIXED_DELTA_SECONDS, PlayerInput.NONE)
        assertEquals(0, afterFinishStep.physicalSteps)
    }

    @Test
    fun `all five AI participants begin racing on GO`() {
        val session = RaceSession(track)

        session.start()
        session.advance(
            session.raceState.countdownDurationSeconds + CarPhysics.FIXED_DELTA_SECONDS,
            PlayerInput.NONE,
        )
        session.advance(CarPhysics.FIXED_DELTA_SECONDS, PlayerInput.NONE)

        assertEquals(RacePhase.RACING, session.raceState.phase)
        assertEquals(5, session.opponents.size)
        session.opponents.forEach { opponent ->
            assertEquals(CarPhysics.FIXED_DELTA_SECONDS, opponent.progress.totalRaceTime, TOLERANCE)
        }
        assertEquals(6, session.participantPositions.size)
    }

    private fun racingSession(): RaceSession =
        RaceSession(track).apply {
            start()
            advance(raceState.countdownDurationSeconds, PlayerInput.NONE)
        }

    private fun configureStartLineCrossing(
        participant: RaceParticipant,
        completedLaps: Int,
        y: Float,
    ) {
        participant.progress.currentCheckpointIndex = track.checkpoints.size
        participant.progress.completedLaps = completedLaps
        participant.state.x = START_LINE_BEFORE_X
        participant.state.y = y
        participant.state.rotationDeg = 0f
        participant.state.speed = FINISH_SPEED
        participant.state.velocityX = FINISH_SPEED
    }

    private companion object {
        const val PLAYER_ID = "player"
        const val FINISH_SPEED = 24f
        const val START_LINE_BEFORE_X = 55.1f
        const val START_LINE_CENTER_Y = 16f
        const val TOLERANCE = 0.0001f
    }
}
