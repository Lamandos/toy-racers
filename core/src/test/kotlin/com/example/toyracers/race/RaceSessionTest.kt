package com.example.toyracers.race

import com.example.toyracers.ai.AiConfig
import com.example.toyracers.ai.AiDifficulty
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
    fun `race supports five simultaneous AI opponents`() {
        assertEquals(5, racingSession().opponents.size)
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
    fun `selected difficulty is applied to every opponent`() {
        val session = RaceSession(
            track = TrackLoader().load(),
            opponentDifficulty = AiDifficulty.HARD,
        )

        assertTrue(session.opponents.isNotEmpty())
        session.opponents.forEach { opponent ->
            assertEquals(AiDifficulty.HARD, opponent.driver?.difficulty)
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
    fun `finished race renders the state produced by the finishing step`() {
        val track = TrackLoader().load().copy(collisionShapes = emptyList())
        val session = RaceSession(track).apply {
            start()
            advance(raceState.countdownDurationSeconds, PlayerInput.NONE)
        }
        val startLineCenterX = track.startLine.bounds.x + track.startLine.bounds.width / 2f
        val startLineCenterY = track.startLine.bounds.y + track.startLine.bounds.height / 2f
        session.player.progress.currentCheckpointIndex = track.checkpoints.size
        session.player.progress.completedLaps = RaceRules.DEFAULT_LAP_COUNT - 1
        session.player.state.x = startLineCenterX - 0.1f
        session.player.state.y = startLineCenterY
        session.player.state.speed = 10f
        session.player.state.velocityX = 10f

        session.advance(CarPhysics.FIXED_DELTA_SECONDS, PlayerInput.NONE)

        assertEquals(RacePhase.FINISHED, session.raceState.phase)
        val renderedState = session.renderStateOf(session.player)
        assertEquals(session.player.state.x, renderedState.x, TOLERANCE)
        assertEquals(session.player.state.y, renderedState.y, TOLERANCE)
        assertEquals(session.player.state.rotationDeg, renderedState.rotationDeg, TOLERANCE)
        assertEquals(session.player.state.speed, renderedState.speed, TOLERANCE)
        assertEquals(session.player.state.velocityX, renderedState.velocityX, TOLERANCE)
        assertEquals(session.player.state.velocityY, renderedState.velocityY, TOLERANCE)
        assertEquals(session.player.state.angularVelocity, renderedState.angularVelocity, TOLERANCE)
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
    fun `AI driving the wrong way does not overwrite its last safe state`() {
        val session = racingSession(withoutObjects = true)
        val opponent = session.opponents.first()
        val lastSafeState = opponent.lastSafeState.copy()
        opponent.state.rotationDeg += 180f
        opponent.state.speed = 3f

        session.advance(CarPhysics.FIXED_DELTA_SECONDS, PlayerInput.NONE)

        assertEquals(lastSafeState, opponent.lastSafeState)
    }

    @Test
    fun `AI respawn clears off-road speed reduction and drift state`() {
        val session = RaceSession(
            track = TrackLoader().load().copy(collisionShapes = emptyList()),
            aiConfig = AiConfig(offTrackDurationSeconds = CarPhysics.FIXED_DELTA_SECONDS),
        ).apply {
            start()
            advance(raceState.countdownDurationSeconds, PlayerInput.NONE)
        }
        val opponent = session.opponents.first()
        val safeState = opponent.lastSafeState.copy()
        opponent.state.x = -10f
        opponent.state.y = -10f
        opponent.state.lateralSpeed = 8f
        opponent.state.driftAmount = 0.75f
        opponent.surfaceSpeedState.speedMultiplier = 0.3f

        session.advance(CarPhysics.FIXED_DELTA_SECONDS, PlayerInput.NONE)

        assertEquals(safeState.x, opponent.state.x, TOLERANCE)
        assertEquals(safeState.y, opponent.state.y, TOLERANCE)
        assertEquals(1f, opponent.surfaceSpeedState.speedMultiplier, TOLERANCE)
        assertEquals(0f, opponent.state.lateralSpeed, TOLERANCE)
        assertEquals(0f, opponent.state.driftAmount, TOLERANCE)
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
        repeat(180) {
            if (track.surfaceAt(opponent.state.x, opponent.state.y) != SurfaceType.ASPHALT) {
                session.advance(CarPhysics.FIXED_DELTA_SECONDS, PlayerInput.NONE)
            }
        }

        val movementSquared =
            (opponent.state.x - startX) * (opponent.state.x - startX) +
                (opponent.state.y - startY) * (opponent.state.y - startY)
        assertTrue(movementSquared > 1f)
        assertEquals(
            SurfaceType.ASPHALT,
            track.surfaceAt(opponent.state.x, opponent.state.y),
        )
        assertTrue(
            "AI did not advance: state=${opponent.state}, progress=${opponent.progress}, " +
                "behavior=${opponent.driver?.behaviorState}",
            opponent.progress.completedLaps > 0 ||
                opponent.progress.currentCheckpointIndex > 0,
        )
    }

    @Test
    fun `five AI remain within real time simulation budget`() {
        val session = racingSession()
        val startedAt = System.nanoTime()

        session.advance(10f, PlayerInput.NONE)

        val elapsedSeconds = (System.nanoTime() - startedAt) / 1_000_000_000.0
        assertTrue("10 simulated seconds took $elapsedSeconds real seconds", elapsedSeconds < 5.0)
        assertEquals(5, session.opponents.size)
    }

    @Test
    fun `five interacting AI complete a valid lap on every built in track`() {
        TrackId.entries.forEach { trackId ->
            val session = RaceSession(TrackLoader().load(trackId)).apply {
                start()
                advance(raceState.countdownDurationSeconds, PlayerInput.NONE)
            }

            session.advance(MAX_RACE_SIMULATION_SECONDS, PlayerInput.NONE)

            session.opponents.forEach { opponent ->
                assertTrue(
                    "$trackId ${opponent.id} did not finish: state=${opponent.state}, " +
                        "progress=${opponent.progress}, behavior=${opponent.driver?.behaviorState}",
                    opponent.progress.finished,
                )
            }
        }
    }

    @Test
    fun `fixed simulation produces the same result for different frame rates`() {
        val sixtyFps = racingSession()
        val fifteenFps = racingSession()

        repeat(12) {
            sixtyFps.advance(CarPhysics.FIXED_DELTA_SECONDS, PlayerInput(throttle = 1f))
        }
        repeat(3) {
            fifteenFps.advance(CarPhysics.FIXED_DELTA_SECONDS * 4f, PlayerInput(throttle = 1f))
        }

        (listOf(sixtyFps.player) + sixtyFps.opponents).zip(
            listOf(fifteenFps.player) + fifteenFps.opponents,
        ).forEach { (first, second) ->
            assertEquals(first.state.x, second.state.x, TOLERANCE)
            assertEquals(first.state.y, second.state.y, TOLERANCE)
            assertEquals(first.state.rotationDeg, second.state.rotationDeg, TOLERANCE)
            assertEquals(first.state.speed, second.state.speed, TOLERANCE)
            assertEquals(first.progress, second.progress)
        }
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
        const val MAX_RACE_SIMULATION_SECONDS = 240f
        const val TOLERANCE = 0.0001f
    }
}
