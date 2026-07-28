package com.example.toyracers.ai

import com.example.toyracers.car.CarConfig
import com.example.toyracers.car.CarPhysics
import com.example.toyracers.car.CarState
import com.example.toyracers.collision.CollisionSystem
import com.example.toyracers.race.RaceProgress
import com.example.toyracers.race.RaceRules
import com.example.toyracers.track.TrackPoint
import com.example.toyracers.track.TrackLoader
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AiDriverTest {
    @Test
    fun `driver steers toward waypoint using player input convention`() {
        val leftDriver = driverForTarget(TrackPoint(10f, 10f))
        val rightDriver = driverForTarget(TrackPoint(10f, -10f))
        val car = CarState(rotationDeg = 0f, speed = 8f)

        val leftInput = leftDriver.update(car, FIXED_DELTA)
        val rightInput = rightDriver.update(car, FIXED_DELTA)

        assertTrue(leftInput.steering < 0f)
        assertTrue(rightInput.steering > 0f)
    }

    @Test
    fun `sharp turn reduces target speed and applies brake`() {
        val driver = driverForTarget(TrackPoint(0f, 10f))
        val car = CarState(rotationDeg = 0f, speed = 30f)

        val input = driver.update(car, FIXED_DELTA)

        assertEquals(0f, input.throttle, TOLERANCE)
        assertEquals(1f, input.brake, TOLERANCE)
        assertEquals(-1f, input.steering, TOLERANCE)
    }

    @Test
    fun `reaching target advances to following waypoint`() {
        val line = listOf(
            TrackPoint(0f, 0f),
            TrackPoint(10f, 0f),
            TrackPoint(10f, 10f),
        )
        val driver = AiDriver(line, initialPosition = TrackPoint(0f, 0f))
        assertEquals(1, driver.targetWaypointIndex)

        driver.update(CarState(x = 10f, y = 0f, speed = 5f), FIXED_DELTA)

        assertEquals(2, driver.targetWaypointIndex)
    }

    @Test
    fun `stationary car enters deterministic reverse recovery`() {
        val config = AiConfig(stuckDurationSeconds = 0.5f)
        val driver = AiDriver(
            racingLine = testLine(TrackPoint(10f, 0f)),
            initialPosition = TrackPoint(0f, 0f),
            config = config,
        )
        val car = CarState()

        driver.update(car, 0.25f)
        val recoveryInput = driver.update(car, 0.25f)

        assertEquals(0f, recoveryInput.throttle, TOLERANCE)
        assertEquals(1f, recoveryInput.brake, TOLERANCE)
    }

    @Test
    fun `same state sequence produces identical decisions`() {
        val first = driverForTarget(TrackPoint(10f, 4f))
        val second = driverForTarget(TrackPoint(10f, 4f))
        val car = CarState(speed = 12f)

        repeat(180) {
            assertEquals(first.update(car, FIXED_DELTA), second.update(car, FIXED_DELTA))
        }
    }

    @Test
    fun `all AI grid positions complete a valid lap on built in track`() {
        val track = TrackLoader().load()
        track.startGrid.drop(1).forEach { start ->
            val state = CarState(
                x = start.position.x,
                y = start.position.y,
                rotationDeg = start.rotationDeg,
            )
            val driver = AiDriver(
                track.racingLine,
                start.position,
                AiConfig(waypointRadius = track.racingLineWaypointRadius),
            )
            val physics = CarPhysics()
            val carConfig = CarConfig()
            val collisions = CollisionSystem()
            val rules = RaceRules(track, requiredLaps = 1)
            val progress = RaceProgress()

            repeat(MAX_LAP_SIMULATION_STEPS) {
                if (progress.finished) return@repeat
                val previous = TrackPoint(state.x, state.y)
                physics.update(state, carConfig, driver.update(state, FIXED_DELTA), FIXED_DELTA)
                collisions.resolveTrackCollision(state, carConfig.collisionRadius, track)
                rules.update(progress, previous, TrackPoint(state.x, state.y), FIXED_DELTA)
            }

            assertTrue(
                "AI from $start did not complete a valid lap: state=$state progress=$progress " +
                    "waypoint=${driver.targetWaypointIndex}",
                progress.finished,
            )
        }
    }

    @Test(expected = IllegalArgumentException::class)
    fun `negative delta is rejected`() {
        driverForTarget(TrackPoint(10f, 0f)).update(CarState(), -FIXED_DELTA)
    }

    private fun driverForTarget(target: TrackPoint): AiDriver =
        AiDriver(
            racingLine = testLine(target),
            initialPosition = TrackPoint(0f, 0f),
        )

    private fun testLine(target: TrackPoint): List<TrackPoint> = listOf(
        TrackPoint(-10f, -10f),
        TrackPoint(0f, 0f),
        target,
        TrackPoint(-10f, 10f),
    )

    private companion object {
        const val FIXED_DELTA = 1f / 60f
        const val MAX_LAP_SIMULATION_STEPS = 60 * 60
        const val TOLERANCE = 0.001f
    }
}
