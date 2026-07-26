package com.example.toyracers.debug

import com.badlogic.gdx.graphics.Camera
import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.glutils.ShapeRenderer
import com.badlogic.gdx.utils.viewport.Viewport
import com.example.toyracers.car.CarState
import com.example.toyracers.track.Track
import com.example.toyracers.track.TrackRectangle

/** Optional wireframe view of collision shapes. */
class CollisionDebugRenderer {
    fun render(
        viewport: Viewport,
        camera: Camera,
        shapes: ShapeRenderer,
        track: Track,
        cars: List<DebugCar>,
    ) {
        viewport.apply()
        camera.update()
        shapes.projectionMatrix = camera.combined
        shapes.begin(ShapeRenderer.ShapeType.Line)
        shapes.color = BOUNDARY_COLOR
        drawRectangle(shapes, track.worldBounds)
        shapes.color = CAR_COLOR
        cars.forEach { shapes.circle(it.state.x, it.state.y, it.radius, CIRCLE_SEGMENTS) }
        shapes.end()
    }

    private fun drawRectangle(
        shapes: ShapeRenderer,
        rectangle: TrackRectangle,
    ) {
        shapes.rect(rectangle.x, rectangle.y, rectangle.width, rectangle.height)
    }

    private companion object {
        const val CIRCLE_SEGMENTS = 24
        val BOUNDARY_COLOR = Color(1f, 0.25f, 0.2f, 1f)
        val CAR_COLOR = Color(0.2f, 0.9f, 1f, 1f)
    }
}

data class DebugCar(
    val state: CarState,
    val radius: Float,
)
