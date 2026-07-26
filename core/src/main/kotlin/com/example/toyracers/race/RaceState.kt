package com.example.toyracers.race

enum class RacePhase {
    LOADING,
    READY,
    COUNTDOWN,
    RACING,
    PAUSED,
    FINISHED,
}

/**
 * Owns legal race-phase transitions and converts frame time into active simulation time.
 *
 * Rendering and platform lifecycle can observe this state, but only [RACING] produces time that
 * may be passed to physics, AI, and race timers.
 */
class RaceState(
    val countdownDurationSeconds: Float = DEFAULT_COUNTDOWN_SECONDS,
) {
    var phase: RacePhase = RacePhase.LOADING
        private set

    var countdownRemainingSeconds: Float = countdownDurationSeconds
        private set

    init {
        require(countdownDurationSeconds > 0f) {
            "Countdown duration must be positive"
        }
    }

    fun markReady() {
        requirePhase(RacePhase.LOADING)
        phase = RacePhase.READY
    }

    fun startCountdown() {
        requirePhase(RacePhase.READY)
        countdownRemainingSeconds = countdownDurationSeconds
        phase = RacePhase.COUNTDOWN
    }

    /**
     * Advances countdown state and returns the part of [deltaSeconds] available to simulation.
     */
    fun advance(deltaSeconds: Float): Float {
        require(deltaSeconds >= 0f) { "Delta time must not be negative" }
        return when (phase) {
            RacePhase.COUNTDOWN -> advanceCountdown(deltaSeconds)
            RacePhase.RACING -> deltaSeconds
            else -> 0f
        }
    }

    fun pause() {
        requirePhase(RacePhase.RACING)
        phase = RacePhase.PAUSED
    }

    fun resume() {
        requirePhase(RacePhase.PAUSED)
        phase = RacePhase.RACING
    }

    fun finish() {
        requirePhase(RacePhase.RACING)
        phase = RacePhase.FINISHED
    }

    fun restart() {
        phase = RacePhase.READY
        startCountdown()
    }

    private fun advanceCountdown(deltaSeconds: Float): Float {
        if (deltaSeconds < countdownRemainingSeconds) {
            countdownRemainingSeconds -= deltaSeconds
            return 0f
        }

        val simulationSeconds = deltaSeconds - countdownRemainingSeconds
        countdownRemainingSeconds = 0f
        phase = RacePhase.RACING
        return simulationSeconds
    }

    private fun requirePhase(expected: RacePhase) {
        check(phase == expected) {
            "Expected race phase $expected, but was $phase"
        }
    }

    companion object {
        const val DEFAULT_COUNTDOWN_SECONDS = 3f
    }
}
