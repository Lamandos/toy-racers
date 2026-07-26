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

        drawTabletop(shapes, track.worldBounds)
        shapes.color = GRASS_COLOR
        drawRectangle(shapes, tabletopMatBounds(track))
        track.surfaceRegions.forEach { region ->
            shapes.color = colorFor(region.surface)
            drawRectangle(shapes, region.bounds)
        }
        track.innerObstacles.forEach { obstacle ->
            shapes.color = colorFor(track.backgroundSurface)
            drawRectangle(shapes, obstacle)
        }
        drawCurbs(shapes, track)
        drawLaneMarkers(shapes, track)

        shapes.color = START_LINE_COLOR
        drawRectangle(shapes, track.startLine.bounds)
        shapes.end()
    }

    private fun tabletopMatBounds(track: Track): TrackRectangle {
        val boundary = track.outerBoundary
        return TrackRectangle(
            x = boundary.x - MAT_MARGIN,
            y = boundary.y - MAT_MARGIN,
            width = boundary.width + MAT_MARGIN * 2f,
            height = boundary.height + MAT_MARGIN * 2f,
        )
    }

    private fun drawTabletop(
        shapes: ShapeRenderer,
        bounds: TrackRectangle,
    ) {
        shapes.color = WOOD_DARK
        drawRectangle(shapes, bounds)
        shapes.color = WOOD_GRAIN
        var y = bounds.y + WOOD_PLANK_HEIGHT
        while (y < bounds.y + bounds.height) {
            shapes.rect(bounds.x, y, bounds.width, WOOD_GRAIN_WIDTH)
            y += WOOD_PLANK_HEIGHT
        }
    }

    private fun drawCurbs(
        shapes: ShapeRenderer,
        track: Track,
    ) {
        val outer = track.outerBoundary
        var x = outer.x
        var index = 0
        while (x < outer.maxX) {
            shapes.color = if (index++ % 2 == 0) CURB_LIGHT else CURB_RED
            shapes.rect(x, outer.y, CURB_LENGTH, CURB_WIDTH)
            shapes.rect(x, outer.maxY - CURB_WIDTH, CURB_LENGTH, CURB_WIDTH)
            x += CURB_LENGTH
        }
    }

    private fun drawLaneMarkers(
        shapes: ShapeRenderer,
        track: Track,
    ) {
        shapes.color = LANE_MARKER_COLOR
        val bottomY = track.outerBoundary.y + BOTTOM_LANE_OFFSET
        var x = track.outerBoundary.x + LANE_MARKER_GAP
        while (x < track.outerBoundary.maxX - LANE_MARKER_LENGTH) {
            shapes.rect(x, bottomY, LANE_MARKER_LENGTH, LANE_MARKER_WIDTH)
            x += LANE_MARKER_LENGTH + LANE_MARKER_GAP
        }
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
        val WOOD_DARK = Color(0.24f, 0.12f, 0.07f, 1f)
        val WOOD_GRAIN = Color(0.34f, 0.18f, 0.10f, 1f)
        val CURB_LIGHT = Color(0.94f, 0.88f, 0.72f, 1f)
        val CURB_RED = Color(0.78f, 0.16f, 0.12f, 1f)
        val LANE_MARKER_COLOR = Color(0.92f, 0.82f, 0.42f, 0.8f)
        const val WOOD_PLANK_HEIGHT = 3f
        const val WOOD_GRAIN_WIDTH = 0.08f
        const val CURB_LENGTH = 1.2f
        const val CURB_WIDTH = 0.28f
        const val BOTTOM_LANE_OFFSET = 3f
        const val LANE_MARKER_LENGTH = 1.3f
        const val LANE_MARKER_WIDTH = 0.12f
        const val LANE_MARKER_GAP = 1.1f
        const val MAT_MARGIN = 1.1f
    }
}
