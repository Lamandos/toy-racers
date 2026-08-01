package com.example.toyracers.race

import com.example.toyracers.car.CarPhysics
import com.example.toyracers.car.CarModel
import com.example.toyracers.car.opponentModelsFor
import com.example.toyracers.input.PlayerInput
import com.example.toyracers.track.TrackLoader
import com.example.toyracers.track.TrackId
import com.example.toyracers.track.SurfaceType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RaceSessionTest {
    @Test
    fun `race uses four opponents for the five car roster`() {
        assertEquals(4, racingSession().opponents.size)
    }

    @Test
    fun `player and AI participants receive their own model performance`() {
        val playerModel = CarModel.YELLOW_SPORT
        val opponents = opponentModelsFor(playerModel)
        val session = RaceSession(
            track = TrackLoader().load(),
            playerCarModel = playerModel,
            opponentCarModels = opponents,
        )

        assertEquals(
            playerModel.performance.applyTo(),
            session.player.carConfig,
        )
        assertEquals(playerModel, session.player.carModel)
        session.opponents.forEachIndexed { index, opponent ->
            assertEquals(opponents[index].performance.applyTo(), opponent.carConfig)
            assertEquals(opponents[index], opponent.carModel)
        }
    }

    @Test
    fun `one session step updates player and AI through the shared pipeline`() {
        val session = racingSession()
        val playerStartX = session.player.state.x
        val opponentStartX = session.opponents.first().state.x

        session.advance(
            CarPhysics.FIXED_DELTA_SECONDS,
            PlayerInput(throttle = 1f),
        )

        assertTrue(session.player.state.x > playerStartX)
        assertTrue(session.opponents.first().state.x > opponentStartX)
        assertTrue(session.player.progress.totalRaceTime > 0f)
        assertTrue(session.opponents.first().progress.totalRaceTime > 0f)
    }

    @Test
    fun `shared pipeline applies track collision to every participant`() {
        val session = racingSession(withoutObjects = true)
        session.player.state.x = -10f
        session.player.state.y = 36f
        session.opponents.first().state.x = -10f
        session.opponents.first().state.y = 45f

        session.advance(CarPhysics.FIXED_DELTA_SECONDS, PlayerInput.NONE)

        val minimumCoordinate = session.player.carConfig.collisionRadius
        assertTrue(session.player.state.x >= minimumCoordinate)
        assertTrue(session.opponents.first().state.x >= minimumCoordinate)
    }

    @Test
    fun `paused session does not advance participants or race time`() {
        val session = racingSession()
        session.advance(CarPhysics.FIXED_DELTA_SECONDS, PlayerInput(throttle = 1f))
        session.pause()
        val playerX = session.player.state.x
        val raceTime = session.player.progress.totalRaceTime

        session.advance(1f, PlayerInput(throttle = 1f))

        assertEquals(playerX, session.player.state.x, TOLERANCE)
        assertEquals(raceTime, session.player.progress.totalRaceTime, TOLERANCE)
        assertEquals(RacePhase.PAUSED, session.raceState.phase)
    }

    @Test
    fun `bathroom AI follows its racing line on asphalt`() {
        val track = TrackLoader().load(TrackId.BATHROOM)
        val session = RaceSession(track).apply {
            start()
            advance(raceState.countdownDurationSeconds, PlayerInput.NONE)
        }
        val opponent = session.opponents.first()
        val startX = opponent.state.x
        val startY = opponent.state.y

        session.advance(120f, PlayerInput.NONE)

        val movementSquared =
            (opponent.state.x - startX) * (opponent.state.x - startX) +
                (opponent.state.y - startY) * (opponent.state.y - startY)
        assertTrue(movementSquared > 1f)
        assertEquals(
            SurfaceType.ASPHALT,
            track.surfaceAt(opponent.state.x, opponent.state.y),
        )
        assertTrue(
            opponent.progress.completedLaps > 0 ||
                opponent.progress.currentCheckpointIndex > 0,
        )
    }

    private fun racingSession(withoutObjects: Boolean = false): RaceSession {
        val loadedTrack = TrackLoader().load()
        val track = if (withoutObjects) {
            loadedTrack.copy(collisionShapes = emptyList())
        } else {
            loadedTrack
        }
        return RaceSession(track).apply {
            start()
            advance(raceState.countdownDurationSeconds, PlayerInput.NONE)
        }
    }

    private companion object {
        const val TOLERANCE = 0.0001f
    }
}
