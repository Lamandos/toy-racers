package com.example.toyracers.surface

import com.example.toyracers.car.CarConfig
import com.example.toyracers.car.CarState
import com.example.toyracers.track.SurfaceType
import com.example.toyracers.track.TrackId
import com.example.toyracers.track.TrackLoader
import com.example.toyracers.track.TrackPoint
import org.junit.Assert.assertEquals
import org.junit.Test

class SurfaceScenarioTest {
    private val carConfig = CarConfig()
    private val trackLoader = TrackLoader()

    @Test
    fun `asphalt on both built in tracks keeps the full speed allowance`() {
        TrackId.entries.forEach { trackId ->
            val track = trackLoader.load(trackId)
            val car = fullSpeedCar()
            val surfaceState = SurfaceSpeedState()

            SurfaceSpeedSystem().update(
                car,
                carConfig,
                surfaceState,
                track.surfaceAt(track.startGrid.first().position),
                TRANSITION_SECONDS,
            )

            assertEquals(SurfaceType.ASPHALT, track.surfaceAt(track.startGrid.first().position))
            assertEquals(1f, surfaceState.speedMultiplier, TOLERANCE)
            assertEquals(carConfig.maxForwardSpeed, car.speed, TOLERANCE)
        }
    }

    @Test
    fun `parquet and tile apply the built in off road speed limit`() {
        listOf(
            TrackId.LIVING_ROOM to SurfaceType.PARQUET,
            TrackId.BATHROOM to SurfaceType.TILE,
        ).forEach { (trackId, expectedSurface) ->
            val track = trackLoader.load(trackId)
            val car = fullSpeedCar()
            val surfaceState = SurfaceSpeedState()
            val surface = track.surfaceAt(OFF_ROAD_SAMPLE)

            SurfaceSpeedSystem().update(
                car,
                carConfig,
                surfaceState,
                surface,
                TRANSITION_SECONDS,
            )

            assertEquals(expectedSurface, surface)
            assertEquals(OFF_ROAD_MULTIPLIER, surfaceState.speedMultiplier, TOLERANCE)
            assertEquals(carConfig.maxForwardSpeed * OFF_ROAD_MULTIPLIER, car.speed, TOLERANCE)
        }
    }

    @Test
    fun `asphalt to parquet transition reduces speed allowance gradually`() {
        val car = fullSpeedCar()
        val surfaceState = SurfaceSpeedState()
        val parquet = trackLoader.load(TrackId.LIVING_ROOM).surfaceAt(OFF_ROAD_SAMPLE)

        SurfaceSpeedSystem().update(car, carConfig, surfaceState, parquet, HALF_TRANSITION_SECONDS)

        assertEquals(SurfaceType.PARQUET, parquet)
        assertEquals(HALF_TRANSITION_MULTIPLIER, surfaceState.speedMultiplier, TOLERANCE)
        assertEquals(carConfig.maxForwardSpeed * HALF_TRANSITION_MULTIPLIER, car.speed, TOLERANCE)
    }

    @Test
    fun `parquet to asphalt transition restores the full speed allowance gradually`() {
        val car = fullSpeedCar()
        val surfaceState = SurfaceSpeedState(OFF_ROAD_MULTIPLIER)

        SurfaceSpeedSystem().update(
            car,
            carConfig,
            surfaceState,
            SurfaceType.ASPHALT,
            HALF_TRANSITION_SECONDS,
        )

        assertEquals(HALF_TRANSITION_MULTIPLIER, surfaceState.speedMultiplier, TOLERANCE)
        assertEquals(carConfig.maxForwardSpeed * HALF_TRANSITION_MULTIPLIER, car.speed, TOLERANCE)

        SurfaceSpeedSystem().update(
            car,
            carConfig,
            surfaceState,
            SurfaceType.ASPHALT,
            HALF_TRANSITION_SECONDS,
        )

        assertEquals(1f, surfaceState.speedMultiplier, TOLERANCE)
    }

    private fun fullSpeedCar(): CarState =
        CarState(
            velocityX = carConfig.maxForwardSpeed,
            speed = carConfig.maxForwardSpeed,
        )

    private companion object {
        const val TRANSITION_SECONDS = 3f
        const val HALF_TRANSITION_SECONDS = TRANSITION_SECONDS / 2f
        const val OFF_ROAD_MULTIPLIER = 0.3f
        const val HALF_TRANSITION_MULTIPLIER = 0.65f
        const val TOLERANCE = 0.001f
        val OFF_ROAD_SAMPLE = TrackPoint(3f, 3f)
    }
}
