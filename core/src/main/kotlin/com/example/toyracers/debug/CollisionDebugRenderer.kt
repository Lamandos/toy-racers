package com.example.toyracers.debug

import com.badlogic.gdx.graphics.Camera
import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.glutils.ShapeRenderer
import com.badlogic.gdx.utils.viewport.Viewport
import com.example.toyracers.car.CarState
import com.example.toyracers.track.Track
import com.example.toyracers.track.TrackCircle
import com.example.toyracers.track.TrackPolygon
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
        track.roadRegion?.let { road ->
            shapes.color = ROAD_EDGE_COLOR
            drawStadium(shapes, road.outer)
            drawStadium(shapes, road.inner)
        }
        shapes.color = ROAD_EDGE_COLOR
        track.roadOuter?.let { drawPolygon(shapes, it) }
        track.roadInner?.let { drawPolygon(shapes, it) }
        shapes.color = OBJECT_COLOR
        track.innerObstacles.forEach { drawRectangle(shapes, it) }
        track.collisionShapes.forEach { collisionShape ->
            when (collisionShape) {
                is TrackCircle -> shapes.circle(
                    collisionShape.center.x,
                    collisionShape.center.y,
                    collisionShape.radius,
                    CIRCLE_SEGMENTS,
                )
                is TrackPolygon -> drawPolygon(shapes, collisionShape)
            }
        }
        shapes.color = CAR_COLOR
        cars.forEach { shapes.circle(it.state.x, it.state.y, it.radius, CIRCLE_SEGMENTS) }
        shapes.end()
    }

    private fun drawPolygon(
        shapes: ShapeRenderer,
        polygon: TrackPolygon,
    ) {
        polygon.vertices.forEachIndexed { index, point ->
            val next = polygon.vertices[(index + 1) % polygon.vertices.size]
            shapes.line(point.x, point.y, next.x, next.y)
        }
    }

    private fun drawStadium(
        shapes: ShapeRenderer,
        stadium: com.example.toyracers.track.TrackStadium,
    ) {
        shapes.arc(
            stadium.leftCenterX,
            stadium.centerY,
            stadium.radius,
            90f,
            180f,
            ARC_SEGMENTS,
        )
        shapes.arc(
            stadium.rightCenterX,
            stadium.centerY,
            stadium.radius,
            -90f,
            180f,
            ARC_SEGMENTS,
        )
        shapes.line(
            stadium.leftCenterX,
            stadium.centerY + stadium.radius,
            stadium.rightCenterX,
            stadium.centerY + stadium.radius,
        )
        shapes.line(
            stadium.leftCenterX,
            stadium.centerY - stadium.radius,
            stadium.rightCenterX,
            stadium.centerY - stadium.radius,
        )
    }

    private fun drawRectangle(
        shapes: ShapeRenderer,
        rectangle: TrackRectangle,
    ) {
        shapes.rect(rectangle.x, rectangle.y, rectangle.width, rectangle.height)
    }

    private companion object {
        const val CIRCLE_SEGMENTS = 24
        const val ARC_SEGMENTS = 24
        val BOUNDARY_COLOR = Color(1f, 0.25f, 0.2f, 1f)
        val ROAD_EDGE_COLOR = Color(0.25f, 1f, 0.35f, 1f)
        val OBJECT_COLOR = Color(1f, 0.75f, 0.15f, 1f)
        val CAR_COLOR = Color(0.2f, 0.9f, 1f, 1f)
    }
}

data class DebugCar(
    val state: CarState,
    val radius: Float,
)
