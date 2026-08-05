package com.example.toyracers.ai

import com.example.toyracers.car.CarConfig
import com.example.toyracers.car.CarPhysics
import com.example.toyracers.car.CarState
import com.example.toyracers.collision.CollisionSystem
import com.example.toyracers.input.PlayerInput
import com.example.toyracers.race.RaceProgress
import com.example.toyracers.race.RaceRules
import com.example.toyracers.track.TrackPoint
import com.example.toyracers.track.TrackLoader
import com.example.toyracers.track.TrackId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class AiDriverTest {
    @Test
    fun `invalid racing line reports validation error before creating path follower`() {
        val error = assertThrows(IllegalArgumentException::class.java) {
            AiDriver(emptyList(), initialPosition = TrackPoint(0f, 0f))
        }

        assertEquals("Racing line must contain at least 3 points", error.message)
    }

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
    fun `slow obstacle ahead triggers deterministic overtake away from obstacle`() {
        val driver = driverForTarget(TrackPoint(10f, 0f))
        val car = CarState(rotationDeg = 0f, speed = 8f)

        val input = driver.update(
            carState = car,
            deltaSeconds = FIXED_DELTA,
            obstacles = listOf(AiObstacle(x = 4f, y = 0.5f, radius = 0.5f, speed = 3f)),
        )

        assertEquals(AiBehaviorState.OVERTAKE, driver.behaviorState)
        assertTrue(input.steering > 0f)
        assertEquals(AiBehaviorState.OVERTAKE, driver.debugSnapshot?.behaviorState)
    }

    @Test
    fun `overtake selects the only passing corridor clear of other cars`() {
        val driver = driverForTarget(TrackPoint(10f, 0f))
        val input = driver.update(
            carState = CarState(rotationDeg = 0f, speed = 8f),
            deltaSeconds = FIXED_DELTA,
            obstacles = listOf(
                AiObstacle(x = 4f, y = 0.5f, radius = 0.5f, speed = 3f),
                AiObstacle(x = 3f, y = -2f, radius = 0.5f, speed = 8f),
            ),
        )

        assertEquals(AiBehaviorState.OVERTAKE, driver.behaviorState)
        assertTrue("AI must use the clear left corridor", input.steering < 0f)
    }

    @Test
    fun `blocked passing corridors prevent unsafe overtake`() {
        val driver = driverForTarget(TrackPoint(10f, 0f))
        val input = driver.update(
            carState = CarState(rotationDeg = 0f, speed = 8f),
            deltaSeconds = FIXED_DELTA,
            obstacles = listOf(
                AiObstacle(x = 4f, y = 0f, radius = 0.5f, speed = 3f),
                AiObstacle(x = 2f, y = 2f, radius = 0.5f, speed = 8f),
                AiObstacle(x = 2f, y = -2f, radius = 0.5f, speed = 8f),
            ),
        )

        assertEquals(AiBehaviorState.AVOID, driver.behaviorState)
        assertEquals(0f, input.steering, TOLERANCE)
        assertEquals(1f, input.brake, TOLERANCE)
    }

    @Test
    fun `nearby obstacle outside lane does not alter route behavior`() {
        val driver = driverForTarget(TrackPoint(10f, 0f))

        driver.update(
            carState = CarState(rotationDeg = 0f, speed = 8f),
            deltaSeconds = FIXED_DELTA,
            obstacles = listOf(AiObstacle(x = 3f, y = 5f, radius = 0.5f)),
        )

        assertEquals(AiBehaviorState.FOLLOW_ROUTE, driver.behaviorState)
    }

    @Test
    fun `finished driver brakes and enters finished state`() {
        val driver = driverForTarget(TrackPoint(10f, 0f))

        val input = driver.update(CarState(speed = 8f), FIXED_DELTA, finished = true)

        assertEquals(AiBehaviorState.FINISHED, driver.behaviorState)
        assertEquals(0f, input.throttle, TOLERANCE)
        assertEquals(1f, input.brake, TOLERANCE)
    }

    @Test
    fun `finished driver releases brake after stopping`() {
        val driver = driverForTarget(TrackPoint(10f, 0f))

        val input = driver.update(CarState(speed = 0f), FIXED_DELTA, finished = true)

        assertEquals(AiBehaviorState.FINISHED, driver.behaviorState)
        assertEquals(PlayerInput.NONE, input)
    }

    @Test
    fun `difficulty profiles have visibly different speed and reaction settings`() {
        val base = AiConfig()
        val easy = base.forDifficulty(AiDifficulty.EASY)
        val hard = base.forDifficulty(AiDifficulty.HARD)

        assertTrue(easy.straightSpeed < base.straightSpeed)
        assertTrue(easy.steeringResponse < base.steeringResponse)
        assertTrue(hard.straightSpeed > base.straightSpeed)
        assertTrue(hard.obstacleDetectionDistance > base.obstacleDetectionDistance)
        assertTrue(easy.mistakeProbability > hard.mistakeProbability)
    }

    @Test
    fun `difficulty profiles preserve tuned config invariants`() {
        val tuned = AiConfig(
            straightSpeed = 10f,
            cornerSpeed = 10f,
            obstacleDetectionDistance = 1f,
            staticObstacleReactionDistance = 1f,
            overtakeMinimumClearance = 1f,
            sensorRayStep = 1f,
        )

        AiDifficulty.entries.forEach { difficulty ->
            val adjusted = tuned.forDifficulty(difficulty)

            assertTrue(
                "$difficulty corner speed exceeds straight speed: $adjusted",
                adjusted.cornerSpeed <= adjusted.straightSpeed,
            )
            assertTrue(
                "$difficulty reaction distance is outside sensor range: $adjusted",
                adjusted.staticObstacleReactionDistance in
                    adjusted.sensorRayStep..adjusted.obstacleDetectionDistance,
            )
        }
    }

    @Test
    fun `track sensor rays detect the world boundary`() {
        val track = TrackLoader().load()
        val detector = AiObstacleDetector(AiConfig(obstacleDetectionDistance = 5f))
        val car = CarState(
            x = track.worldBounds.maxX - 1f,
            y = track.worldBounds.y + track.worldBounds.height / 2f,
            rotationDeg = 0f,
        )

        val rays = detector.scanTrack(car, track)

        assertEquals(3, rays.size)
        assertTrue(rays.any(AiSensorRay::hit))
    }

    @Test
    fun `driver reacts to a track boundary before immediate collision range`() {
        val track = TrackLoader().load()
        val position = TrackPoint(
            x = track.worldBounds.maxX - 4f,
            y = track.worldBounds.y + track.worldBounds.height / 2f,
        )
        val driver = AiDriver(
            racingLine = listOf(
                TrackPoint(position.x - 10f, position.y),
                position,
                TrackPoint(position.x + 10f, position.y),
            ),
            initialPosition = position,
            track = track,
        )

        val input = driver.update(
            CarState(x = position.x, y = position.y, rotationDeg = 0f, speed = 8f),
            FIXED_DELTA,
        )

        assertEquals(AiBehaviorState.AVOID, driver.behaviorState)
        assertTrue(kotlin.math.abs(input.steering) > 0f)
        assertTrue(driver.debugSnapshot?.sensorRays?.any(AiSensorRay::hit) == true)
    }

    @Test
    fun `off track driver requests safe respawn without changing car coordinates`() {
        val driver = AiDriver(
            racingLine = testLine(TrackPoint(10f, 0f)),
            initialPosition = TrackPoint(0f, 0f),
            config = AiConfig(offTrackDurationSeconds = 0.1f),
        )
        val car = CarState(x = 100f, y = 100f, speed = 5f)

        driver.update(car, 0.1f, isOnTrack = false)

        assertTrue(driver.consumeRespawnRequest())
        assertEquals(100f, car.x, TOLERANCE)
        assertEquals(100f, car.y, TOLERANCE)
    }

    @Test
    fun `all AI grid positions complete a valid lap on built in track`() {
        TrackId.entries.forEach { trackId ->
            val track = TrackLoader().load(trackId)
            AiDifficulty.entries.forEach { difficulty ->
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
                        difficulty = difficulty,
                    )
                    val physics = CarPhysics()
                    val carConfig = CarConfig()
                    val collisions = CollisionSystem()
                    val rules = RaceRules(track, requiredLaps = 1)
                    val progress = RaceProgress()

                    repeat(MAX_LAP_SIMULATION_STEPS) {
                        if (progress.finished) return@repeat
                        val previous = TrackPoint(state.x, state.y)
                        physics.update(
                            state,
                            carConfig,
                            driver.update(state, FIXED_DELTA),
                            FIXED_DELTA,
                        )
                        collisions.resolveTrackCollision(state, carConfig.collisionRadius, track)
                        rules.update(progress, previous, TrackPoint(state.x, state.y), FIXED_DELTA)
                    }

                    assertTrue(
                        "$difficulty AI from $start did not complete a valid lap: " +
                            "state=$state progress=$progress waypoint=${driver.targetWaypointIndex}",
                        progress.finished,
                    )
                }
            }
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
        const val MAX_LAP_SIMULATION_STEPS = 60 * 120
        const val TOLERANCE = 0.001f
    }
}
