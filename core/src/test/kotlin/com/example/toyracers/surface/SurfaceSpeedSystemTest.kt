package com.example.toyracers.surface

import com.example.toyracers.car.CarConfig
import com.example.toyracers.car.CarState
import com.example.toyracers.track.SurfaceType
import org.junit.Assert.assertEquals
import org.junit.Test
import kotlin.math.roundToInt

class SurfaceSpeedSystemTest {
    private val system = SurfaceSpeedSystem()
    private val carConfig = CarConfig()

    @Test
    fun `off road slowdown reaches thirty percent in three seconds`() {
        val car = CarState(velocityX = carConfig.maxForwardSpeed, speed = carConfig.maxForwardSpeed)
        val surfaceState = SurfaceSpeedState()

        simulate(car, surfaceState, SurfaceType.GRASS, seconds = 1.5f)
        assertEquals(0.65f, surfaceState.speedMultiplier, TOLERANCE)
        assertEquals(carConfig.maxForwardSpeed * 0.65f, car.speed, TOLERANCE)

        simulate(car, surfaceState, SurfaceType.GRASS, seconds = 1.5f)
        assertEquals(0.3f, surfaceState.speedMultiplier, TOLERANCE)
        assertEquals(carConfig.maxForwardSpeed * 0.3f, car.speed, TOLERANCE)
    }

    @Test
    fun `road recovery reaches full speed allowance in three seconds`() {
        val car = CarState()
        val surfaceState = SurfaceSpeedState(speedMultiplier = 0.3f)

        simulate(car, surfaceState, SurfaceType.ASPHALT, seconds = 1.5f)
        assertEquals(0.65f, surfaceState.speedMultiplier, TOLERANCE)

        simulate(car, surfaceState, SurfaceType.ASPHALT, seconds = 1.5f)
        assertEquals(1f, surfaceState.speedMultiplier, TOLERANCE)
    }

    @Test
    fun `slowdown is gradual rather than immediate`() {
        val car = CarState(velocityX = carConfig.maxForwardSpeed, speed = carConfig.maxForwardSpeed)
        val surfaceState = SurfaceSpeedState()

        system.update(
            car,
            carConfig,
            surfaceState,
            SurfaceType.GRASS,
            deltaSeconds = 1f,
        )

        assertEquals(0.7667f, surfaceState.speedMultiplier, TOLERANCE)
        assertEquals(carConfig.maxForwardSpeed * 0.7667f, car.speed, SPEED_TOLERANCE)
    }

    @Test
    fun `off road reverse speed uses the same multiplier`() {
        val car = CarState(
            velocityX = -carConfig.maxReverseSpeed,
            speed = -carConfig.maxReverseSpeed,
        )
        val surfaceState = SurfaceSpeedState(speedMultiplier = 0.3f)

        system.update(car, carConfig, surfaceState, SurfaceType.GRASS, 1f / 60f)

        assertEquals(-carConfig.maxReverseSpeed * 0.3f, car.speed, TOLERANCE)
    }

    @Test
    fun `non grass road surfaces do not apply off road slowdown`() {
        listOf(SurfaceType.ASPHALT, SurfaceType.BOOST, SurfaceType.OIL).forEach { surface ->
            val car = CarState()
            val surfaceState = SurfaceSpeedState()

            system.update(car, carConfig, surfaceState, surface, 1f)

            assertEquals(1f, surfaceState.speedMultiplier, TOLERANCE)
        }
    }

    private fun simulate(
        car: CarState,
        surfaceState: SurfaceSpeedState,
        surface: SurfaceType,
        seconds: Float,
    ) {
        val steps = (seconds / FIXED_DELTA_SECONDS).roundToInt()
        repeat(steps) {
            system.update(car, carConfig, surfaceState, surface, FIXED_DELTA_SECONDS)
        }
    }

    private companion object {
        const val FIXED_DELTA_SECONDS = 1f / 60f
        const val TOLERANCE = 0.001f
        const val SPEED_TOLERANCE = 0.01f
    }
}
