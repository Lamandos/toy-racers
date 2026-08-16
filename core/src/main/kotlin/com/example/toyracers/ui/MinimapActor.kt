package com.example.toyracers.ui

import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.g2d.Batch
import com.badlogic.gdx.graphics.glutils.ShapeRenderer
import com.badlogic.gdx.math.Vector2
import com.badlogic.gdx.scenes.scene2d.Actor
import com.badlogic.gdx.utils.Disposable
import com.example.toyracers.track.Track
import com.example.toyracers.track.TrackPolygon
import kotlin.math.cos
import kotlin.math.sin

/** Draws cached track geometry and dynamic participant markers in screen space. */
class MinimapActor(
    track: Track,
) : Actor(),
    Disposable {
    private val shapes = ShapeRenderer()
    private val stageOrigin = Vector2()
    private val worldBounds = track.worldBounds
    private val outerVertices = verticesOf(track.roadOuter)
    private val innerVertices = verticesOf(track.roadInner)
    private var snapshot = RaceMinimapSnapshot(emptyList())

    init {
        setSize(PREFERRED_WIDTH, PREFERRED_HEIGHT)
    }

    fun update(value: RaceMinimapSnapshot) {
        snapshot = value
    }

    override fun draw(
        batch: Batch,
        parentAlpha: Float,
    ) {
        if (width <= 0f || height <= 0f) return
        localToStageCoordinates(stageOrigin.set(0f, 0f))
        val transform = MinimapTransform(worldBounds, width, height, CONTENT_PADDING)
        batch.end()
        shapes.projectionMatrix = batch.projectionMatrix
        drawPanel()
        drawTrack(transform)
        drawParticipants(transform)
        batch.begin()
    }

    private fun drawPanel() {
        shapes.begin(ShapeRenderer.ShapeType.Filled)
        shapes.color = PANEL_COLOR
        shapes.rect(stageOrigin.x, stageOrigin.y, width, height)
        shapes.end()
        shapes.begin(ShapeRenderer.ShapeType.Line)
        shapes.color = BORDER_COLOR
        shapes.rect(stageOrigin.x, stageOrigin.y, width, height)
        shapes.end()
    }

    private fun drawTrack(transform: MinimapTransform) {
        shapes.begin(ShapeRenderer.ShapeType.Line)
        shapes.color = ROAD_COLOR
        if (outerVertices == null || innerVertices == null) {
            shapes.rect(
                stageOrigin.x + CONTENT_PADDING,
                stageOrigin.y + CONTENT_PADDING,
                width - CONTENT_PADDING * 2f,
                height - CONTENT_PADDING * 2f,
            )
        } else {
            drawLoop(outerVertices, transform)
            drawLoop(innerVertices, transform)
        }
        shapes.end()
    }

    private fun drawLoop(
        vertices: FloatArray,
        transform: MinimapTransform,
    ) {
        var index = 0
        while (index < vertices.size) {
            val next = (index + 2) % vertices.size
            shapes.line(
                stageOrigin.x + transform.mapX(vertices[index]),
                stageOrigin.y + transform.mapY(vertices[index + 1]),
                stageOrigin.x + transform.mapX(vertices[next]),
                stageOrigin.y + transform.mapY(vertices[next + 1]),
            )
            index += 2
        }
    }

    private fun drawParticipants(transform: MinimapTransform) {
        shapes.begin(ShapeRenderer.ShapeType.Filled)
        snapshot.participants.forEach {
            if (it.role == MinimapParticipantRole.OPPONENT) {
                shapes.color = OPPONENT_COLOR
                shapes.circle(
                    stageOrigin.x + transform.mapX(it.x),
                    stageOrigin.y + transform.mapY(it.y),
                    OPPONENT_RADIUS,
                    CIRCLE_SEGMENTS,
                )
            }
        }
        snapshot.participants.forEach {
            if (it.role == MinimapParticipantRole.PLAYER) {
                shapes.color = PLAYER_COLOR
                drawPlayerMarker(it, transform)
            }
        }
        shapes.end()
    }

    private fun drawPlayerMarker(
        participant: MinimapParticipantSnapshot,
        transform: MinimapTransform,
    ) {
        val centerX = stageOrigin.x + transform.mapX(participant.x)
        val centerY = stageOrigin.y + transform.mapY(participant.y)
        val radians = Math.toRadians(participant.rotationDeg.toDouble()).toFloat()
        val forwardX = cos(radians)
        val forwardY = sin(radians)
        val sideX = -forwardY
        val sideY = forwardX
        shapes.triangle(
            centerX + forwardX * PLAYER_LENGTH,
            centerY + forwardY * PLAYER_LENGTH,
            centerX - forwardX * PLAYER_LENGTH + sideX * PLAYER_HALF_WIDTH,
            centerY - forwardY * PLAYER_LENGTH + sideY * PLAYER_HALF_WIDTH,
            centerX - forwardX * PLAYER_LENGTH - sideX * PLAYER_HALF_WIDTH,
            centerY - forwardY * PLAYER_LENGTH - sideY * PLAYER_HALF_WIDTH,
        )
    }

    override fun dispose() {
        shapes.dispose()
    }

    private fun verticesOf(polygon: TrackPolygon?): FloatArray? {
        polygon ?: return null
        return FloatArray(polygon.vertices.size * 2).also { coordinates ->
            polygon.vertices.forEachIndexed { index, point ->
                coordinates[index * 2] = point.x
                coordinates[index * 2 + 1] = point.y
            }
        }
    }

    companion object {
        const val PREFERRED_WIDTH = 190f
        const val PREFERRED_HEIGHT = 142f
        private const val CONTENT_PADDING = 10f
        private const val OPPONENT_RADIUS = 3.5f
        private const val PLAYER_LENGTH = 7f
        private const val PLAYER_HALF_WIDTH = 4.5f
        private const val CIRCLE_SEGMENTS = 12
        private val PANEL_COLOR = Color(0.01f, 0.025f, 0.055f, 0.82f)
        private val BORDER_COLOR = Color(0.02f, 0.72f, 1f, 0.96f)
        private val ROAD_COLOR = Color(0.38f, 0.82f, 1f, 0.9f)
        private val OPPONENT_COLOR = Color(0.82f, 0.86f, 0.9f, 1f)
        private val PLAYER_COLOR = Color(1f, 0.25f, 0.68f, 1f)
    }
}
