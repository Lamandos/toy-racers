package com.example.toyracers.camera

import com.badlogic.gdx.graphics.OrthographicCamera
import com.example.toyracers.car.CarState
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.hypot
import kotlin.math.sin

/**
 * Positions a race camera from simulation state without changing the simulation.
 *
 * Bounds describe the complete drawable world. The camera's visible extents are
 * kept inside them, including while shake is active.
 */
class RaceCameraController internal constructor(
    private val camera: RaceCameraView,
    private val bounds: CameraBounds,
    private val config: RaceCameraConfig = RaceCameraConfig(),
) {
    constructor(
        camera: OrthographicCamera,
        bounds: CameraBounds,
        config: RaceCameraConfig = RaceCameraConfig(),
    ) : this(LibGdxRaceCameraView(camera), bounds, config)

    private var centerX = 0f
    private var centerY = 0f
    private var shakeAmount = 0f
    private var shakeTime = 0f

    init {
        require(bounds.width > 0f) { "Camera bounds width must be positive" }
        require(bounds.height > 0f) { "Camera bounds height must be positive" }
        camera.zoom = config.zoom
    }

    fun snapTo(target: CarState) {
        val targetPosition = calculateTarget(target)
        centerX = clampX(targetPosition.x)
        centerY = clampY(targetPosition.y)
        shakeAmount = 0f
        shakeTime = 0f
        applyCameraPosition(0f, 0f)
    }

    fun update(
        target: CarState,
        deltaSeconds: Float,
    ) {
        if (deltaSeconds <= 0f) return

        val targetPosition = calculateTarget(target)
        val followAlpha = 1f - exp(-config.followSpeed * deltaSeconds)
        centerX += (clampX(targetPosition.x) - centerX) * followAlpha
        centerY += (clampY(targetPosition.y) - centerY) * followAlpha

        shakeTime += deltaSeconds
        shakeAmount *= exp(-config.shakeDecaySpeed * deltaSeconds)
        if (shakeAmount < MIN_SHAKE_AMOUNT) {
            shakeAmount = 0f
        }

        val shakeX = sin(shakeTime * SHAKE_X_FREQUENCY) * shakeAmount
        val shakeY = cos(shakeTime * SHAKE_Y_FREQUENCY) * shakeAmount
        applyCameraPosition(shakeX, shakeY)
    }

    /** Adds an impulse in world units; repeated impacts accumulate up to [maxAmount]. */
    fun addShake(
        amount: Float,
        maxAmount: Float = DEFAULT_MAX_SHAKE,
    ) {
        require(amount >= 0f) { "Shake amount must not be negative" }
        require(maxAmount >= 0f) { "Maximum shake amount must not be negative" }
        shakeAmount = (shakeAmount + amount).coerceAtMost(maxAmount)
    }

    internal fun currentShakeAmount(): Float = shakeAmount

    private fun calculateTarget(target: CarState): CameraTarget {
        val speed = hypot(target.velocityX, target.velocityY)
        if (speed <= MIN_LOOK_AHEAD_SPEED) {
            return CameraTarget(target.x, target.y)
        }
        return CameraTarget(
            x = target.x + target.velocityX / speed * config.lookAheadDistance,
            y = target.y + target.velocityY / speed * config.lookAheadDistance,
        )
    }

    private fun applyCameraPosition(
        shakeX: Float,
        shakeY: Float,
    ) {
        camera.setPosition(clampX(centerX + shakeX), clampY(centerY + shakeY))
    }

    private fun clampX(value: Float): Float {
        val halfVisibleWidth = camera.viewportWidth * camera.zoom / 2f
        return clampAxis(value, bounds.minX, bounds.maxX, halfVisibleWidth)
    }

    private fun clampY(value: Float): Float {
        val halfVisibleHeight = camera.viewportHeight * camera.zoom / 2f
        return clampAxis(value, bounds.minY, bounds.maxY, halfVisibleHeight)
    }

    private fun clampAxis(
        value: Float,
        minimum: Float,
        maximum: Float,
        halfVisibleSize: Float,
    ): Float {
        if (halfVisibleSize * 2f >= maximum - minimum) {
            return (minimum + maximum) / 2f
        }
        return value.coerceIn(minimum + halfVisibleSize, maximum - halfVisibleSize)
    }

    private companion object {
        const val MIN_LOOK_AHEAD_SPEED = 0.01f
        const val MIN_SHAKE_AMOUNT = 0.001f
        const val DEFAULT_MAX_SHAKE = 1.25f
        val SHAKE_X_FREQUENCY = (17f * PI).toFloat()
        val SHAKE_Y_FREQUENCY = (23f * PI).toFloat()
    }
}

internal interface RaceCameraView {
    val viewportWidth: Float
    val viewportHeight: Float
    var zoom: Float

    fun setPosition(
        x: Float,
        y: Float,
    )
}

private class LibGdxRaceCameraView(
    private val camera: OrthographicCamera,
) : RaceCameraView {
    override val viewportWidth: Float
        get() = camera.viewportWidth
    override val viewportHeight: Float
        get() = camera.viewportHeight
    override var zoom: Float
        get() = camera.zoom
        set(value) {
            camera.zoom = value
        }

    override fun setPosition(
        x: Float,
        y: Float,
    ) {
        camera.position.set(x, y, 0f)
        camera.update()
    }
}

data class CameraBounds(
    val minX: Float,
    val minY: Float,
    val maxX: Float,
    val maxY: Float,
) {
    val width: Float
        get() = maxX - minX
    val height: Float
        get() = maxY - minY
}

private data class CameraTarget(
    val x: Float,
    val y: Float,
)
