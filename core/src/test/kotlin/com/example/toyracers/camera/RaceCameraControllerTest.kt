package com.example.toyracers.camera

import com.example.toyracers.car.CarState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RaceCameraControllerTest {
    @Test
    fun `snap uses velocity direction for look ahead`() {
        val camera = camera()
        val controller = controller(camera)

        controller.snapTo(
            CarState(
                x = 20f,
                y = 12f,
                velocityX = 3f,
                velocityY = 4f,
            ),
        )

        assertEquals(22.4f, camera.x, TOLERANCE)
        assertEquals(15.2f, camera.y, TOLERANCE)
    }

    @Test
    fun `follow approaches target without snapping`() {
        val camera = camera()
        val controller = controller(camera)
        val car = CarState(x = 10f, y = 10f)
        controller.snapTo(car)
        car.x = 30f

        controller.update(car, 1f / 60f)

        assertTrue(camera.x > 10f)
        assertTrue(camera.x < 30f)
    }

    @Test
    fun `camera remains inside world bounds`() {
        val camera = camera()
        val controller = controller(camera)

        controller.snapTo(CarState(x = 0f, y = 0f))
        assertEquals(5f, camera.x, TOLERANCE)
        assertEquals(4f, camera.y, TOLERANCE)

        controller.snapTo(CarState(x = 40f, y = 30f))
        assertEquals(35f, camera.x, TOLERANCE)
        assertEquals(26f, camera.y, TOLERANCE)
    }

    @Test
    fun `shake decays quickly and never leaves world bounds`() {
        val camera = camera()
        val controller = controller(camera)
        val car = CarState(x = 0f, y = 0f)
        controller.snapTo(car)
        controller.addShake(1f)

        repeat(60) {
            controller.update(car, 1f / 60f)
            assertTrue(camera.x >= 5f)
            assertTrue(camera.y >= 4f)
        }

        assertTrue(controller.currentShakeAmount() < 0.001f)
    }

    private fun camera(): FakeCamera = FakeCamera()

    private fun controller(camera: FakeCamera): RaceCameraController =
        RaceCameraController(
            camera = camera,
            bounds = CameraBounds(0f, 0f, 40f, 30f),
            config =
                RaceCameraConfig(
                    followSpeed = 5f,
                    lookAheadDistance = 4f,
                    zoom = 1f,
                    shakeDecaySpeed = 12f,
                ),
        )

    private companion object {
        const val TOLERANCE = 0.0001f
    }

    private class FakeCamera : RaceCameraView {
        override val viewportWidth = 10f
        override val viewportHeight = 8f
        override var zoom = 1f
        var x = 0f
        var y = 0f

        override fun setPosition(
            x: Float,
            y: Float,
        ) {
            this.x = x
            this.y = y
        }
    }
}
