package com.example.toyracers.race

import org.junit.Assert.assertEquals
import org.junit.Test

class RaceStateTest {
    @Test
    fun `race follows loading ready countdown and racing phases`() {
        val state = RaceState(countdownDurationSeconds = 3f)

        assertEquals(RacePhase.LOADING, state.phase)
        state.markReady()
        assertEquals(RacePhase.READY, state.phase)
        state.startCountdown()
        assertEquals(RacePhase.COUNTDOWN, state.phase)

        assertEquals(0f, state.advance(2f), TOLERANCE)
        assertEquals(1f, state.countdownRemainingSeconds, TOLERANCE)
        assertEquals(0.5f, state.advance(1.5f), TOLERANCE)
        assertEquals(RacePhase.RACING, state.phase)
    }

    @Test
    fun `pause produces no simulation time until explicit resume`() {
        val state = racingState()

        state.pause()
        assertEquals(RacePhase.PAUSED, state.phase)
        assertEquals(0f, state.advance(10f), TOLERANCE)

        state.resume()
        assertEquals(RacePhase.RACING, state.phase)
        assertEquals(0.25f, state.advance(0.25f), TOLERANCE)
    }

    @Test
    fun `finished race cannot advance simulation`() {
        val state = racingState()

        state.finish()

        assertEquals(RacePhase.FINISHED, state.phase)
        assertEquals(0f, state.advance(1f), TOLERANCE)
    }

    @Test
    fun `restart returns any phase to a fresh countdown`() {
        val state = racingState()
        state.pause()

        state.restart()

        assertEquals(RacePhase.COUNTDOWN, state.phase)
        assertEquals(3f, state.countdownRemainingSeconds, TOLERANCE)
    }

    @Test(expected = IllegalStateException::class)
    fun `countdown cannot start before loading completes`() {
        RaceState().startCountdown()
    }

    @Test(expected = IllegalArgumentException::class)
    fun `negative delta is rejected`() {
        RaceState().advance(-0.1f)
    }

    private fun racingState(): RaceState =
        RaceState().apply {
            markReady()
            startCountdown()
            advance(countdownDurationSeconds)
        }

    private companion object {
        const val TOLERANCE = 0.001f
    }
}
