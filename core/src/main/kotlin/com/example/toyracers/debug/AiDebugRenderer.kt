package com.example.toyracers.debug

import com.badlogic.gdx.graphics.Camera
import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.g2d.BitmapFont
import com.badlogic.gdx.graphics.g2d.SpriteBatch
import com.badlogic.gdx.graphics.glutils.ShapeRenderer
import com.badlogic.gdx.utils.Disposable
import com.badlogic.gdx.utils.viewport.Viewport
import com.example.toyracers.ai.AiDebugSnapshot
import com.example.toyracers.track.TrackPoint

/** Visual AI diagnostics: route, target, sensor rays, state, speed and commands. */
class AiDebugRenderer : Disposable {
    private val batch = SpriteBatch()
    private val font = BitmapFont().apply { data.setScale(TEXT_SCALE) }

    fun render(
        viewport: Viewport,
        camera: Camera,
        shapes: ShapeRenderer,
        racingLine: List<TrackPoint>,
        snapshots: List<AiDebugSnapshot>,
    ) {
        viewport.apply()
        camera.update()
        shapes.projectionMatrix = camera.combined
        shapes.begin(ShapeRenderer.ShapeType.Line)
        shapes.color = ROUTE_COLOR
        racingLine.forEachIndexed { index, point ->
            val next = racingLine[(index + 1) % racingLine.size]
            shapes.line(point.x, point.y, next.x, next.y)
        }
        snapshots.forEach { snapshot ->
            shapes.color = TARGET_COLOR
            shapes.line(snapshot.position.x, snapshot.position.y, snapshot.targetPoint.x, snapshot.targetPoint.y)
            shapes.circle(snapshot.targetPoint.x, snapshot.targetPoint.y, TARGET_RADIUS, 12)
            snapshot.sensorRays.forEach { ray ->
                shapes.color = if (ray.hit) HIT_RAY_COLOR else CLEAR_RAY_COLOR
                shapes.line(ray.start.x, ray.start.y, ray.end.x, ray.end.y)
            }
        }
        shapes.end()
        batch.projectionMatrix = camera.combined
        batch.begin()
        snapshots.forEach { snapshot ->
            val input = snapshot.input
            font.draw(
                batch,
                "${snapshot.behaviorState} v=${"%.1f".format(snapshot.speed)} " +
                    "T=${"%.1f".format(input.throttle)} B=${"%.1f".format(input.brake)} " +
                    "S=${"%.1f".format(input.steering)}",
                snapshot.position.x + TEXT_OFFSET,
                snapshot.position.y + TEXT_OFFSET,
            )
        }
        batch.end()
    }

    override fun dispose() {
        batch.dispose()
        font.dispose()
    }

    private companion object {
        const val TARGET_RADIUS = 0.3f
        const val TEXT_SCALE = 0.025f
        const val TEXT_OFFSET = 0.6f
        val ROUTE_COLOR = Color(0.2f, 0.8f, 1f, 0.65f)
        val TARGET_COLOR = Color(1f, 0.2f, 1f, 1f)
        val HIT_RAY_COLOR = Color(1f, 0.2f, 0.15f, 1f)
        val CLEAR_RAY_COLOR = Color(0.2f, 1f, 0.35f, 0.8f)
    }
}
