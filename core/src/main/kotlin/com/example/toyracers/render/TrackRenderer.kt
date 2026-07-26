package com.example.toyracers.render

import com.badlogic.gdx.graphics.Camera
import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.glutils.ShapeRenderer
import com.badlogic.gdx.utils.ScreenUtils
import com.badlogic.gdx.utils.viewport.Viewport
import com.example.toyracers.track.SurfaceType
import com.example.toyracers.track.Track
import com.example.toyracers.track.TrackRectangle

/** Draws track data without owning or changing gameplay state. */
class TrackRenderer {
    fun render(
        viewport: Viewport,
        camera: Camera,
        shapes: ShapeRenderer,
        track: Track,
    ) {
        ScreenUtils.clear(colorFor(track.backgroundSurface))
        viewport.apply()
        camera.update()
        shapes.projectionMatrix = camera.combined
        shapes.begin(ShapeRenderer.ShapeType.Filled)

        shapes.color = colorFor(track.backgroundSurface)
        drawRectangle(shapes, track.worldBounds)
        track.surfaceRegions.forEach { region ->
            shapes.color = colorFor(region.surface)
            drawRectangle(shapes, region.bounds)
        }
        track.innerObstacles.forEach { obstacle ->
            shapes.color = colorFor(track.backgroundSurface)
            drawRectangle(shapes, obstacle)
        }

        shapes.color = START_LINE_COLOR
        drawRectangle(shapes, track.startLine.bounds)
        shapes.end()
    }

    private fun drawRectangle(
        shapes: ShapeRenderer,
        rectangle: TrackRectangle,
    ) {
        shapes.rect(rectangle.x, rectangle.y, rectangle.width, rectangle.height)
    }

    private fun colorFor(surface: SurfaceType): Color = when (surface) {
        SurfaceType.ASPHALT -> ASPHALT_COLOR
        SurfaceType.GRASS -> GRASS_COLOR
        SurfaceType.BOOST -> BOOST_COLOR
        SurfaceType.OIL -> OIL_COLOR
    }

    private companion object {
        val ASPHALT_COLOR = Color(0.20f, 0.22f, 0.25f, 1f)
        val GRASS_COLOR = Color(0.18f, 0.48f, 0.24f, 1f)
        val BOOST_COLOR = Color(0.12f, 0.72f, 0.92f, 1f)
        val OIL_COLOR = Color(0.08f, 0.08f, 0.10f, 1f)
        val START_LINE_COLOR = Color.WHITE
    }
}
